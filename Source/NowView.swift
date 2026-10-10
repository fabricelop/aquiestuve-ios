import SwiftUI
import MapKit

struct NowView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var location: LocationService
    @StateObject private var search = NearbySearch()
    @AppStorage("ae_show_map") private var showMap = true
    @State private var radius = 250.0
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var fullMap = false
    @State private var showAll = false
    @State private var selectedGroup: PlaceGroup = .all
    @State private var createPlace = false
    @State private var placeQuery = ""
    @State private var searchRadius = 3000.0
    @State private var remoteMode = ""
    @State private var previewPlace: PlaceCandidate?
    @FocusState private var isSearching: Bool

    private var matchingPlaces: [PlaceCandidate] {
        let normalized = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        var pool = search.candidates.map { original in
            var item = original
            item.category = store.preferredCategory(for: original)
            return item
        }
        if remoteMode == "name:" + normalized ||
           (remoteMode == "group:" + selectedGroup.rawValue && selectedGroup != .all) {
            var seen = Set(pool.map(\.id))
            for original in search.nameResults where seen.insert(original.id).inserted {
                var item = original
                item.category = store.preferredCategory(for: original)
                pool.append(item)
            }
        }
        let remoteIDs = Set(search.nameResults.map(\.id))
        return pool.filter { item in
            (selectedGroup == .all || item.categoryGroup == selectedGroup) &&
            (normalized.isEmpty || [item.name, item.categoryLabel, item.address ?? ""]
                .contains { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .contains(normalized) } ||
             (remoteMode == "name:" + normalized && remoteIDs.contains(item.id)))
        }.sorted { lhs, rhs in
            if lhs.visits > 0 && rhs.visits == 0 && normalized.isEmpty { return true }
            if rhs.visits > 0 && lhs.visits == 0 && normalized.isEmpty { return false }
            return lhs.distance < rhs.distance
        }
    }

    private var displayed: [PlaceCandidate] {
        let filterActive = selectedGroup != .all || !placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return showAll || filterActive ? matchingPlaces : Array(matchingPlaces.prefix(7))
    }

    private var availableGroups: [PlaceGroup] {
        PlaceGroup.allCases
    }

    private func mapRegion(_ center: GeoPoint, radius: Double) -> MKCoordinateRegion {
        let latMeters = max(300, radius * 2.3)
        return MKCoordinateRegion(center: center.coordinate,
                                  latitudinalMeters: latMeters,
                                  longitudinalMeters: latMeters)
    }

    private func namedSearch(near center: GeoPoint) {
        let key = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 2 else { return }
        remoteMode = "name:" + key.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        isSearching = false
        Task { await search.searchByName(key, near: center, radius: searchRadius) }
    }

    private func categorySearch(near center: GeoPoint) {
        guard selectedGroup != .all else { return }
        placeQuery = ""
        remoteMode = "group:" + selectedGroup.rawValue
        let term: String
        switch selectedGroup {
        case .food: term = "restaurantes"
        case .cafes: term = "cafeterías y bares"
        case .shopping: term = "tiendas"
        case .health: term = "farmacias y centros de salud"
        case .sports: term = "centros deportivos"
        case .outdoors: term = "parques"
        default: term = selectedGroup.title
        }
        Task { await search.searchByName(term, near: center, radius: searchRadius) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let stay = store.activeStay {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(stay.status == .unresolved ? "Visita pendiente" : "Visita actual", systemImage: "location.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        Text(store.place(for: stay)?.name ?? "¿Dónde estás?")
                            .font(.title2.bold())
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Text("Desde \(stay.arrival.formatted(date: .omitted, time: .shortened)) · \(stay.duration(asOf: context.date).readableDuration)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(stay.status == .unresolved ? "Puedes identificar esta parada en Historial" :
                             stay.status == .automatic ? "Identificada automáticamente; revisable" : "Confirmada")
                            .font(.caption).foregroundStyle(stay.status == .unresolved ? .orange : .green)
                        Button("Finalizar estancia") { store.endCurrent() }.buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                } else {
                    Label("Sin estancia activa · selecciona un sitio o espera una detección",
                          systemImage: "location.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if location.authorization == .notDetermined {
                    Button("Activar ubicación") { location.requestAccess() }.buttonStyle(.borderedProminent)
                } else if location.authorization == .denied || location.authorization == .restricted {
                    Label("Activa la ubicación en Ajustes de iOS", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }

                if let position = location.coordinate {
                    HStack {
                        Button {
                            showMap.toggle()
                        } label: {
                            Label(showMap ? "Ocultar mapa" : "Mostrar mapa", systemImage: showMap ? "map.fill" : "map")
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        if showMap {
                            Button {
                                fullMap = true
                            } label: { Label("Pantalla completa", systemImage: "arrow.up.left.and.arrow.down.right") }
                                .buttonStyle(.bordered)
                        }
                    }
                    if showMap {
                        Map(position: $mapPosition, interactionModes: .all) {
                            UserAnnotation()
                            ForEach(matchingPlaces) { item in
                                Annotation(item.name, coordinate: item.position.coordinate) {
                                    Button { isSearching = false; previewPlace = item } label: {
                                        Image(systemName: item.categoryGroup.symbol)
                                            .font(.title3)
                                            .foregroundStyle(item.categoryGroup.color)
                                            .padding(5)
                                            .background(.regularMaterial, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Ver lugar: \(item.name)")
                                }
                            }
                        }
                        .mapControls { MapCompass(); MapScaleView(); MapUserLocationButton() }
                        .frame(height: 285)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .accessibilityLabel("Mapa interactivo. Pellizca para ampliar y desplázate para explorar.")
                    }
                    HStack {
                        Text("Lugares cercanos").font(.title3.bold())
                        Spacer()
                        if search.loading { ProgressView() }
                        Button {
                            location.refreshPosition()
                            Task { await search.search(near: position, radius: radius, force: true) }
                        } label: { Image(systemName: "arrow.clockwise") }
                            .accessibilityLabel("Actualizar sitios")
                    }
                    Picker("Radio de proximidad", selection: $radius) {
                        Text("100 m").tag(100.0)
                        Text("250 m").tag(250.0)
                        Text("500 m").tag(500.0)
                        Text("1 km").tag(1000.0)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: radius) { _, value in
                        mapPosition = .region(mapRegion(position, radius: value))
                        Task { await search.search(near: position, radius: value) }
                    }
                    Text("Radio actual: \(radius.readableDistance). \(search.candidates.count) sitios cargados." +
                         (search.coverageLimited ? " Apple puede limitar los resultados; pulsa Buscar más por sectores." : ""))
                        .font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Nombre, calle o categoría", text: $placeQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .focused($isSearching)
                            .onSubmit { namedSearch(near: position) }
                        if !placeQuery.isEmpty {
                            Button { placeQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Vaciar búsqueda")
                        }
                    }
                    .padding(11)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Picker("Radio de búsqueda ampliada", selection: $searchRadius) {
                            Text("1 km").tag(1000.0)
                            Text("3 km").tag(3000.0)
                            Text("5 km").tag(5000.0)
                            Text("10 km").tag(10000.0)
                        }
                        .pickerStyle(.menu)
                        Button("Buscar en zona") { namedSearch(near: position) }
                            .buttonStyle(.borderedProminent)
                            .disabled(placeQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || search.loading)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(availableGroups) { group in
                                Button {
                                    selectedGroup = group
                                    remoteMode = ""
                                } label: {
                                    Label(group.title, systemImage: group.symbol)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 9).padding(.vertical, 7)
                                        .background(selectedGroup == group ? group.color.opacity(0.2) : Color.secondary.opacity(0.1), in: Capsule())
                                        .overlay(Capsule().strokeBorder(selectedGroup == group ? group.color : .clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if selectedGroup != .all {
                        Button("Buscar más de \(selectedGroup.title.lowercased()) en \(searchRadius.readableDistance)") {
                            categorySearch(near: position)
                        }
                        .font(.subheadline)
                        .disabled(search.loading)
                    }
                    HStack {
                        Text("\(matchingPlaces.count) coincidencias · Apple: \(search.appleCount) · OSM: \(search.osmCount)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if selectedGroup == .all && placeQuery.isEmpty {
                            Button(showAll ? "Sugeridos" : "Ver todos") { showAll.toggle() }
                                .font(.caption.bold())
                        }
                    }
                    ForEach(displayed) { item in
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
                                        Text(address).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    if matchingPlaces.isEmpty && !search.loading {
                        Text("Sin coincidencias cargadas. Prueba una búsqueda ampliada, OSM o crea el lugar.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Button { Task { await search.expandNearby(near: position, radius: radius) } } label: {
                            Label("Más por sectores", systemImage: "square.grid.2x2")
                        }
                        .buttonStyle(.bordered).disabled(search.loading)
                        Button { Task { await search.addOSM(near: position, radius: radius) } } label: {
                            Label("Ampliar con OSM", systemImage: "globe.europe.africa")
                        }
                        .buttonStyle(.bordered).disabled(search.loading)
                    }
                    Button { createPlace = true } label: { Label("Crear lugar privado", systemImage: "plus") }
                        .buttonStyle(.borderedProminent)
                    if let warning = search.warning { Text(warning).font(.caption).foregroundStyle(.orange) }
                    Text("Las búsquedas por texto y sectores son manuales. OSM limita las consultas nuevas a una cada 10 minutos. Los sitios obtenidos no garantizan cobertura completa.")
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
            if let point = location.coordinate {
                mapPosition = .region(mapRegion(point, radius: radius))
                await search.search(near: point, radius: radius)
            }
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
        .fullScreenCover(isPresented: $fullMap) {
            if let point = location.coordinate {
                FullPlaceMap(search: search, center: point, radius: radius) { item in
                    fullMap = false
                    // Defer the second sheet until the full-screen modal is dismissed.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { previewPlace = item }
                }
            }
        }
    }
}

private struct FullPlaceMap: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var search: NearbySearch
    let center: GeoPoint
    let radius: Double
    let onSelect: (PlaceCandidate) -> Void
    @State private var camera: MapCameraPosition
    @State private var visibleCenter: GeoPoint
    @State private var visibleRadius: Double

    init(search: NearbySearch, center: GeoPoint, radius: Double, onSelect: @escaping (PlaceCandidate) -> Void) {
        self.search = search; self.center = center; self.radius = radius; self.onSelect = onSelect
        _camera = State(initialValue: .region(MKCoordinateRegion(center: center.coordinate,
                                  latitudinalMeters: radius * 2.5, longitudinalMeters: radius * 2.5)))
        _visibleCenter = State(initialValue: center)
        _visibleRadius = State(initialValue: radius)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $camera, interactionModes: .all) {
                    UserAnnotation()
                    ForEach(search.candidates + search.exploreResults.filter { new in
                        !search.candidates.contains(where: { $0.id == new.id })
                    }) { item in
                        Annotation(item.name, coordinate: item.position.coordinate) {
                            Button { onSelect(item) } label: {
                                Image(systemName: item.categoryGroup.symbol)
                                    .font(.title2).foregroundStyle(item.categoryGroup.color)
                                    .padding(7).background(.regularMaterial, in: Circle())
                            }
                            .accessibilityLabel("Ver ficha de \(item.name)")
                        }
                    }
                }
                .mapControls { MapCompass(); MapScaleView(); MapUserLocationButton() }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleCenter = GeoPoint(context.region.center)
                    visibleRadius = min(3000, max(100, context.region.span.latitudeDelta * 111000 / 2))
                }
                VStack(spacing: 7) {
                    Button {
                        Task { await search.searchMapArea(near: visibleCenter, radius: visibleRadius) }
                    } label: {
                        Label("Buscar en esta zona", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(search.loading)
                    Text("Mover el mapa no realiza consultas. Pellizca para acercar o alejar.")
                        .font(.caption2).padding(5)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 20)
            }
            .navigationTitle("Explorar mapa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

private struct NearbyPlacePreview: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: VisitStore
    let item: PlaceCandidate
    let confirm: () -> Void
    @State private var category: String
    @State private var customCategory = ""

    init(item: PlaceCandidate, confirm: @escaping () -> Void) {
        self.item = item; self.confirm = confirm
        _category = State(initialValue: item.categoryLabel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.name).font(.title2.bold())
                    Text("\(store.preferredCategory(for: item)) · \(item.distance.readableDistance) de la posición consultada")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let address = item.address, !address.isEmpty {
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: item.position.coordinate,
                        latitudinalMeters: 420, longitudinalMeters: 420))) {
                        Marker(item.name, coordinate: item.position.coordinate)
                    }
                    .mapControls { MapCompass(); MapScaleView() }
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Corregir categoría del lugar").font(.headline)
                        Picker("Categoría", selection: $category) {
                            Text(item.categoryLabel).tag(item.categoryLabel)
                            ForEach(PlaceGroup.allCases.filter {
                                $0 != .all && $0.title != item.categoryLabel
                            }, id: \.rawValue) { group in
                                Text(group.title).tag(group.title)
                            }
                        }
                        TextField("O escribir categoría más concreta", text: $customCategory)
                            .textInputAutocapitalization(.sentences)
                        Button("Guardar categoría sin crear visita") {
                            store.updateCategory(for: item, to: customCategory.isEmpty ? category : customCategory)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    Text("Solo el botón inferior confirma tu presencia. Consultar este sitio o corregir su categoría no registra ninguna visita.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Confirmar que estoy aquí") { confirm() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("Ficha del lugar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}
