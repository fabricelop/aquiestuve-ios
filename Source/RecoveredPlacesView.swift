import SwiftUI

/// Archive, local suppression and temporary silence are always reversible.
struct RecoveredPlacesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var preferences = RadarPreferencesStore.shared
    @State private var query = ""

    private var items: [RecoveredRadarItem] {
        preferences.recoverable.filter { pair in
            query.isEmpty || pair.rule.name.localizedStandardContains(query) ||
                pair.rule.category.localizedStandardContains(query)
        }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Nada se borra definitivamente. Puedes recuperar un sitio silenciado, oculto en una zona o archivado de las sugerencias. También aparecerá en la Guía.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if items.isEmpty {
                    ContentUnavailableView("No hay lugares descartados", systemImage: "tray")
                }
                ForEach(items) { pair in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(pair.rule.name.isEmpty ? "Lugar sin nombre" : pair.rule.name)
                                .font(.headline)
                            Text(pair.rule.category).font(.caption).foregroundStyle(.secondary)
                            if pair.rule.archived {
                                Label("Archivado", systemImage: "archivebox")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if let until = pair.rule.snoozedUntil {
                                Text(until > Date() ? "Silenciado hasta \(until.formatted(date: .abbreviated, time: .shortened))" :
                                    "Silencio temporal finalizado")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if !pair.rule.hiddenAround.isEmpty {
                                Text("Oculto en \(pair.rule.hiddenAround.count) zona(s)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Button("Recuperar") { preferences.restore(pair.key) }
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $query, prompt: "Buscar descartados")
            .navigationTitle("Descartados")
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Cerrar") { dismiss() }
            }}
        }
    }
}
