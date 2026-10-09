import Foundation
import CoreLocation

struct GeoPoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    func distance(to other: GeoPoint) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

enum PlaceSource: String, Codable { case personal, apple, osm }

struct Place: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var source: PlaceSource
    var sourceKey: String
    var name: String
    var category: String
    var position: GeoPoint
    var createdAt: Date = Date()
    var isPrivate: Bool { source == .personal }
}

enum StayStatus: String, Codable { case unresolved, automatic, confirmed }

struct Stay: Identifiable, Codable {
    var id: UUID = UUID()
    var placeID: UUID?
    var position: GeoPoint
    var arrival: Date
    var departure: Date?
    var status: StayStatus
    var origin: String
    var duration: TimeInterval { duration(asOf: Date()) }
    func duration(asOf date: Date) -> TimeInterval { max(0, (departure ?? date).timeIntervalSince(arrival)) }
}

struct PlaceCandidate: Identifiable, Hashable {
    var id: String { source.rawValue + ":" + sourceKey }
    let source: PlaceSource
    let sourceKey: String
    let name: String
    let category: String
    let position: GeoPoint
    var distance: Double = 0
    var visits: Int = 0
    var savedID: UUID?
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct StoredData: Codable {
    var schemaVersion: Int = 1
    var places: [Place] = []
    var stays: [Stay] = []
}

extension Double {
    var readableDistance: String { self < 1000 ? "\(Int(self.rounded())) m" : String(format: "%.1f km", self / 1000) }
}

extension TimeInterval {
    var readableDuration: String {
        let minutes = Int(max(0, self) / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        return "\(hours) h \(minutes % 60) min"
    }
}
