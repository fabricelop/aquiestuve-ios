import SwiftUI

/// Merge only after two explicit choices: selecting the other record and confirming it.
/// Works for stored visits and for two unvisited public-map candidates.
struct DuplicateMergeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: VisitStore
    let primary: PlaceCandidate
    let options: [PlaceCandidate]
    let onMerged: () -> Void
    @State private var query = ""
    @State private var selected: PlaceCandidate?

    private var alternatives: [PlaceCandidate] {
        var seen = Set<String>()
        return options.filter {
            $0.id != primary.id && seen.insert($0.id).inserted &&
            (query.isEmpty || $0.name.localizedStandardContains(query) ||
             $0.categoryLabel.localizedStandardContains(query))
        }.sorted {
            if $0.position.distance(to: primary.position) != $1.position.distance(to: primary.position) {
                return $0.position.distance(to: primary.position) < $1.position.distance(to: primary.position)
            }
            return $0.name < $1.name
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Lugar que conservaremos") {
                    Label(primary.name, systemImage: primary.displaySymbol)
                    Text("Las visitas y categorías personales se conservarán. No se añadirá ninguna visita nueva.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("¿Qué otro nombre representa el mismo sitio?") {
                    ForEach(alternatives) { alternative in
                        Button {
                            selected = alternative
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(alternative.name).fontWeight(.semibold).foregroundStyle(.primary)
                                Text("\(alternative.categoryLabel) · \(alternative.position.distance(to: primary.position).readableDistance) entre los dos puntos")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Buscar el nombre duplicado")
            .navigationTitle("Unir lugares repetidos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Cerrar") { dismiss() }
            } }
            .confirmationDialog("¿Son exactamente el mismo establecimiento?", isPresented: Binding(
                get: { selected != nil }, set: { if !$0 { selected = nil } }
            ), titleVisibility: .visible) {
                if let target = selected {
                    Button("Sí, fusionar \(target.name) con \(primary.name)") {
                        if store.mergeCandidates(primary: primary, duplicate: target) {
                            onMerged()
                        }
                        selected = nil
                        dismiss()
                    }
                }
                Button("Cancelar", role: .cancel) { selected = nil }
            } message: {
                Text("Se recordarán ambos nombres de mapa como un solo lugar. Las visitas asociadas se unificarán y las que se solapen no contarán dos veces.")
            }
        }
    }
}

struct DuplicateSuggestion: Identifiable {
    let primary: PlaceCandidate
    let other: PlaceCandidate
    var id: String { primary.id + "|" + other.id }
}

enum DuplicateSuggester {
    private static let genericWords: Set<String> = ["supermercado", "supermercados", "tienda", "tiendas", "market", "centro", "local"]
    private static func meaningful(_ input: String) -> String {
        let raw = input.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let words = raw.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !genericWords.contains($0) }
        return words.joined(separator: " ")
    }

    /// Suggestions only. Never changes stored data automatically.
    static func suggest(_ candidates: [PlaceCandidate]) -> [DuplicateSuggestion] {
        let pool = Array(candidates.prefix(150))
        var results: [DuplicateSuggestion] = []
        for i in pool.indices {
            for j in pool.indices where j > i {
                let a = pool[i], b = pool[j]
                guard a.id != b.id && a.categoryGroup == b.categoryGroup &&
                      a.position.distance(to: b.position) <= 55 else { continue }
                let x = meaningful(a.name), y = meaningful(b.name)
                guard !x.isEmpty, x == y && x.count >= 3 else { continue }
                results.append(DuplicateSuggestion(primary: a, other: b))
                if results.count >= 6 { return results }
            }
        }
        return results
    }
}
