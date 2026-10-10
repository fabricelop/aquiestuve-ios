import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: VisitStore
    @State private var mode = 0

    private var entries: [Stay] {
        store.stays.filter {
            mode == 0 || (mode == 1 ? $0.placeID == nil : $0.placeID != nil)
        }.sorted { $0.arrival > $1.arrival }
    }
    private var dates: [Date] {
        Array(Set(entries.map { Calendar.current.startOfDay(for: $0.arrival) })).sorted(by: >)
    }

    var body: some View {
        List {
            Section {
                Picker("Mostrar", selection: $mode) {
                    Text("Todas").tag(0)
                    Text("Pendientes").tag(1)
                    Text("Identificadas").tag(2)
                }
                .pickerStyle(.segmented)
                Text("\(store.pendingCount) paradas pendientes. Solo las identificadas cuentan en las estadísticas. Las paradas breves aparecen únicamente si el iPhone llegó a detectarlas.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(dates, id: \.self) { date in
                Section(date.formatted(date: .complete, time: .omitted)) {
                    ForEach(entries.filter { Calendar.current.isDate($0.arrival, inSameDayAs: date) }) { stay in
                        NavigationLink {
                            EditVisitView(visit: stay)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: stay.placeID == nil ? "questionmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(stay.placeID == nil ? .orange : .green)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(store.place(for: stay)?.name ?? "Parada por identificar")
                                        .font(.headline)
                                    Text("\(stay.arrival.formatted(date: .omitted, time: .shortened)) – \(stay.departure?.formatted(date: .omitted, time: .shortened) ?? "en curso")")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text("\(stay.duration.readableDuration) · " +
                                         (stay.origin == "paseo" ? "Posible parada de paseo" :
                                          stay.status == .automatic ? "Identificación automática" :
                                          stay.status == .confirmed ? "Confirmada" : "Pendiente"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
        .navigationTitle("Historial")
        .overlay {
            if store.stays.isEmpty {
                ContentUnavailableView("Todavía no hay visitas", systemImage: "clock",
                    description: Text("Las estancias detectadas aparecerán aquí. Las breves necesitan el modo Paseo y no siempre se detectan."))
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
    @State private var nearby = false
    @State private var createPlace = false

    init(visit: Stay) {
        self.visit = visit
        _arrival = State(initialValue: visit.arrival)
        _departure = State(initialValue: visit.departure ?? Date())
        _isOpen = State(initialValue: visit.departure == nil)
        _selectedPlaceID = State(initialValue: visit.placeID)
    }
    var body: some View {
        Form {
            Section("Lugar registrado") {
                Picker("Lugar", selection: $selectedPlaceID) {
                    Text("Sin identificar").tag(nil as UUID?)
                    ForEach(store.places.sorted { $0.name < $1.name }) { place in
                        Text(place.name).tag(Optional(place.id))
                    }
                }
                Button("Buscar sitio alrededor de esta parada") { nearby = true }
                Button("Crear lugar en esta posición") { createPlace = true }
                Text("La búsqueda usa la posición histórica de la parada, no la posición actual del iPhone.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Horario estimado · corregible") {
                DatePicker("Llegada", selection: $arrival, displayedComponents: [.date, .hourAndMinute])
                Toggle("Visita todavía en curso", isOn: $isOpen)
                if !isOpen {
                    DatePicker("Salida", selection: $departure, in: arrival...,
                               displayedComponents: [.date, .hourAndMinute])
                }
            }
            Section {
                Button("Guardar corrección") {
                    store.updateVisit(visit, arrival: arrival,
                                      departure: isOpen ? nil : max(arrival, departure),
                                      placeID: selectedPlaceID)
                    dismiss()
                }
                Button("Descartar esta parada", role: .destructive) {
                    store.deleteVisit(visit.id)
                    dismiss()
                }
            }
        }
        .navigationTitle("Revisar parada")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $nearby) {
            HistoryNearbyPicker(position: visit.position) { candidate in
                store.assign(candidate, to: visit.id)
                dismiss()
            }
        }
        .sheet(isPresented: $createPlace) {
            CreatePlaceView(initial: visit.position, assignToCurrentByDefault: false)
        }
    }
}

private struct HistoryNearbyPicker: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = NearbySearch()
    let position: GeoPoint
    let onSelect: (PlaceCandidate) -> Void
    @State private var radius = 250.0
    @State private var query = ""
    @State private var selected: PlaceCandidate?

    private var candidates: [PlaceCandidate] {
        let base = search.candidates + (query == search.nameQuery ? search.nameResults : [])
        var ids = Set<String>()
        let remoteIds = Set(search.nameResults.map(\.id))
        return base.filter {
            ids.insert($0.id).inserted &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) ||
             (query == search.nameQuery && remoteIds.contains($0.id)))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Buscar alrededor de la posición registrada ese día.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Nombre del establecimiento", text: $query)
                        .submitLabel(.search)
                        .onSubmit { Task { await search.searchByName(query, near: position, radius: 1000) } }
                    Button("Buscar nombre en 1 km") {
                        Task { await search.searchByName(query, near: position, radius: 1000) }
                    }
                    .disabled(query.count < 2 || search.loading)
                    Picker("Radio cercano", selection: $radius) {
                        Text("100 m").tag(100.0)
                        Text("250 m").tag(250.0)
                        Text("500 m").tag(500.0)
                        Text("1 km").tag(1000.0)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: radius) { _, newValue in
                        Task { await search.search(near: position, radius: newValue) }
                    }
                }
                Section("Sitios encontrados") {
                    ForEach(candidates) { item in
                        Button {
                            selected = item
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name).foregroundStyle(.primary)
                                Text("\(item.categoryLabel) · \(item.distance.readableDistance)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let warning = search.warning { Text(warning).font(.caption) }
                }
            }
            .navigationTitle("Identificar parada")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
            .task { await search.search(near: position, radius: radius) }
            .alert("Confirmar lugar", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
                Button("Cancelar", role: .cancel) { selected = nil }
                Button("Confirmar visita") {
                    if let selected { onSelect(selected) }
                    selected = nil
                }
            } message: {
                Text("Se asignará esta parada a \(selected?.name ?? "el lugar elegido").")
            }
        }
    }
}
