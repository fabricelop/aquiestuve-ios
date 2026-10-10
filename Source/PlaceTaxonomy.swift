import Foundation
import SwiftUI

// Presentación local, determinista y sin consultas de red. Los datos guardados
// conservan su categoría original, incluida cualquier corrección del usuario.
enum PlaceGroup: String, CaseIterable, Identifiable {
    case all, food, cafes, shopping, health, leisure, culture, outdoors, sports,
         transport, education, lodging, services, privatePlaces, others

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todos"
        case .food: return "Restaurantes y comida"
        case .cafes: return "Cafés y bares"
        case .shopping: return "Tiendas y compras"
        case .health: return "Salud"
        case .leisure: return "Ocio"
        case .culture: return "Cultura"
        case .outdoors: return "Parques y naturaleza"
        case .sports: return "Deporte"
        case .transport: return "Transporte"
        case .education: return "Educación y trabajo"
        case .lodging: return "Alojamiento"
        case .services: return "Servicios"
        case .privatePlaces: return "Personales"
        case .others: return "Otros"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .food: return "fork.knife"
        case .cafes: return "cup.and.saucer.fill"
        case .shopping: return "bag.fill"
        case .health: return "cross.case.fill"
        case .leisure: return "sparkles.tv.fill"
        case .culture: return "building.columns.fill"
        case .outdoors: return "leaf.fill"
        case .sports: return "figure.run"
        case .transport: return "tram.fill"
        case .education: return "books.vertical.fill"
        case .lodging: return "bed.double.fill"
        case .services: return "wrench.adjustable.fill"
        case .privatePlaces: return "house.fill"
        case .others: return "mappin.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .indigo
        case .food: return .orange
        case .cafes: return .brown
        case .shopping: return .blue
        case .health: return .red
        case .leisure: return .purple
        case .culture: return .pink
        case .outdoors: return .green
        case .sports: return .mint
        case .transport: return .teal
        case .education: return .indigo
        case .lodging: return .cyan
        case .services: return .gray
        case .privatePlaces: return .yellow
        case .others: return .secondary
        }
    }
}

struct LocalizedPlaceCategory {
    let label: String
    let group: PlaceGroup
}

enum PlaceTaxonomy {
    private static func simplified(_ string: String) -> String {
        string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
            .replacingOccurrences(of: "mkpoicategory", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func marketLooksLikeSupermarket(_ name: String) -> Bool {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
        return ["supermercad", "mercadona", "carrefour", "hipercor", "supercor", "lidl", "aldi", "alcampo", "eroski", "ahorramas", "caprabo", "bonarea", "consum", "condis", "alimerka", "dia market", "supermercados dia"].contains(where: { folded.contains($0) })
    }

    static func classify(_ category: String, name: String, personal: Bool = false) -> LocalizedPlaceCategory {
        let key = simplified(category)
        func result(_ label: String, _ group: PlaceGroup) -> LocalizedPlaceCategory {
            LocalizedPlaceCategory(label: label, group: group)
        }
        if personal {
            switch key {
            case "casa", "home", "domicilio": return result("Casa", .privatePlaces)
            case "amigos", "friend", "friends": return result("Casa de amigos", .privatePlaces)
            case "trabajo", "work": return result("Trabajo", .privatePlaces)
            default:
                let value = category.trimmingCharacters(in: .whitespacesAndNewlines)
                return result(value.isEmpty ? "Lugar privado" : value, .privatePlaces)
            }
        }
        switch key {
        // Restauración y alimentación.
        case "restaurant", "restaurante": return result("Restaurante", .food)
        case "fastfood", "comidarapida": return result("Comida rápida", .food)
        case "foodcourt": return result("Zona de restauración", .food)
        case "foodmarket", "market", "alimentacion", "mercado":
            return marketLooksLikeSupermarket(name) ? result("Supermercado", .shopping) : result("Alimentación y mercados", .shopping)
        case "supermarket", "supermercado": return result("Supermercado", .shopping)
        case "convenience", "grocery", "general": return result("Alimentación", .shopping)
        case "bakery", "panaderia": return result("Panadería", .shopping)
        case "butcher", "carniceria": return result("Carnicería", .shopping)
        case "greengrocer", "verduleria", "fruteria": return result("Frutería", .shopping)
        case "seafood", "fishmonger": return result("Pescadería", .shopping)
        case "cafe", "coffee", "coffeehouse", "cafeteria": return result("Cafetería", .cafes)
        case "bar": return result("Bar", .cafes)
        case "pub": return result("Pub", .cafes)
        case "nightlife", "nightclub": return result("Vida nocturna", .leisure)
        case "brewery": return result("Cervecería", .cafes)
        case "winery", "wine": return result("Bodega y vinos", .shopping)
        case "distillery": return result("Destilería", .shopping)
        case "icecream", "icecreamshop": return result("Heladería", .food)
        // Tiendas; una categoría genérica no se convierte en una categoría específica sin evidencia.
        case "store", "shop", "tienda", "comercio": return result("Tienda", .shopping)
        case "clothes", "clothing", "fashion": return result("Moda", .shopping)
        case "shoes": return result("Zapatería", .shopping)
        case "books", "bookshop": return result("Librería", .shopping)
        case "electronics": return result("Electrónica", .shopping)
        case "departmentstore": return result("Grandes almacenes", .shopping)
        case "mall", "shoppingcenter": return result("Centro comercial", .shopping)
        case "hardware": return result("Ferretería", .shopping)
        case "furniture": return result("Muebles", .shopping)
        case "florist": return result("Floristería", .shopping)
        case "beauty", "cosmetics": return result("Belleza", .shopping)
        case "hairdresser", "barbershop": return result("Peluquería", .services)
        // Sanidad y seguridad.
        case "pharmacy", "farmacia": return result("Farmacia", .health)
        case "hospital": return result("Hospital", .health)
        case "clinic", "doctors", "doctor", "dentist": return result("Centro sanitario", .health)
        case "veterinary", "veterinarian", "animalservice": return result("Servicios para animales", .health)
        case "police": return result("Policía", .services)
        case "firestation": return result("Bomberos", .services)
        // Ocio, cultura y espacios públicos.
        case "movietheater", "cinema": return result("Cine", .leisure)
        case "theater", "theatre": return result("Teatro", .culture)
        case "museum": return result("Museo", .culture)
        case "library", "biblioteca": return result("Biblioteca", .culture)
        case "musicvenue", "concert", "concertvenue": return result("Música en directo", .leisure)
        case "amusementpark", "themepark": return result("Parque de atracciones", .leisure)
        case "aquarium": return result("Acuario", .leisure)
        case "zoo": return result("Zoo", .leisure)
        case "casino": return result("Casino", .leisure)
        case "planetarium": return result("Planetario", .culture)
        case "castle", "fortress", "landmark", "nationalmonument", "monument": return result("Monumento", .culture)
        case "park", "nationalpark", "nature", "garden": return result("Parque o jardín", .outdoors)
        case "beach": return result("Playa", .outdoors)
        case "campground", "campsite": return result("Camping", .outdoors)
        case "marina": return result("Puerto deportivo", .outdoors)
        case "sportscentre", "sportscenter", "fitnesscentre", "fitnesscenter", "gym", "gimnasio": return result("Gimnasio o centro deportivo", .sports)
        case "stadium": return result("Estadio", .sports)
        case "swimmingpool": return result("Piscina", .sports)
        // Movilidad.
        case "airport": return result("Aeropuerto", .transport)
        case "trainstation", "railwaystation": return result("Estación de tren", .transport)
        case "busstation": return result("Estación de autobuses", .transport)
        case "busstop": return result("Parada de autobús", .transport)
        case "subwaystation", "metrostation": return result("Metro", .transport)
        case "parking", "parkinggarage": return result("Aparcamiento", .transport)
        case "gasstation", "fuel", "petrolstation": return result("Gasolinera", .transport)
        case "carrepair": return result("Taller de coches", .services)
        case "carwash": return result("Lavado de coches", .services)
        case "bicyclerental", "bicycleshop": return result("Bicicletas", .transport)
        // Educación, alojamientos y servicios.
        case "school", "colegio": return result("Colegio", .education)
        case "university": return result("Universidad", .education)
        case "college": return result("Centro educativo", .education)
        case "office", "oficina", "workplace": return result("Oficina", .education)
        case "hotel": return result("Hotel", .lodging)
        case "motel": return result("Motel", .lodging)
        case "hostel": return result("Hostal", .lodging)
        case "guesthouse": return result("Pensión", .lodging)
        case "atm": return result("Cajero automático", .services)
        case "bank": return result("Banco", .services)
        case "postoffice": return result("Correos", .services)
        case "townhall", "cityhall": return result("Ayuntamiento", .services)
        case "courthouse": return result("Juzgados", .services)
        case "religioussite", "placeofworship": return result("Lugar de culto", .services)
        case "spa": return result("Spa", .services)
        case "laundry", "drycleaning": return result("Lavandería o tintorería", .services)
        case "toilets": return result("Aseos públicos", .services)
        case "personal": return result("Personal", .privatePlaces)
        case "otro", "otros", "other", "unknown", "establecimiento", "": return result("Sin clasificar", .others)
        default:
            // Una categoría escrita por el usuario se conserva, pero no mostramos códigos de MapKit ni etiquetas OSM en inglés.
            if category.localizedCaseInsensitiveContains("MKPOICategory") { return result("Sin clasificar", .others) }
            if category.rangeOfCharacter(from: CharacterSet(charactersIn: "_")) != nil { return result("Sin clasificar", .others) }
            return result(category, .others)
        }
    }
}

extension PlaceCandidate {
    var categoryLabel: String {
        PlaceTaxonomy.classify(category, name: name, personal: source == .personal).label
    }
    var categoryGroup: PlaceGroup {
        PlaceTaxonomy.classify(category, name: name, personal: source == .personal).group
    }
}

extension Place {
    var categoryLabel: String {
        PlaceTaxonomy.classify(category, name: name, personal: isPrivate).label
    }
    var categoryGroup: PlaceGroup {
        PlaceTaxonomy.classify(category, name: name, personal: isPrivate).group
    }
}
