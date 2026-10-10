import Foundation

/// Independent from visits.json. These are visibility preferences, NEVER evidence of a visit.
struct RadarAnchor: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var createdAt: Date

    func distance(latitude: Double, longitude: Double) -> Double {
        let lat1 = self.latitude * .pi / 180
        let lat2 = latitude * .pi / 180
        let dLat = (latitude - self.latitude) * .pi / 180
        let dLon = (longitude - self.longitude) * .pi / 180
        let a = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }
}

struct RadarRule: Codable, Equatable {
    var favorite = false
    var snoozeCount = 0
    var snoozedUntil: Date?
    var hiddenAround: [RadarAnchor] = []
    var archived = false
    var name: String = ""
    var category: String = ""
    var latitude = 0.0
    var longitude = 0.0

    func hidden(at latitude: Double, _ longitude: Double, now: Date = Date()) -> Bool {
        if archived { return true }
        if let until = snoozedUntil, now < until { return true }
        return hiddenAround.contains { $0.distance(latitude: latitude, longitude: longitude) <= 450 }
    }

    var suppressed: Bool {
        archived || !hiddenAround.isEmpty || (snoozedUntil ?? .distantPast) > Date()
    }
}

struct RadarSnapshot: Codable {
    var rules: [String: RadarRule] = [:]
}

enum RadarRanking {
    /// Distance dominates. Favorite and verified visits help order *nearby* places only.
    static func score(meters: Double, visits: Int, favorite: Bool) -> Double {
        let near = max(0, 310 - min(max(0, meters), 500) * 1.40)
        let immediate = meters < 25 ? 70.0 : 0.0
        return near + immediate + (favorite ? 85 : 0) + Double(min(max(visits, 0), 10)) * 9
    }
}
