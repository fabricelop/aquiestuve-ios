import SwiftUI

struct SavedPlacesView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var location: LocationService
    @State private var query = ""
    @State private var addPlace = false
    @State private var placeToDelete: Place?

    private var filtered: [Place] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.places
            .filter { needle.isEmpty || $0.name.localizedStandardContains(needle)
                || $0.categoryLabel.localizedStandardContains(needle) }
            .sorted {
                let lhs = store.visitCount(for: $0)
                let rhs = store.visitCount(for: $1)
                if lhs != rhs { return lhs > rhs }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var createdByMe: [Place] { filtered.filter { $0.isPrivate } }
    private var registeredVisits: [Place] { filtered.filter { !$0.isPrivate } }

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
            Section {
                Text("Aquí se guardan tanto los sitios que creas como los establecimientos que confirmas al registrar visitas. No es la lista completa de lugares cercanos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Creados por mí · \(createdByMe.count)") {
                if createdByMe.isEmpty {
                    Text(query.isEmpty ? "Todavía no has creado lugares privados." : "No hay coincidencias.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(createdByMe) { place in
                    placeLink(place)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Borrar", role: .destructive) { placeToDelete = place }
                        }
                }
            }
            Section("Establecimientos registrados · \(registeredVisits.count)") {
                if registeredVisits.isEmpty {
                    Text(query.isEmpty ? "Aparecerán cuando confirmes visitas a establecimientos." : "No hay coincidencias.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(registeredVisits) { place in
                    placeLink(place)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Borrar", role: .destructive) { placeToDelete = place }
                        }
                }
            }
        }
        .searchable(text: $query, prompt: "Buscar mis lugares")
        .navigationTitle("Mis lugares")
        .confirmationDialog(
            "Eliminar \(placeToDelete?.name ?? "lugar") de Mis lugares",
            isPresented: Binding(
                get: { placeToDelete != nil },
                set: { if !$0 { placeToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let place = placeToDelete {
                Button("Quitar lugar y conservar visitas sin identificar") {
                    store.deletePlace(place, deleteVisits: false)
                    placeToDelete = nil
                }
                Button("Eliminar lugar y sus visitas", role: .destructive) {
                    store.deletePlace(place, deleteVisits: true)
                    placeToDelete = nil
                }
            }
            Button("Cancelar", role: .cancel) { placeToDelete = nil }
        } message: {
            Text("Si eliminas las visitas, se borrarán también de tus estadísticas. Esta acción no se puede deshacer.")
        }
        .sheet(isPresented: $addPlace) {
            if let point = location.coordinate { CreatePlaceView(initial: point) }
        }
    }

    private func placeLink(_ place: Place) -> some View {
        NavigationLink {
            PlaceDetailsView(place: place)
        } label: {
            placeRow(place)
        }
    }

    private func placeRow(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(place.name, systemImage: place.categoryGroup.symbol)
                .font(.headline).foregroundStyle(place.categoryGroup.color)
            Text("\(place.categoryLabel) · \(store.visitCount(for: place)) visitas · \(store.totalTime(for: place).readableDuration)")
                .font(.caption).foregroundStyle(.secondary)
            if place.isPrivate {
                Label("Creado por ti · Privado", systemImage: "lock.fill")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

struct PlaceDetailsView: View {
    @EnvironmentObject private var store: VisitStore
    @Environment(\.dismiss) private var dismiss
    let place: Place
    @State private var name: String
    @State private var category: String
    @State private var confirmDelete = false
    init(place: Place) {
        self.place = place
        _name = State(initialValue: place.name)
        _category = State(initialValue: place.categoryLabel)
    }
    var body: some View {
        Form {
            Section("Lugar") {
                TextField("Nombre", text: $name)
                TextField("Categoría", text: $category)
                Menu("Elegir categoría habitual") {
                    ForEach(["Restaurante", "Cafetería", "Bar", "Supermercado", "Tienda",
                             "Farmacia", "Parque", "Gimnasio", "Hotel", "Oficina", "Casa", "Otro"], id: \.self) { option in
                        Button(option) { category = option }
                    }
                }
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
                Button("Eliminar de Mis lugares", role: .destructive) {
                    confirmDelete = true
                }
            }
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Eliminar \(place.name) de Mis lugares", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Quitar lugar y conservar visitas sin identificar") {
                store.deletePlace(place, deleteVisits: false)
                dismiss()
            }
            Button("Eliminar lugar y sus visitas", role: .destructive) {
                store.deletePlace(place, deleteVisits: true)
                dismiss()
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Borrar las visitas eliminará sus tiempos y recuentos de las estadísticas. No se puede deshacer.")
        }
    }
}
