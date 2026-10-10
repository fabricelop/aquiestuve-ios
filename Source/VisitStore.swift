import Foundation
import CoreLocation
import Combine

@MainActor
final class VisitStore: ObservableObject {
    static let shared = VisitStore()
    @Published private(set) var places: [Place] = []
    @Published private(set) var stays: [Stay] = []
    @Published private(set) var categoryOverrides: [String: String] = [:]
    @Published private(set) var lastError: String?

    private let storageURL: URL
    private init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AquiEstuve", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        storageURL = folder.appendingPathComponent("visits.json")
        if let data = try? Data(contentsOf: storageURL),
           let stored = try? JSONDecoder().decode(StoredData.self, from: data) {
            places = stored.places
            stays = stored.stays
            categoryOverrides = stored.categoryOverrides
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(StoredData(places: places, stays: stays, categoryOverrides: categoryOverrides))
            try data.write(to: storageURL, options: .atomic)
            try (storageURL as NSURL).setResourceValue(FileProtectionType.completeUntilFirstUserAuthentication,
                                                       forKey: .fileProtectionKey)
            lastError = nil
        } catch { lastError = "No se pudo guardar: \(error.localizedDescription)" }
    }

    var activeStay: Stay? { stays.last(where: { $0.departure == nil }) }
    func place(for stay: Stay) -> Place? { places.first(where: { $0.id == stay.placeID }) }
    func visitCount(for place: Place) -> Int { stays.filter { $0.placeID == place.id }.count }
    func totalTime(for place: Place, asOf date: Date = Date()) -> TimeInterval {
        stays.filter { $0.placeID == place.id }.reduce(0) { $0 + $1.duration(asOf: date) }
    }

    @discardableResult
    func createPersonalPlace(name: String, category: String, at point: GeoPoint) -> Place {
        let place = Place(source: .personal, sourceKey: UUID().uuidString, name: name,
                          category: category, position: point)
        places.append(place)
        persist()
        return place
    }

    func rename(_ place: Place, name: String, category: String) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index].name = name
        places[index].category = category
        categoryOverrides[place.source.rawValue + ":" + place.sourceKey] = category
        persist()
    }

    /// Delete any saved place, whether created privately or registered from a POI.
    /// Optionally delete its visit records; otherwise preserve them as unclassified.
    /// Neither choice affects visits assigned to any other place.
    func deletePlace(_ place: Place, deleteVisits: Bool) {
        guard places.contains(where: { $0.id == place.id }) else { return }
        if deleteVisits {
            stays.removeAll(where: { $0.placeID == place.id })
        } else {
            for index in stays.indices where stays[index].placeID == place.id {
                stays[index].placeID = nil
                stays[index].status = .unresolved
            }
        }
        places.removeAll(where: { $0.id == place.id })
        // Deleted places must not appear again as category preferences.
        categoryOverrides.removeValue(forKey: place.source.rawValue + ":" + place.sourceKey)
        persist()
    }

    func removePersonalPlace(_ place: Place) {
        guard place.isPrivate else { return }
        deletePlace(place, deleteVisits: false)
    }

    func preferredCategory(for candidate: PlaceCandidate) -> String {
        categoryOverrides[candidate.id] ?? candidate.category
    }

    func updateCategory(for candidate: PlaceCandidate, to category: String) {
        let clean = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        categoryOverrides[candidate.id] = clean
        if let index = places.firstIndex(where: {
            $0.source == candidate.source && $0.sourceKey == candidate.sourceKey
        }) {
            places[index].category = clean
        }
        persist()
    }

    func savedCandidate(for place: Place, near point: GeoPoint) -> PlaceCandidate {
        PlaceCandidate(source: place.source, sourceKey: place.sourceKey, name: place.name,
                       category: categoryOverrides[place.source.rawValue + ":" + place.sourceKey] ?? place.category,
                       position: place.position,
                       distance: place.position.distance(to: point),
                       visits: visitCount(for: place), savedID: place.id)
    }

    func assign(_ candidate: PlaceCandidate, to visitID: UUID? = nil) {
        let place: Place
        if let existing = places.first(where: { $0.id == candidate.savedID }) ??
            places.first(where: { $0.source == candidate.source && $0.sourceKey == candidate.sourceKey }) {
            place = existing
        } else {
            place = Place(source: candidate.source, sourceKey: candidate.sourceKey,
                          name: candidate.name,
                          category: preferredCategory(for: candidate),
                          position: candidate.position)
            places.append(place)
        }
        if let index = stays.firstIndex(where: { $0.id == (visitID ?? activeStay?.id) }) {
            stays[index].placeID = place.id
            stays[index].status = .confirmed
        } else if visitID == nil {
            stays.append(Stay(placeID: place.id, position: candidate.position,
                              arrival: Date(), departure: nil, status: .confirmed, origin: "manual"))
        }
        persist()
    }

    func addManualVisit(for place: Place, at date: Date = Date()) {
        if let index = stays.lastIndex(where: { $0.departure == nil }) {
            stays[index].departure = max(stays[index].arrival, date)
        }
        stays.append(Stay(placeID: place.id, position: place.position, arrival: date,
                          departure: nil, status: .confirmed, origin: "manual"))
        persist()
    }

    func endCurrent(at date: Date = Date()) {
        guard let index = stays.lastIndex(where: { $0.departure == nil }) else { return }
        stays[index].departure = max(stays[index].arrival, date)
        persist()
    }

    func updateVisit(_ visit: Stay, arrival: Date, departure: Date?, placeID: UUID?) {
        guard departure == nil || departure! >= arrival,
              let index = stays.firstIndex(where: { $0.id == visit.id }) else { return }
        stays[index].arrival = arrival
        stays[index].departure = departure
        stays[index].placeID = placeID
        stays[index].status = placeID == nil ? .unresolved : .confirmed
        persist()
    }

    func deleteVisit(_ id: UUID) {
        stays.removeAll(where: { $0.id == id })
        persist()
    }

    /// CLVisit timestamps are approximate, and events may be delivered twice or late.
    /// Uncertain matching never silently assigns the visit to a business.
    @discardableResult
    func receiveVisit(position: GeoPoint, accuracy: Double, arrival: Date, departure: Date?) -> Bool {
        let finiteArrival = arrival != Date.distantPast && arrival != Date.distantFuture
        let finiteDeparture = departure != nil && departure != Date.distantFuture && departure != Date.distantPast
        guard finiteArrival else { return false }
        let prior = stays.indices.last(where: {
            stays[$0].origin.contains("system") &&
            abs(stays[$0].arrival.timeIntervalSince(arrival)) < 600 &&
            stays[$0].position.distance(to: position) < max(75, accuracy)
        })
        if let prior {
            if finiteDeparture, let departure { stays[prior].departure = max(arrival, departure) }
            persist()
            return false
        }
        // A manual check-in can precede a delayed system visit: reconcile rather than double-count.
        if let open = stays.lastIndex(where: {
            $0.departure == nil && $0.origin == "manual" &&
            $0.position.distance(to: position) <= max(80, min(accuracy, 120)) &&
            abs($0.arrival.timeIntervalSince(arrival)) < 7200
        }) {
            stays[open].origin = "manual+system"
            if accuracy > 0 && accuracy < 100 {
                stays[open].arrival = min(stays[open].arrival, arrival)
            }
            if finiteDeparture, let departure {
                stays[open].departure = max(stays[open].arrival, departure)
            }
            persist()
            return false
        }
        // If an arrival event is delayed, don't extend the previous stay past it.
        if let open = stays.lastIndex(where: { $0.departure == nil }), stays[open].arrival < arrival {
            stays[open].departure = arrival
        }
        let possible = places.map { ($0, $0.position.distance(to: position)) }
            .filter { $0.1 <= 50 && visitCount(for: $0.0) > 0 }
            .sorted { $0.1 < $1.1 }
        let confident = accuracy > 0 && accuracy <= 45 && possible.count == 1 && possible[0].1 <= 30
        let match = confident ? possible[0].0.id : nil
        stays.append(Stay(placeID: match, position: position, arrival: arrival,
                          departure: finiteDeparture ? departure : nil,
                          status: match == nil ? .unresolved : .automatic,
                          origin: "system"))
        persist()
        return !finiteDeparture && match == nil
    }


    /// Brief stop observations from optional walk mode, always pending review.
    func receiveWalkStop(position: GeoPoint, arrival: Date, departure: Date) {
        guard departure.timeIntervalSince(arrival) >= 80,
              departure > arrival, departure <= Date().addingTimeInterval(30) else { return }
        // Reconcile with visits already observed by iOS or confirmed by the user.
        if stays.contains(where: {
            $0.position.distance(to: position) < 65 &&
            $0.arrival < departure.addingTimeInterval(120) &&
            ($0.departure ?? Date()) > arrival.addingTimeInterval(-120)
        }) { return }
        stays.append(Stay(placeID: nil, position: position, arrival: arrival,
                          departure: departure, status: .unresolved, origin: "paseo"))
        persist()
    }

    var pendingCount: Int { stays.filter { $0.placeID == nil }.count }

    func exportJSON() -> URL? {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("AquiEstuve-historial.json")
        guard let data = try? JSONEncoder().encode(StoredData(places: places, stays: stays, categoryOverrides: categoryOverrides)),
              (try? data.write(to: path, options: .atomic)) != nil else { return nil }
        return path
    }

    func exportCSV() -> URL? {
        let header = "sitio,categoria,llegada,salida,minutos,estado,origen\n"
        func csv(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let formatter = ISO8601DateFormatter()
        let rows = stays.map { visit -> String in
            let place = place(for: visit)
            return [csv(place?.name ?? "Sin identificar"), csv(place?.category ?? ""),
                    csv(formatter.string(from: visit.arrival)),
                    csv(visit.departure.map { formatter.string(from: $0) } ?? ""),
                    String(Int(visit.duration / 60)), csv(visit.status.rawValue), csv(visit.origin)]
                .joined(separator: ",")
        }.joined(separator: "\n")
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("AquiEstuve-historial.csv")
        guard (try? (header + rows + "\n").write(to: path, atomically: true, encoding: .utf8)) != nil else { return nil }
        return path
    }
}
