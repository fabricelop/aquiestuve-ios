import Foundation

/// Local presentation only. Nothing is removed from the full catalogue.
enum VenueKind: String, CaseIterable, Identifiable {
    case all, commercial, publicPlace, other, mine
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Todos los tipos"
        case .commercial: return "Comercios y locales"
        case .publicPlace: return "Espacios públicos"
        case .other: return "Oficinas y otros"
        case .mine: return "Mis lugares"
        }
    }
}

extension PlaceCandidate {
    var venueKind: VenueKind {
        if source == .personal { return .mine }
        switch categoryGroup {
        case .food, .cafes, .shopping, .health, .leisure, .sports, .lodging:
            return .commercial
        case .outdoors, .transport, .culture:
            return .publicPlace
        case .privatePlaces:
            return .mine
        case .services:
            let key = categoryLabel.lowercased()
            return ["banco", "peluquer", "lavander", "taller", "gasolinera", "correos", "spa"].contains(where: key.contains) ? .commercial : .other
        default:
            return .other
        }
    }
    /// Explicit, transparent scoring. The closest place is not always the most relevant.
    /// A selected category and previous visits can outweigh a nearby unknown office.
    var relevanceScore: Double {
        let typeScore: Double
        switch venueKind {
        case .mine: typeScore = 95
        case .commercial: typeScore = 70
        case .publicPlace: typeScore = 43
        case .other: typeScore = 5
        case .all: typeScore = 0
        }
        let familiarity = min(60.0, Double(visits) * 12)
        return typeScore + familiarity - min(100.0, distance / 13.0)
    }
    var isProbable: Bool {
        venueKind != .other || visits > 0 || savedID != nil
    }
}
