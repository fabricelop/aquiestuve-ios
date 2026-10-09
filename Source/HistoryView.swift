import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: VisitStore
    @State private var unresolvedOnly = false
    private var entries: [Stay] {
        store.stays.filter { !unresolvedOnly || $0.placeID == nil }
            .sorted { $0.arrival > $1.arrival }
    }
    var body: some View {
        List {
            Section {
                Toggle("Solo sin identificar", isOn: $unresolvedOnly)
            }
            ForEach(entries) { stay in
                NavigationLink {
                    EditVisitView(visit: stay)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(store.place(for: stay)?.name ?? "Sin identificar")
                                .font(.headline)
                            if stay.status == .unresolved {
                                Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
                            }
                        }
                        Text(stay.arrival.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("\(stay.duration.readableDuration) · \(stay.departure == nil ? "En curso" : "Finalizada")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { entries[$0].id }
                for id in ids { store.deleteVisit(id) }
            }
        }
        .navigationTitle("Historial")
        .overlay {
            if store.stays.isEmpty {
                ContentUnavailableView("Todavía no hay visitas", systemImage: "clock",
                    description: Text("Las estancias detectadas y confirmadas aparecerán aquí."))
            }
        }
    }
}

struct EditVisitView: View {
    @EnvironmentObject private var store: VisitStore
    @Environment(\.dismiss) private var dismiss
    let visit: Stay
    @State private var arrival: Date
    @State private var departure: Date
    @State private var isOpen: Bool
    @State private var selectedPlaceID: UUID?

    init(visit: Stay) {
        self.visit = visit
        _arrival = State(initialValue: visit.arrival)
        _departure = State(initialValue: visit.departure ?? Date())
        _isOpen = State(initialValue: visit.departure == nil)
        _selectedPlaceID = State(initialValue: visit.placeID)
    }
    var body: some View {
        Form {
            Section("Lugar") {
                Picker("Establecimiento", selection: $selectedPlaceID) {
                    Text("Sin identificar").tag(nil as UUID?)
                    ForEach(store.places.sorted { $0.name < $1.name }) { place in
                        Text(place.name).tag(Optional(place.id))
                    }
                }
                Text("Si no aparece, créalo primero en la pestaña Lugares.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Horarios") {
                DatePicker("Llegada", selection: $arrival, displayedComponents: [.date, .hourAndMinute])
                Toggle("Visita todavía en curso", isOn: $isOpen)
                if !isOpen {
                    DatePicker("Salida", selection: $departure, in: arrival..., displayedComponents: [.date, .hourAndMinute])
                }
            }
            Section {
                Button("Guardar corrección") {
                    store.updateVisit(visit, arrival: arrival, departure: isOpen ? nil : max(arrival, departure),
                                      placeID: selectedPlaceID)
                    dismiss()
                }
                Button("Eliminar visita", role: .destructive) {
                    store.deleteVisit(visit.id)
                    dismiss()
                }
            }
        }
        .navigationTitle("Corregir visita")
        .navigationBarTitleDisplayMode(.inline)
    }
}
