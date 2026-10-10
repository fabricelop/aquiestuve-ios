import SwiftUI
import MapKit

struct NowView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var location: LocationService
    @StateObject private var search = NearbySearch()
    @State private var radius = 250.0
    @State private var showAll = false
    @State private var selectedGroup: PlaceGroup = .all
    @State private var createPlace = false
    @State private var placeQuery = ""
    @State private var previewPlace: PlaceCandidate?
    @FocusState private var isSearching: Bool

    private var matchingPlaces: [PlaceCandidate] {
        let normalized = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return search.candidates.filter { candidate in
            (selectedGroup == .all || candidate.categoryGroup == selectedGroup) &&
            (normalized.isEmpty || [candidate.name, candidate.categoryLabel, candidate.address ?? ""]
                .contains { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .contains(normalized) })
        }
    }
    // Filtering always scans the complete results, not just the seven suggested rows.
    private var displayed: [PlaceCandidate] {
        let filtering = selectedGroup != .all || !placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return showAll || filtering ? matchingPlaces : Array(matchingPlaces.prefix(7))
    }

    private var availableGroups: [PlaceGroup] {
        [.all] + PlaceGroup.allCases.filter { group in
            group != .all && search.candidates.contains(where: { $0.categoryGroup == group })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let stay = store.activeStay {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(stay.status == .unresolved ? "Visita pendiente" : "Visita actual", systemImage: "location.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Text(store.place(for: stay)?.name ?? "¿Dónde estás?")
                            .font(.title2.bold())
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Text("Desde \(stay.arrival.formatted(date: .omitted, time: .shortened)) · \(stay.duration(asOf: context.date).readableDuration)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(stay.status == .automatic ? "Identificado automáticamente; puedes corregirlo" :
                             stay.status == .confirmed ? "Confirmado" : "Elige un lugar de la lista")
                            .font(.caption).foregroundStyle(stay.status == .unresolved ? .orange : .green)
                        Button("Finalizar estancia") { store.endCurrent() }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    Label("Sin estancia activa · selecciona un lugar o espera la detección automática",
                          systemImage: "location.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if location.authorization == .notDetermined {
                    Button("Activar ubicación") { location.requestAccess() }
                        .buttonStyle(.borderedProminent)
                } else if location.authorization == .denied || location.authorization == .restricted {
                    Label("Activa el acceso a la ubicación en Ajustes del iPhone", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }

                if let position = location.coordinate {
                    if let accuracy = location.accuracy, accuracy > 100 {
                        Label("Precisión aproximada: \(accuracy.readableDistance). Confirma el lugar manualmente.",
                              systemImage: "location.slash.circle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Map(initialPosition: .region(MKCoordinateRegion(center: position.coordinate,
                          span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007)))) {
                        UserAnnotation()
                        ForEach(matchingPlaces) { item in
                            Annotation(item.name, coordinate: item.position.coordinate) {
                                Button {
                                    isSearching = false
                                    previewPlace = item
                                } label: {
                                    Image(systemName: item.categoryGroup.symbol)
                                        .font(.title2)
                                        .foregroundStyle(item.categoryGroup.color)
                                        .padding(4)
                                        .background(.regularMaterial, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Ver ficha: \(item.name)")
                            }
                        }
                    }
                    .frame(height: 225)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .accessibilityLabel("Mapa de establecimientos cercanos")

                    HStack {
                        Text("Lugares cercanos").font(.title3.bold())
                        Spacer()
                        if search.loading { ProgressView() }
                        Button { location.refreshPosition(); Task { await search.search(near: position, radius: radius, force: true) } } label: {
                            Image(systemName: "arrow.clockwise")
                        }.accessibilityLabel("Actualizar lugares")
                    }
                    Picker("Radio", selection: $radius) {
                        Text("100 m").tag(100.0)
                        Text("250 m").tag(250.0)
                        Text("500 m").tag(500.0)
                        Text("1 km").tag(1000.0)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: radius) { _, newValue in
                        Task { await search.search(near: position, radius: newValue) }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Buscar sitio, calle o categoría", text: $placeQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($isSearching)
                            .onSubmit { isSearching = false }
                            .accessibilityLabel("Filtrar lugares cercanos")
                        if !placeQuery.isEmpty {
                            Button {
                                placeQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Borrar búsqueda")
                        }
                    }
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableGroups) { group in
                                Button {
                                    selectedGroup = group
                                } label: {
                                    Label(group.title, systemImage: group.symbol)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(selectedGroup == group ? group.color.opacity(0.2) : Color.secondary.opacity(0.1),
                                                    in: Capsule())
                                        .overlay(Capsule().strokeBorder(selectedGroup == group ? group.color : .clear,
                                                                        lineWidth: 1.4))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
                            }
                        }
                    }
                    .accessibilityLabel("Filtrar lugares por categoría")
                    HStack {
                        Text(placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedGroup == .all
                             ? "\(search.candidates.count) encontrados · Apple: \(search.appleCount) · OSM: \(search.osmCount)"
                             : "\(matchingPlaces.count) coincidencias de \(search.candidates.count) lugares")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedGroup == .all {
                            Button(showAll ? "Sugeridos" : "Ver todos") { showAll.toggle() }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    ForEach(displayed) { item in
                        HStack(spacing: 10) {
                            Button {
                                isSearching = false
                                previewPlace = item
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.categoryGroup.symbol)
                                        .font(.title2).foregroundStyle(item.categoryGroup.color)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name).fontWeight(.semibold).foregroundStyle(.primary)
                                        Text("\(item.categoryLabel) · \(item.distance.readableDistance)" +
                                             (item.visits > 0 ? " · \(item.visits) visitas" : ""))
                                            .font(.caption).foregroundStyle(.secondary)
                                        if let address = item.address, !address.isEmpty {
                                            Text(address).font(.caption2).foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    if store.activeStay?.placeID == item.savedID && item.savedID != nil {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ver lugar y confirmar: \(item.name)")
                            Button {
                                isSearching = false
                                previewPlace = item
                            } label: {
                                Image(systemName: "map")
                                    .font(.title3)
                                    .frame(width: 34, height: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Ver en mapa: \(item.name)")
                        }
                        Divider()
                    }
                    if matchingPlaces.isEmpty && (!placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedGroup != .all) {
                        Text("No hay coincidencias en los lugares cargados. Amplía el radio, usa OSM o crea uno nuevo.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if search.candidates.isEmpty && !search.loading {
                        Text("No hay resultados todavía. Prueba a actualizar, ampliar el radio o crear un lugar.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button { Task { await search.addOSM(near: position, radius: radius) } } label: {
                            Label("Buscar más (OSM)", systemImage: "globe.europe.africa")
                        }
                        .buttonStyle(.bordered)
                        .disabled(search.loading)
                        Button { createPlace = true } label: {
                            Label("Crear lugar", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if let warning = search.warning {
                        Text(warning).font(.caption).foregroundStyle(.orange)
                    }
                    Text("OSM amplía la lista con lugares del mapa colaborativo (máx. 700 m, consulta manual cada 10 min). © OpenStreetMap contributors.")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Button("Buscar mi posición") { location.refreshPosition() }
                        .disabled(location.authorization != .authorizedAlways && location.authorization != .authorizedWhenInUse)
                    if let error = location.errorText { Text(error).font(.caption).foregroundStyle(.orange) }
                }
            }
            .padding()
        }
        .navigationTitle("AquíEstuve")
        .task(id: location.coordinate) {
            if let point = location.coordinate { await search.search(near: point, radius: radius) }
        }
        .onAppear { location.refreshPosition() }
        .sheet(isPresented: $createPlace) {
            if let point = location.coordinate { CreatePlaceView(initial: point) }
        }
        .sheet(item: $previewPlace) { item in
            NearbyPlacePreview(item: item) {
                store.assign(item)
                previewPlace = nil
            }
        }
    }
}

private struct NearbyPlacePreview: View {
    @Environment(\.dismiss) private var dismiss
    let item: PlaceCandidate
    let confirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.name).font(.title2.bold())
                    Text("\(item.categoryLabel) · \(item.distance.readableDistance) de tu posición")
                        .foregroundStyle(.secondary)
                    if let address = item.address, !address.isEmpty {
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: item.position.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)))) {
                        Marker(item.name, coordinate: item.position.coordinate)
                    }
                    .frame(height: 350)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    Text("Revisa el pin antes de confirmar. El registro de la visita solo cambia cuando pulses el botón de confirmación.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Confirmar que estoy aquí") { confirm() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("Ubicación del lugar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
