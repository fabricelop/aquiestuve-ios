import SwiftUI

/// Selección rápida que conserva el identificador de una parada pendiente o confirmada.
struct QuickPlacePicker: View {
    @EnvironmentObject private var store: VisitStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = NearbySearch()
    let stay: Stay
    @State private var query = ""
    @State private var radius = 500.0
    @State private var createPlace = false
    private var saved: [Place] {
        store.places.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.position.distance(to: stay.position) < $1.position.distance(to: stay.position) }
    }
    private var nearby: [PlaceCandidate] {
        let matches = search.candidates + (query == search.nameQuery ? search.nameResults : [])
        var seen = Set<String>()
        return matches.filter { item in
            seen.insert(item.id).inserted &&
            (query.isEmpty || item.name.localizedCaseInsensitiveContains(query) ||
             (query == search.nameQuery && search.nameResults.contains(item)))
        }.sorted { $0.distance < $1.distance }
    }
    private func confirm(_ candidate: PlaceCandidate) {
        let known = store.stays.contains(where: { $0.id == stay.id })
        store.assign(candidate, to: known ? stay.id : nil)
        dismiss()
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Elige tu ubicación para la parada de \(stay.arrival.formatted(date: .abbreviated, time: .shortened)).")
                        .font(.subheadline)
                    TextField("Nombre o establecimiento", text: $query)
                        .submitLabel(.search)
                        .onSubmit { remoteSearch() }
                    Button("Buscar por nombre") { remoteSearch() }.disabled(query.count < 2)
                    Picker("Distancia", selection: $radius) {
                        Text("250 m").tag(250.0)
                        Text("500 m").tag(500.0)
                        Text("1 km").tag(1000.0)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: radius) { _, value in
                        Task { await search.search(near: stay.position, radius: value) }
                    }
                }
                if !saved.isEmpty {
                    Section("Mis lugares") {
                        ForEach(saved.prefix(30)) { place in
                            Button { confirm(store.savedCandidate(for: place, near: stay.position)) } label: {
                                Label(place.name, systemImage: "bookmark.fill").foregroundStyle(.primary)
                            }
                        }
                    }
                }
                Section("Lugares cercanos") {
                    ForEach(nearby) { item in
                        Button { confirm(item) } label: {
                            VStack(alignment: .leading) {
                                Text(item.name).foregroundStyle(.primary)
                                Text("\(item.categoryLabel) · \(item.distance.readableDistance)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if search.loading { ProgressView() }
                    if let warning = search.warning { Text(warning).font(.caption) }
                }
                Section {
                    Button { createPlace = true } label: {
                        Label("Crear lugar en esta posición", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("¿Dónde estoy?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
            .task { await search.search(near: stay.position, radius: radius) }
            .sheet(isPresented: $createPlace) {
                CreatePlaceView(initial: stay.position, assignToCurrentByDefault: true,
                                visitID: store.stays.contains(where: { $0.id == stay.id }) ? stay.id : nil)
            }
        }
    }
    private func remoteSearch() {
        guard query.count >= 2 else { return }
        Task { await search.searchByName(query, near: stay.position, radius: 3000) }
    }
}
