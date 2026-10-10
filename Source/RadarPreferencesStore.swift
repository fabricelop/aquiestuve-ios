import Foundation
import Combine

struct RecoveredRadarItem: Identifiable {
    var key: String
    var rule: RadarRule
    var id: String { key }
}

@MainActor
final class RadarPreferencesStore: ObservableObject {
    static let shared = RadarPreferencesStore()
    @Published private(set) var snapshot = RadarSnapshot()
    @Published private(set) var errorText: String?

    private let fileURL: URL
    private var lastUndo: (key: String, previous: RadarRule?)?

    private init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AquiEstuve", isDirectory: true)
        fileURL = folder.appendingPathComponent("radar-preferences.json")
        if let data = try? Data(contentsOf: fileURL),
           let existing = try? JSONDecoder().decode(RadarSnapshot.self, from: data) {
            snapshot = existing
        }
    }

    func key(for item: PlaceCandidate) -> String {
        // Stable across a POI becoming saved: its provider id does not change.
        // Merging two POIs is explicitly user-controlled; existing aliases are recoverable.
        return item.id
    }
    func rule(for item: PlaceCandidate) -> RadarRule { snapshot.rules[key(for: item)] ?? RadarRule() }
    func isVisible(_ item: PlaceCandidate, at point: GeoPoint, now: Date = Date()) -> Bool {
        !rule(for: item).hidden(at: point.latitude, point.longitude, now: now)
    }
    func score(_ item: PlaceCandidate) -> Double {
        RadarRanking.score(meters: item.distance, visits: item.visits, favorite: rule(for: item).favorite)
            - Double(min(rule(for: item).snoozeCount, 4)) * 13
    }

    private func modify(_ item: PlaceCandidate, _ mutation: (inout RadarRule) -> Void) {
        let key = key(for: item)
        lastUndo = (key, snapshot.rules[key])
        var rule = snapshot.rules[key] ?? RadarRule()
        rule.name = item.name
        rule.category = item.categoryLabel
        rule.latitude = item.position.latitude
        rule.longitude = item.position.longitude
        mutation(&rule)
        snapshot.rules[key] = rule
        persist()
    }

    func toggleFavorite(_ item: PlaceCandidate) {
        setFavorite(item, to: !rule(for: item).favorite)
    }
    func setFavorite(_ item: PlaceCandidate, to value: Bool) {
        modify(item) { rule in
            rule.favorite = value
            if value {
                rule.archived = false
                rule.snoozedUntil = nil
                rule.hiddenAround = []
            }
        }
    }
    func snooze(_ item: PlaceCandidate, until: Date = Date().addingTimeInterval(4 * 3600)) {
        modify(item) { rule in
            rule.snoozedUntil = until
            rule.snoozeCount += 1
        }
    }
    func hideInArea(_ item: PlaceCandidate, at point: GeoPoint) {
        modify(item) { rule in
            if !rule.hiddenAround.contains(where: {
                $0.distance(latitude: point.latitude, longitude: point.longitude) < 300
            }) {
                rule.hiddenAround.append(RadarAnchor(latitude: point.latitude, longitude: point.longitude, createdAt: Date()))
            }
        }
    }
    func archive(_ item: PlaceCandidate) { modify(item) { $0.archived = true } }
    func restore(_ key: String) {
        guard var rule = snapshot.rules[key] else { return }
        lastUndo = (key, rule)
        rule.archived = false
        rule.snoozedUntil = nil
        rule.hiddenAround = []
        snapshot.rules[key] = rule
        persist()
    }
    func restore(_ item: PlaceCandidate) { restore(key(for: item)) }
    func undo() {
        guard let undo = lastUndo else { return }
        if let prior = undo.previous { snapshot.rules[undo.key] = prior }
        else { snapshot.rules.removeValue(forKey: undo.key) }
        lastUndo = nil
        persist()
    }
    var canUndo: Bool { lastUndo != nil }
    var recoverable: [RecoveredRadarItem] {
        snapshot.rules.compactMap { key, rule in
            rule.suppressed ? RecoveredRadarItem(key: key, rule: rule) : nil
        }.sorted { $0.rule.name.localizedStandardCompare($1.rule.name) == .orderedAscending }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            try (fileURL as NSURL).setResourceValue(FileProtectionType.completeUntilFirstUserAuthentication,
                                                    forKey: .fileProtectionKey)
            errorText = nil
        } catch { errorText = "No se guardaron las preferencias: \(error.localizedDescription)" }
    }
}
