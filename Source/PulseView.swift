import SwiftUI

/// Radar and Guide are two uses of the same location data. Neither starts GPS tracking.
struct PulseView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var location: LocationService
    @Binding var openExplorer: Bool
    @StateObject private var preferences = RadarPreferencesStore.shared
    @StateObject private var discovery = NearbySearch()
    @State private var discoveryCenter: GeoPoint?
    @State private var lastDiscovery = Date.distantPast
    @State private var selectedMode = 0
    @State private var nearby: [PlaceCandidate] = []
    @State private var passed: Set<String> = []
    @State private var candidateToReview: PlaceCandidate?
    @State private var showRecovered = false
    @State private var showArchiveConfirmation = false
    @State private var archiveCandidate: PlaceCandidate?
    @State private var actionLabel = ""
    @State private var lastCenter: GeoPoint?

    private var ordered: [PlaceCandidate] {
        guard let center = location.coordinate else { return [] }
        return nearby.filter { item in
            !passed.contains(preferences.key(for: item)) && preferences.isVisible(item, at: center)
        }.sorted { a, b in
            let aa = preferences.score(a)
            let bb = preferences.score(b)
            return aa == bb ? a.distance < b.distance : aa > bb
        }
    }
    private var today: [Stay] {
        store.stays.filter { Calendar.current.isDateInToday($0.arrival) }
            .sorted { $0.arrival > $1.arrival }
    }
    private var namedToday: Int { today.filter { $0.placeID != nil }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                HStack(spacing: 5) {
                    modeButton("Radar", icon: "scope", mode: 0)
                    modeButton("Guía", icon: "safari.fill", mode: 1)
                }
                .padding(5)
                .background(.regularMaterial, in: Capsule())
                if selectedMode == 0 {
                    radarPage
                } else {
                    GuidePlacesView(openExplorer: $openExplorer)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background {
            LinearGradient(colors: [Color.indigo.opacity(0.19), Color.cyan.opacity(0.06), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $candidateToReview) { item in
            NearbyPlacePreview(item: item, alternatives: nearby) {
                store.assign(item)
                candidateToReview = nil
                actionLabel = "Visita confirmada · \(item.name)"
            }
        }
        .sheet(isPresented: $showRecovered) { RecoveredPlacesView() }
        .confirmationDialog("Ocultar de las sugerencias", isPresented: $showArchiveConfirmation,
                            titleVisibility: .visible) {
            Button("Archivar, podré recuperarlo") {
                if let item = archiveCandidate { perform(.archive, item) }
                archiveCandidate = nil
            }
            Button("Cancelar", role: .cancel) { archiveCandidate = nil }
        } message: { Text("Seguirá apareciendo en la búsqueda y en Descartados.") }
        .onAppear {
            reloadNearby()
            maybeDiscover()
        }
        .onChange(of: discovery.candidates) { _, _ in reloadNearby() }
        .onChange(of: location.coordinate) { _, newCenter in
            if let old = lastCenter, let newCenter, old.distance(to: newCenter) > 180 { passed = [] }
            reloadNearby()
            maybeDiscover()
        }
        .onChange(of: selectedMode) { _, value in if value == 0 { reloadNearby() } }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "location.north.line.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading,
                                           endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 1) {
                Text("AQUÍESTUVE").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(.secondary)
                Text(selectedMode == 0 ? "Radar Pulse" : "Descubre lugares")
                    .font(.system(.title, design: .rounded, weight: .bold))
            }
            Spacer()
            Button { showRecovered = true } label: {
                Image(systemName: "tray.full.fill")
                    .font(.title3)
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Lugares descartados y recuperables")
        }
    }
    private func modeButton(_ title: String, icon: String, mode: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.25)) { selectedMode = mode } } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(selectedMode == mode ? Color.white : Color.primary)
                .background(selectedMode == mode ? Color.indigo : Color.clear, in: Capsule())
        }.buttonStyle(.plain)
    }

    private var radarPage: some View {
        VStack(spacing: 17) {
            pulseStatus
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DONDE PODRÍAS ESTAR")
                        .font(.caption2.weight(.heavy)).tracking(1.7).foregroundStyle(.secondary)
                    Text("Desliza para personalizar tu radar")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Ver todos") { openExplorer = true }.font(.caption.weight(.semibold))
            }
            if let center = location.coordinate, !ordered.isEmpty {
                RadarCardDeck(items: Array(ordered.prefix(3)), favorite: { preferences.rule(for: $0).favorite },
                              onSwipe: { item, gesture in
                    switch gesture {
                    case .archive:
                        archiveCandidate = item; showArchiveConfirmation = true
                    default: perform(gesture, item)
                    }
                }, onConfirm: { confirmFromRadar($0) }, onOpen: { candidateToReview = $0 })
                HStack {
                    Label("\(ordered.count) candidatos", systemImage: "circle.grid.3x3.fill")
                    Spacer()
                    Text("A \(Int(center.distance(to: ordered[0].position))) m del primero")
                }
                .font(.caption).foregroundStyle(.secondary)
            } else {
                radarEmpty
            }
            radarLegend
            HStack(spacing: 12) {
                metric(icon: "mappin.circle.fill", title: "Lugares hoy", number: namedToday, tint: .indigo)
                metric(icon: "clock.badge.questionmark", title: "Por revisar", number: today.count - namedToday,
                       tint: .orange)
            }
            if !today.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Tu día en movimiento", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.headline)
                    ForEach(today.prefix(3)) { stay in
                        HStack {
                            Circle().fill(stay.placeID == nil ? .orange : .green).frame(width: 8, height: 8)
                            Text(store.place(for: stay)?.name ?? "Parada por identificar")
                                .font(.subheadline).lineLimit(1)
                            Spacer()
                            Text(stay.arrival.formatted(date: .omitted, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").foregroundStyle(.green)
                Text("\(location.walkMode ? "Paseo detallado" : "Detección pasiva") · Sin búsquedas continuas")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
    private var pulseStatus: some View {
        HStack(spacing: 13) {
            RadarOrbitView()
                .frame(width: 91, height: 91)
            VStack(alignment: .leading, spacing: 5) {
                Label("RADAR ACTIVO", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption2.weight(.bold)).tracking(1)
                    .foregroundStyle(.cyan)
                Text(store.activeStay.flatMap { store.place(for: $0)?.name } ??
                     (location.coordinate == nil ? "Esperando posición" : "Explorando tu entorno"))
                    .font(.headline).lineLimit(2)
                Text(location.walkMode ? location.mobilityHint : "Bajo consumo · visitas automáticas")
                    .font(.caption).foregroundStyle(.white.opacity(0.75))
                if let current = store.activeStay {
                    TimelineView(.periodic(from: .now, by: 60)) { tick in
                        Text("Aquí desde hace \(current.duration(asOf: tick.date).readableDuration)")
                            .font(.caption2).foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.37),
                                            Color(red: 0.18, green: 0.23, blue: 0.55)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(.white)
    }
    private var radarEmpty: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass").font(.system(size: 37)).foregroundStyle(.indigo)
            Text(location.coordinate == nil ? "Necesitamos tu ubicación" : "Tu radar está despejado")
                .font(.title3.bold())
            Text("Consulta una vez los lugares de esta zona. Al volver, podrás descartar y marcar favoritos sin esperas.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Cargar lugares cercanos") { openExplorer = true }
                .buttonStyle(.borderedProminent)
            Button("Recuperar descartados") { showRecovered = true }
                .font(.caption)
        }
        .padding(25)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
    private var radarLegend: some View {
        VStack(spacing: 7) {
            HStack(spacing: 12) {
                Label("Derecha: favorito", systemImage: "heart.fill").foregroundStyle(.green)
                Spacer()
                Label("Izquierda: ahora no", systemImage: "clock").foregroundStyle(.orange)
            }
            HStack(spacing: 12) {
                Label("Más izquierda: ocultar aquí", systemImage: "eye.slash").foregroundStyle(.secondary)
                Spacer()
                Label("Arriba: archivar", systemImage: "archivebox").foregroundStyle(.secondary)
            }
            if !actionLabel.isEmpty {
                HStack {
                    Text(actionLabel).lineLimit(2)
                    Spacer()
                    Button("Deshacer") {
                        preferences.undo(); passed = []; actionLabel = ""
                    }.fontWeight(.semibold)
                }
                .font(.caption).padding(10)
                .background(.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .font(.caption2)
    }
    private func metric(icon: String, title: String, number: Int, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint)
            VStack(alignment: .leading) {
                Text("\(number)").font(.title2.bold())
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
    private func reloadNearby() {
        guard let center = location.coordinate else { return }
        let previous = lastCenter
        nearby = NearbyNotificationCache.radarCandidates(for: center, radius: 400)
        lastCenter = center
        if let previous, previous.distance(to: center) > 180 { passed = [] }
    }
    /// Once when entering a new area without enough cached candidates; not a poll.
    private func maybeDiscover() {
        guard selectedMode == 0, let center = location.coordinate, nearby.count < 3,
              !discovery.loading, Date().timeIntervalSince(lastDiscovery) >= 600 else { return }
        if let previous = discoveryCenter, previous.distance(to: center) < 400 { return }
        discoveryCenter = center
        lastDiscovery = Date()
        Task {
            await discovery.search(near: center, radius: 400)
            reloadNearby()
        }
    }

    private func confirmFromRadar(_ item: PlaceCandidate) {
        // Only this explicitly labelled button records presence. Swipes never do.
        store.assign(item)
        passed.insert(preferences.key(for: item))
        actionLabel = "Visita confirmada: \(item.name) · puedes corregirla en Historial"
    }

    private func perform(_ action: RadarSwipeAction, _ item: PlaceCandidate) {
        let key = preferences.key(for: item)
        switch action {
        case .favorite: preferences.setFavorite(item, to: true); actionLabel = "Favorito actualizado: \(item.name)"
        case .later: preferences.snooze(item); actionLabel = "\(item.name) · oculto durante 4 horas"
        case .nearby:
            if let point = location.coordinate { preferences.hideInArea(item, at: point) }
            actionLabel = "\(item.name) · oculto solo en esta zona"
        case .archive: preferences.archive(item); actionLabel = "\(item.name) · archivado, recuperable"
        }
        passed.insert(key)
    }
}

/// Lightweight visual indicator, NOT a continuous-radar/accelerometer service.
private struct RadarOrbitView: View {
    var body: some View {
        ZStack {
            Circle().stroke(.cyan.opacity(0.2), lineWidth: 1)
            Circle().stroke(.cyan.opacity(0.33), lineWidth: 1).padding(15)
            Circle().stroke(.cyan.opacity(0.54), lineWidth: 1).padding(29)
            Circle().fill(.cyan.opacity(0.16)).frame(width: 38, height: 38)
            Image(systemName: "location.north.fill")
                .foregroundStyle(.white).font(.title3)
            Circle().fill(.mint).frame(width: 8, height: 8).offset(x: 27, y: -23)
            Circle().fill(.cyan).frame(width: 6, height: 6).offset(x: -33, y: 11)
            Circle().fill(.white).frame(width: 5, height: 5).offset(x: 20, y: 31)
        }
    }
}

enum RadarSwipeAction { case favorite, later, nearby, archive }

private struct RadarCardDeck: View {
    let items: [PlaceCandidate]
    let favorite: (PlaceCandidate) -> Bool
    let onSwipe: (PlaceCandidate, RadarSwipeAction) -> Void
    let onConfirm: (PlaceCandidate) -> Void
    let onOpen: (PlaceCandidate) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(items.indices.reversed()), id: \.self) { index in
                RadarSwipeCard(item: items[index], isFavorite: favorite(items[index]), front: index == 0,
                               onSwipe: { onSwipe(items[index], $0) },
                               onConfirm: { onConfirm(items[index]) },
                               onOpen: { onOpen(items[index]) })
                    .scaleEffect(1 - CGFloat(index) * 0.035)
                    .offset(y: CGFloat(index) * 10)
                    .zIndex(Double(items.count - index))
                    .allowsHitTesting(index == 0)
            }
        }
        .frame(height: 330)
        .animation(.spring(response: 0.35, dampingFraction: 0.84), value: items.map(\.id))
    }
}

private struct RadarSwipeCard: View {
    let item: PlaceCandidate
    let isFavorite: Bool
    let front: Bool
    let onSwipe: (RadarSwipeAction) -> Void
    let onConfirm: () -> Void
    let onOpen: () -> Void
    @State private var translation: CGSize = .zero

    private var tint: Color { item.categoryGroup.color }
    private var label: String {
        if translation.height < -75 && abs(translation.height) > abs(translation.width) { return "ARCHIVAR" }
        if translation.width > 75 { return "FAVORITO" }
        if translation.width < -185 { return "OCULTAR AQUÍ" }
        if translation.width < -65 { return "AHORA NO" }
        return ""
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label(item.categoryLabel.uppercased(), systemImage: item.displaySymbol)
                    .font(.caption2.weight(.bold)).lineLimit(1)
                Spacer()
                if isFavorite { Image(systemName: "heart.fill").foregroundStyle(.pink) }
                Text(item.distance.readableDistance).font(.caption.weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.88))
            Spacer(minLength: 0)
            Text(item.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .lineLimit(2).minimumScaleFactor(0.75)
                .foregroundStyle(.white)
            if let address = item.address, !address.isEmpty {
                Text(address).font(.caption).foregroundStyle(.white.opacity(0.78)).lineLimit(1)
            }
            HStack(spacing: 8) {
                Image(systemName: "hand.draw")
                Text(label.isEmpty ? "Desliza para decidir" : label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.9))
            Button("Ver detalles y mapa", action: onOpen)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            Button(action: onConfirm) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Estoy aquí · Confirmar visita")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.indigo)
                .padding(.vertical, 13).padding(.horizontal, 15)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain)
        }
        .padding(21)
        .frame(maxWidth: .infinity, minHeight: 292, maxHeight: 292)
        .background {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.40), tint.opacity(0.92)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    Circle().stroke(.white.opacity(0.13), lineWidth: 24)
                        .frame(width: 170, height: 170).offset(x: 45, y: -65).clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .shadow(color: tint.opacity(0.2), radius: 16, y: 7)
        }
        .offset(translation)
        .rotationEffect(.degrees(Double(translation.width / 22)))
        .gesture(DragGesture(minimumDistance: 22)
            .onChanged { translation = $0.translation }
            .onEnded { value in
                let x = value.translation.width
                let y = value.translation.height
                let action: RadarSwipeAction?
                if y < -105 && abs(y) > abs(x) { action = .archive }
                else if x > 100 { action = .favorite }
                else if x < -195 { action = .nearby }
                else if x < -80 { action = .later }
                else { action = nil }
                withAnimation(.spring(response: 0.3)) { translation = .zero }
                if let action { onSwipe(action) }
            })
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Favorito") { onSwipe(.favorite) }
        .accessibilityAction(named: "Ahora no") { onSwipe(.later) }
        .accessibilityAction(named: "Ocultar en esta zona") { onSwipe(.nearby) }
    }
}
