import SwiftUI
import MapKit

/// Place discovery is intentionally manual and separated from recording a visit.
/// Radar-hidden results are excluded by default; the user can opt in to recover them.
struct GuidePlacesView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var location: LocationService
    @Binding var openExplorer: Bool
    @StateObject private var search = NearbySearch()
    @StateObject private var preferences = RadarPreferencesStore.shared
    @State private var area: GeoPoint?
    @State private var destination = ""
    @State private var findingDestination = false
    @State private var category: PlaceGroup = .all
    @State private var detailedCategory = ""
    @State private var chooseDetailedCategory = false
    @State private var keyword = ""
    @State private var showMap = false
    @State private var showSuppressed = false
    @State private var hasLoaded = false
    @State private var selectedItem: PlaceCandidate?
    @State private var message = ""

    private var center: GeoPoint? { area ?? location.coordinate }
    private var pool: [PlaceCandidate] {
        guard let center else { return [] }
        var seen = Set<String>()
        return (search.nameResults + search.candidates + store.places.map {
            store.savedCandidate(for: $0, near: center)
        }).filter { $0.position.distance(to: center) <= 5_000 }
            .filter { seen.insert($0.id).inserted }
    }
    private var results: [PlaceCandidate] {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return pool.filter { place in
            let matchesCurrentRemote = search.nameResults.contains(where: { $0.id == place.id }) &&
                (search.nameQuery == searchTerm(for: category) || search.nameQuery == query)
            let fitsCategory = category == .all || place.categoryGroup == category || matchesCurrentRemote
            let fitsKeyword = query.isEmpty ||
                [place.name, place.categoryLabel, place.address ?? ""].contains {
                    $0.localizedStandardContains(query)
                } || (keywordWasSearched && matchesCurrentRemote)
            let visible = showSuppressed || preferences.isVisible(place, at: center ?? place.position)
            return fitsCategory && fitsKeyword && visible
        }.sorted { $0.distance < $1.distance }
    }
    @State private var keywordWasSearched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            destinationPanel
            categoryChips
            searchInput
            searchActions
            resultContent
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            Task { await loadNearCurrent() }
        }
        .onChange(of: detailedCategory) { _, value in
            guard !value.isEmpty else { return }
            keyword = value
            category = .all
            Task { await searchText() }
        }
        .sheet(isPresented: $chooseDetailedCategory) {
            CategoryPickerView(selection: $detailedCategory)
        }
        .sheet(item: $selectedItem) { item in
            NearbyPlacePreview(item: item, alternatives: pool) {
                store.assign(item)
                selectedItem = nil
            }
        }
    }

    private var destinationPanel: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("GUÍA DE LUGARES", systemImage: "safari.fill")
                        .font(.caption2.weight(.bold)).tracking(1.6)
                        .foregroundStyle(.cyan)
                    Spacer()
                    Text("Sin registrar visitas").font(.caption2).foregroundStyle(.white.opacity(0.75))
                }
                Text("Explora aquí o en cualquier ciudad")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    TextField("Ciudad, barrio o destino", text: $destination)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.search)
                        .onSubmit { Task { await findDestination() } }
                        .padding(11)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                    Button {
                        Task { await findDestination() }
                    } label: {
                        if findingDestination { ProgressView().tint(.white) }
                        else { Image(systemName: "arrow.right.circle.fill").font(.title2) }
                    }
                    .disabled(destination.trimmingCharacters(in: .whitespaces).count < 2 || findingDestination)
                    .accessibilityLabel("Buscar destino")
                    .foregroundStyle(.white)
                }
                Button {
                    area = nil; destination = ""; keywordWasSearched = false
                    Task { await loadNearCurrent() }
                } label: {
                    Label(area == nil ? "Alrededor de mí" : "Volver a mi ubicación", systemImage: "location.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                }
            }
            .padding(17)
            .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading,
                                       endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 22))
    }

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("¿Qué quieres encontrar?").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlaceGroup.allCases) { group in
                        Button {
                            category = group
                            keyword = ""; keywordWasSearched = false
                            Task { await searchCategory() }
                        } label: {
                            Label(group.title, systemImage: group.symbol)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 11).padding(.vertical, 10)
                                .background(category == group ? Color.indigo : Color(uiColor: .secondarySystemBackground),
                                            in: Capsule())
                                .foregroundStyle(category == group ? Color.white : Color.primary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var searchInput: some View {
            HStack(spacing: 8) {
                TextField("Nombre, actividad o tipo concreto", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { Task { await searchText() } }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13))
                Button { chooseDetailedCategory = true } label: {
                    Image(systemName: "square.grid.2x2.fill").font(.title3)
                        .frame(width: 43, height: 43)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13))
                }.accessibilityLabel("Elegir entre 323 categorías")
                Button { Task { await searchText() } } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3).foregroundStyle(.white)
                        .frame(width: 43, height: 43)
                        .background(.indigo, in: RoundedRectangle(cornerRadius: 13))
                }.accessibilityLabel("Buscar establecimientos")
            }
    }

    private var searchActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { Task { await loadNearCurrent() } } label: {
                    Label("Actualizar zona", systemImage: "arrow.clockwise")
                }.buttonStyle(.bordered)
                Button { showMap.toggle() } label: {
                    Label(showMap ? "Lista" : "Mapa", systemImage: showMap ? "list.bullet" : "map")
                }.buttonStyle(.bordered)
                Button("Explorar más") { openExplorer = true }
                    .font(.caption.weight(.semibold))
            }
            if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
            if let warning = search.warning {
                Text(warning).font(.caption).foregroundStyle(.orange)
            }
            if search.loading { ProgressView("Buscando lugares…").font(.caption) }
        }
    }

    private var resultContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(results.count) lugares").font(.headline)
                Spacer()
            }
            Toggle(isOn: $showSuppressed) {
                Label("Mostrar descartados del Radar", systemImage: "eye")
                    .font(.subheadline.weight(.medium))
            }
            .tint(.indigo)
            .accessibilityHint("Permite ver y recuperar lugares archivados, silenciados u ocultos en esta zona")
            if showMap, let center {
                Map(initialPosition: .region(MKCoordinateRegion(center: center.coordinate,
                                      latitudinalMeters: 2200, longitudinalMeters: 2200))) {
                    ForEach(Array(results.prefix(45))) { place in
                        Annotation(place.name, coordinate: place.position.coordinate) {
                            Button { selectedItem = place } label: {
                                Image(systemName: place.displaySymbol)
                                    .font(.caption.bold()).foregroundStyle(.white)
                                    .padding(8).background(.indigo, in: Circle())
                            }
                        }
                    }
                }
                .frame(height: 290)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            LazyVStack(spacing: 9) {
            ForEach(Array(results.prefix(80))) { place in
                GuidePlaceRow(item: place, isFavorite: preferences.rule(for: place).favorite,
                              suppressed: !preferences.isVisible(place, at: center ?? place.position),
                              onOpen: { selectedItem = place },
                              onFavorite: { preferences.toggleFavorite(place) },
                              onRestore: { preferences.restore(place) })
            }
            }
            if !search.loading && results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map.fill").font(.title).foregroundStyle(.indigo)
                    Text("Sin resultados todavía").font(.headline)
                    Text("Elige una categoría o busca un nombre; las consultas se hacen solo cuando lo solicitas.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(24)
            }
        }
    }


    private func loadNearCurrent() async {
        guard let point = center else { message = "Autoriza la ubicación o busca una ciudad."; return }
        message = area == nil ? "Lugares cerca de ti" : "Resultados alrededor del destino elegido"
        await search.search(near: point, radius: 650)
    }
    private func searchCategory() async {
        guard let point = center else { return }
        if category == .all { await loadNearCurrent(); return }
        await search.searchByName(searchTerm(for: category), near: point, radius: 3_000)
    }
    private func searchText() async {
        guard let point = center else { return }
        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else { return }
        keywordWasSearched = true
        await search.searchByName(value, near: point, radius: 5_000)
    }
    private func searchTerm(for group: PlaceGroup) -> String {
        switch group {
        case .food: return "restaurantes"
        case .cafes: return "cafeterías bares"
        case .shopping: return "tiendas y comercios"
        case .health: return "farmacias hospitales clínicas"
        case .leisure: return "ocio y entretenimiento"
        case .culture: return "museos y centros culturales"
        case .outdoors: return "parques y jardines"
        case .sports: return "gimnasios centros deportivos"
        case .transport: return "transporte estaciones"
        case .education: return "universidad colegio escuela"
        case .business: return "oficinas empresas"
        case .institutions: return "instituciones públicas"
        case .lodging: return "hoteles alojamientos"
        case .services: return "servicios"
        case .privatePlaces, .all, .others: return group.title
        }
    }
    private func findDestination() async {
        let query = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, !findingDestination else { return }
        findingDestination = true
        defer { findingDestination = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { message = "No se encontró el destino"; return }
            area = GeoPoint(item.placemark.coordinate)
            category = .all
            keyword = ""
            keywordWasSearched = false
            message = "Destino: \(item.name ?? query)"
            await loadNearCurrent()
        } catch {
            message = "No se pudo localizar ese destino: \(error.localizedDescription)"
        }
    }
}

private struct GuidePlaceRow: View {
    let item: PlaceCandidate
    let isFavorite: Bool
    let suppressed: Bool
    let onOpen: () -> Void
    let onFavorite: () -> Void
    let onRestore: () -> Void
    var body: some View {
        HStack(spacing: 11) {
            Button(action: onOpen) {
                HStack(spacing: 11) {
                    Image(systemName: item.displaySymbol)
                        .font(.title3).foregroundStyle(item.categoryGroup.color)
                        .frame(width: 44, height: 44)
                        .background(item.categoryGroup.color.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                            .foregroundStyle(.primary)
                        Text("\(item.categoryLabel) · \(item.distance.readableDistance)")
                            .font(.caption).foregroundStyle(.secondary)
                        if suppressed {
                            Text("Oculto del radar · recuperable")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }.buttonStyle(.plain)
            VStack(spacing: 10) {
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? .pink : .secondary)
                }.accessibilityLabel(isFavorite ? "Quitar favorito" : "Marcar favorito")
                if suppressed {
                    Button(action: onRestore) { Image(systemName: "arrow.uturn.backward") }
                        .accessibilityLabel("Recuperar en radar")
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17))
    }
}
