import SwiftUI

struct SavedPlacesView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var location: LocationService
    @State private var query = ""
    @State private var addPlace = false
    private var filtered: [Place] {
        store.places.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { store.visitCount(for: $0) > store.visitCount(for: $1) }
    }
    var body: some View {
        List {
            Section {
                Button {
                    location.refreshPosition()
                    addPlace = true
                } label: {
                    Label("Añadir lugar privado", systemImage: "plus.circle.fill")
                }
                .disabled(location.coordinate == nil)
            }
            Section("Lugares guardados · \(filtered.count)") {
                ForEach(filtered) { place in
                    NavigationLink {
                        PlaceDetailsView(place: place)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name).font(.headline)
                            Text("\(place.category) · \(store.visitCount(for: place)) visitas · \(store.totalTime(for: place).readableDuration)")
                                .font(.caption).foregroundStyle(.secondary)
                            if place.isPrivate { Label("Privado", systemImage: "lock.fill").font(.caption2) }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Buscar mis lugares")
        .navigationTitle("Mis lugares")
        .sheet(isPresented: $addPlace) {
            if let point = location.coordinate { CreatePlaceView(initial: point) }
        }
    }
}

struct PlaceDetailsView: View {
    @EnvironmentObject private var store: VisitStore
    @Environment(\.dismiss) private var dismiss
    let place: Place
    @State private var name: String
    @State private var category: String
    init(place: Place) {
        self.place = place
        _name = State(initialValue: place.name)
        _category = State(initialValue: place.category)
    }
    var body: some View {
        Form {
            Section("Lugar") {
                TextField("Nombre", text: $name)
                TextField("Categoría", text: $category)
                Button("Guardar nombre y categoría") {
                    store.rename(place, name: name, category: category)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("Mis estadísticas") {
                LabeledContent("Visitas", value: "\(store.visitCount(for: place))")
                LabeledContent("Tiempo acumulado", value: store.totalTime(for: place).readableDuration)
                if let last = store.stays.filter({ $0.placeID == place.id }).max(by: { $0.arrival < $1.arrival }) {
                    LabeledContent("Última visita", value: last.arrival.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Section {
                Button("Empezar una visita ahora") {
                    store.addManualVisit(for: place)
                    dismiss()
                }
                if place.isPrivate {
                    Button("Borrar lugar privado", role: .destructive) {
                        store.removePersonalPlace(place)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
