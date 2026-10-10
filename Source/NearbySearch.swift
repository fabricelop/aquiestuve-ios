import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
final class NearbySearch: ObservableObject {
    @Published private(set) var candidates: [PlaceCandidate] = []
    @Published private(set) var loading = false
    @Published private(set) var warning: String?
    @Published private(set) var appleCount = 0
    @Published private(set) var osmCount = 0
    @Published private(set) var nameResults: [PlaceCandidate] = []
    @Published private(set) var nameQuery: String = ""
    @Published private(set) var exploreResults: [PlaceCandidate] = []
    @Published private(set) var coverageLimited = false
    private var expansion: [PlaceCandidate] = []
    private var textCache: [String: (date: Date, places: [PlaceCandidate])] = [:]
    private var previousExpansion: Date = .distantPast
    private var lastCenter: GeoPoint?
    private var lastRadius: Double = 250
    private var previousSearch: Date = .distantPast
    private var osmCache: [String: (date: Date, places: [PlaceCandidate])] = [:]
    private let store = VisitStore.shared

    func search(near center: GeoPoint, radius: Double = 250, force: Bool = false) async {
        // No polling: reuse answers for three minutes; even manual refreshes cap at 15 seconds.
        if let previous = lastCenter,
           previous.distance(to: center) < 70, lastRadius == radius,
           Date().timeIntervalSince(previousSearch) < (force ? 15 : 180) { return }
        guard !loading else { return }
        loading = true
        warning = nil
        osmCount = 0
        expansion = []
        coverageLimited = false
        lastCenter = center
        lastRadius = radius
        previousSearch = Date()
        defer { loading = false }
        let request = MKLocalPointsOfInterestRequest(center: center.coordinate, radius: radius)
        do {
            let answer = try await MKLocalSearch(request: request).start()
            let found: [PlaceCandidate] = answer.mapItems.compactMap { item in
                guard let name = item.name, !name.isEmpty else { return nil }
                let position = GeoPoint(item.placemark.coordinate)
                let key = "\(name.lowercased())-\(Int(position.latitude * 100000))-\(Int(position.longitude * 100000))"
                let street = [item.placemark.thoroughfare, item.placemark.subThoroughfare]
                    .compactMap { $0 }.joined(separator: " ")
                let address = [street.isEmpty ? nil : street, item.placemark.locality]
                    .compactMap { $0 }.joined(separator: ", ")
                return PlaceCandidate(source: .apple, sourceKey: key, name: name,
                    category: item.pointOfInterestCategory?.rawValue ?? "Establecimiento", position: position,
                    address: address.isEmpty ? nil : address)
            }
            appleCount = found.count
            coverageLimited = found.count >= 45
            candidates = combined(found, near: center, radius: radius)
            NearbyNotificationCache.save(candidates, center: center)
            Task { await LivePlacesManager.shared.refresh(near: center) }
        } catch {
            warning = "Apple Maps no respondió: \(error.localizedDescription)"
            candidates = combined([], near: center, radius: radius)
        }
    }

    func addOSM(near center: GeoPoint, radius: Double) async {
        let radius = min(700, max(100, radius))
        let key = "\(Int(center.latitude * 1000))-\(Int(center.longitude * 1000))-\(Int(radius))"
        if let cache = osmCache[key], Date().timeIntervalSince(cache.date) < 24 * 3600 {
            osmCount = cache.places.count
            candidates = combined(candidates.filter { $0.source == .apple },
                                  plus: cache.places, near: center, radius: radius)
            NearbyNotificationCache.save(candidates, center: center)
            Task { await LivePlacesManager.shared.refresh(near: center) }
            return
        }
        // Persistent 10-minute minimum to respect the community Overpass service.
        let previous = UserDefaults.standard.object(forKey: "lastOSMRequest") as? Date ?? .distantPast
        guard Date().timeIntervalSince(previous) > 600 else {
            warning = "OpenStreetMap: espera 10 minutos entre consultas nuevas."
            return
        }
        guard !loading else { return }
        loading = true
        defer { loading = false }
        UserDefaults.standard.set(Date(), forKey: "lastOSMRequest")
        let r = Int(radius)
        let lat = String(format: "%.5f", center.latitude)
        let lon = String(format: "%.5f", center.longitude)
        let around = "(around:\(r),\(lat),\(lon))"
        let statement = "[out:json][timeout:12];(nwr[\"name\"][\"amenity\"]\(around);nwr[\"name\"][\"shop\"]\(around);nwr[\"name\"][\"tourism\"]\(around);nwr[\"name\"][\"leisure\"]\(around););out center 300;"
        var components = URLComponents(string: "https://overpass-api.de/api/interpreter")!
        components.queryItems = [URLQueryItem(name: "data", value: statement)]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("AquiEstuve/0.1 (personal, manual searches)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                warning = "OpenStreetMap está ocupado o limitando las consultas."
                return
            }
            let decoded = try JSONDecoder().decode(OSMResponse.self, from: data)
            let found: [PlaceCandidate] = decoded.elements.compactMap { element in
                guard let name = element.tags?["name"], !name.isEmpty,
                      let lat = element.lat ?? element.center?.lat,
                      let lon = element.lon ?? element.center?.lon else { return nil }
                let position = GeoPoint(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                guard center.distance(to: position) <= radius else { return nil }
                let category = element.tags?["amenity"] ?? element.tags?["shop"] ??
                               element.tags?["tourism"] ?? element.tags?["leisure"] ?? "Establecimiento"
                let street = [element.tags?["addr:street"], element.tags?["addr:housenumber"]]
                    .compactMap { $0 }.joined(separator: " ")
                let address = [street.isEmpty ? nil : street, element.tags?["addr:city"]]
                    .compactMap { $0 }.joined(separator: ", ")
                return PlaceCandidate(source: .osm, sourceKey: "\(element.type)/\(element.id)",
                                      name: name, category: category, position: position,
                                      address: address.isEmpty ? nil : address)
            }
            osmCount = found.count
            osmCache[key] = (Date(), found)
            candidates = combined(candidates.filter { $0.source == .apple },
                                  plus: found, near: center, radius: radius)
            NearbyNotificationCache.save(candidates, center: center)
            Task { await LivePlacesManager.shared.refresh(near: center) }
        } catch { warning = "No se pudo consultar OpenStreetMap: \(error.localizedDescription)" }
    }


    /// Explicit search by name in a larger geographical area. NEVER run on each keystroke.
    /// Results are kept separate from the nearby list and disappear when the query changes.
    func searchByName(_ raw: String, near center: GeoPoint, radius: Double) async {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { warning = "Escribe al menos dos letras."; return }
        guard !loading else { return }
        let limit = min(10_000, max(1_000, radius))
        let key = "\(query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))-\(Int(center.latitude * 100))-\(Int(center.longitude * 100))-\(Int(limit))"
        nameQuery = query
        if let cache = textCache[key], Date().timeIntervalSince(cache.date) < 3600 {
            nameResults = cache.places
            warning = "Búsqueda recuperada de la memoria local."
            return
        }
        loading = true
        defer { loading = false }
        warning = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: center.coordinate,
            latitudinalMeters: limit * 2, longitudinalMeters: limit * 2)
        do {
            let response = try await MKLocalSearch(request: request).start()
            let found = response.mapItems.compactMap { candidate($0) }.filter {
                $0.position.distance(to: center) <= limit
            }
            let returnedIds = Set(found.map(\.id))
            nameResults = combined(found, near: center, radius: limit).filter { item in
                returnedIds.contains(item.id) ||
                (item.savedID != nil && item.name.localizedCaseInsensitiveContains(query))
            }
            nameQuery = query
            textCache[key] = (Date(), nameResults)
            if nameResults.isEmpty { warning = "Sin coincidencias en Apple Maps; prueba otro nombre o zona." }
        } catch {
            warning = "No se pudo ampliar la búsqueda: \(error.localizedDescription)"
        }
    }

    /// When nearby results are likely capped, split the circle into four smaller
    /// bounded queries. Only by explicit user action, never automatically in background.
    func expandNearby(near center: GeoPoint, radius: Double) async {
        guard !loading else { return }
        guard Date().timeIntervalSince(previousExpansion) >= 60 else {
            warning = "Espera un minuto antes de repetir la búsqueda por sectores."
            return
        }
        previousExpansion = Date()
        loading = true
        warning = "Buscando hasta cuatro sectores. Puede tardar unos segundos."
        defer { loading = false }
        var additional: [PlaceCandidate] = []
        let offset = radius * 0.4
        let latitude = offset / 111_000
        let longitude = offset / max(20_000, 111_000 * cos(center.latitude * .pi / 180))
        for (dy, dx) in [(-1.0,-1.0), (-1.0,1.0), (1.0,-1.0), (1.0,1.0)] {
            let subcenter = CLLocationCoordinate2D(latitude: center.latitude + dy * latitude,
                                                  longitude: center.longitude + dx * longitude)
            let request = MKLocalPointsOfInterestRequest(center: subcenter,
                                                         radius: max(100, radius * 0.58))
            do {
                let response = try await MKLocalSearch(request: request).start()
                additional += response.mapItems.compactMap { candidate($0) }
            } catch { continue }
        }
        // Retain original first-page candidates and deduplicate cross-sector findings.
        expansion = additional
        appleCount = candidates.filter { $0.source == .apple }.count + additional.count
        candidates = combined(candidates + expansion, near: center, radius: radius)
        NearbyNotificationCache.save(candidates, center: center)
        warning = "Resultados ampliados con cuatro sectores; la cobertura no es exhaustiva."
    }

    /// Explicit search in a panned / zoomed map. Reuses point-of-interest search,
    /// not the phone's current position. Never runs automatically on pan gestures.
    func searchMapArea(near center: GeoPoint, radius: Double) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        let radius = min(3_000, max(100, radius))
        let request = MKLocalPointsOfInterestRequest(center: center.coordinate, radius: radius)
        do {
            let response = try await MKLocalSearch(request: request).start()
            exploreResults = combined(response.mapItems.compactMap { candidate($0) },
                                      near: center, radius: radius)
        } catch { warning = "No se pudo explorar esta zona: \(error.localizedDescription)" }
    }

    private func candidate(_ item: MKMapItem) -> PlaceCandidate? {
        guard let name = item.name, !name.isEmpty else { return nil }
        let position = GeoPoint(item.placemark.coordinate)
        let key = "\(name.lowercased())-\(Int(position.latitude * 100000))-\(Int(position.longitude * 100000))"
        let street = [item.placemark.thoroughfare, item.placemark.subThoroughfare]
            .compactMap { $0 }.joined(separator: " ")
        let address = [street.isEmpty ? nil : street, item.placemark.locality]
            .compactMap { $0 }.joined(separator: ", ")
        return PlaceCandidate(source: .apple, sourceKey: key, name: name,
            category: item.pointOfInterestCategory?.rawValue ?? "Establecimiento",
            position: position, address: address.isEmpty ? nil : address)
    }

    private func combined(_ fromApple: [PlaceCandidate], plus osm: [PlaceCandidate] = [],
                          near center: GeoPoint, radius: Double) -> [PlaceCandidate] {
        var output: [PlaceCandidate] = store.places.filter { $0.position.distance(to: center) <= radius }
            .map { store.savedCandidate(for: $0, near: center) }
        for var item in (fromApple + osm) {
            item.distance = item.position.distance(to: center)
            guard item.distance <= radius else { continue }
            if let category = store.categoryOverrides[item.id] { item.category = category }
            if let exact = store.canonicalPlace(for: item) {
                // Explicitly merged aliases render as a single saved venue in every search.
                if !output.contains(where: { $0.savedID == exact.id }) {
                    output.append(store.savedCandidate(for: exact, near: center))
                }
                continue
            }
            // OSM can provide a more precise category than Apple's generic "store".
            // Enrich ONLY the displayed candidate; never overwrite user-saved categories.
            if let matchIndex = output.firstIndex(where: {
                $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) ==
                item.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) &&
                $0.position.distance(to: item.position) < 30
            }) {
                let existing = output[matchIndex]
                let appleGeneric = existing.categoryGroup == .others ||
                    existing.categoryLabel == "Tienda" || existing.categoryLabel == "Alimentación y mercados"
                let osmSpecific = item.categoryGroup != .others &&
                    item.categoryLabel != "Tienda" && item.categoryLabel != "Alimentación y mercados"
                if item.source == .osm && existing.source == .apple &&
                   existing.savedID == nil && appleGeneric && osmSpecific {
                    output[matchIndex] = PlaceCandidate(source: existing.source, sourceKey: existing.sourceKey,
                        name: existing.name, category: item.category, position: existing.position,
                        distance: existing.distance, visits: existing.visits,
                        savedID: existing.savedID, address: existing.address ?? item.address)
                }
                continue
            }
            output.append(item)
        }
        return output.sorted {
            if ($0.visits > 0) != ($1.visits > 0) { return $0.visits > 0 }
            return $0.distance < $1.distance
        }
    }
}

private struct OSMResponse: Decodable {
    let elements: [OSMElement]
}
private struct OSMElement: Decodable {
    let type: String
    let id: Int64
    let lat: Double?
    let lon: Double?
    let center: OSMCenter?
    let tags: [String: String]?
}
private struct OSMCenter: Decodable { let lat: Double; let lon: Double }
