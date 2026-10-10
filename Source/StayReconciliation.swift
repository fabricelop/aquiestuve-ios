import Foundation

/// Platform-neutral reconciliation, unit-tested on Windows/Linux/macOS.
/// Never combines two different named places or merely consecutive stays.
struct StayEvidence {
    var id: UUID
    var placeID: UUID?
    var latitude: Double
    var longitude: Double
    var arrival: Date
    var departure: Date?
    var status: String
    var origin: String
}

enum StayReconciliation {
    static func reconcile(_ entries: [StayEvidence], now: Date = Date()) -> [StayEvidence] {
        let sorted = entries.sorted {
            if $0.arrival == $1.arrival { return $0.id.uuidString < $1.id.uuidString }
            return $0.arrival < $1.arrival
        }
        var merged: [StayEvidence] = []
        for entry in sorted {
            var match: Int?
            for index in merged.indices.reversed() {
                let existing = merged[index]
                // An unended visit covers up to NOW, not unlimited future time.
                let endA = existing.departure ?? now
                let endB = entry.departure ?? now
                let overlap = min(endA, endB).timeIntervalSince(max(existing.arrival, entry.arrival))
                guard overlap >= 30 else { continue }
                if let a = existing.placeID, let b = entry.placeID, a != b { continue }
                // When either observation is unnamed, merge only if most of the
                // shorter stay overlaps; nearby buildings can be different venues.
                if existing.placeID == nil || entry.placeID == nil {
                    let short = min(endA.timeIntervalSince(existing.arrival),
                                    endB.timeIntervalSince(entry.arrival))
                    guard overlap >= max(30, short * 0.7) else { continue }
                }
                let radius: Double = existing.placeID != nil && existing.placeID == entry.placeID ? 160 : 80
                guard metersBetween(existing, entry) <= radius else { continue }
                match = index
                break
            }
            guard let index = match else { merged.append(entry); continue }
            var kept = merged[index]
            kept.arrival = min(kept.arrival, entry.arrival)
            if kept.departure == nil || entry.departure == nil {
                kept.departure = nil
            } else {
                kept.departure = max(kept.departure!, entry.departure!)
            }
            if kept.placeID == nil { kept.placeID = entry.placeID }
            let rank: [String: Int] = ["unresolved": 0, "automatic": 1, "confirmed": 2]
            if (rank[entry.status] ?? 0) > (rank[kept.status] ?? 0) {
                kept.status = entry.status
            }
            let sources = Set((kept.origin + "+" + entry.origin).split(separator: "+").map(String.init))
            kept.origin = sources.sorted().joined(separator: "+")
            merged[index] = kept
        }
        return merged
    }

    private static func metersBetween(_ a: StayEvidence, _ b: StayEvidence) -> Double {
        let rad = Double.pi / 180
        let dLat = (b.latitude - a.latitude) * rad
        let dLon = (b.longitude - a.longitude) * rad
        let q = pow(sin(dLat / 2), 2) + cos(a.latitude * rad) * cos(b.latitude * rad) * pow(sin(dLon / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(max(0, q)), sqrt(max(0, 1 - q)))
    }
}
