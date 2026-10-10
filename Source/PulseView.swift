import SwiftUI
import CoreLocation

/// Contextual home surface. Reuses CoreLocation and the existing local POI cache.
/// No polling, background map fetches or additional location subscriptions.
struct PulseView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var location: LocationService
    @Binding var openExplorer: Bool
    @State private var candidateToReview: PlaceCandidate?

    private var recentToday: [Stay] {
        store.stays.filter { Calendar.current.isDateInToday($0.arrival) }
            .sorted { $0.arrival > $1.arrival }
    }
    private var candidates: [PlaceCandidate] {
        guard let center = location.coordinate else { return [] }
        return Array(NearbyNotificationCache.suggestions(for: center)
            .filter { $0.distance <= 150 }
            .sorted {
                if $0.relevanceScore == $1.relevanceScore { return $0.distance < $1.distance }
                return $0.relevanceScore > $1.relevanceScore
            }.prefix(3))
    }
    private var namedVisitsToday: Int { recentToday.filter { $0.placeID != nil }.count }
    private var pendingToday: Int { recentToday.filter { $0.placeID == nil }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                header
                pulseHero
                statsTiles
                candidateSection
                todaySection
                reconciliationNotice
                privacyFooter
            }
            .padding()
        }
        .background {
            LinearGradient(colors: [.indigo.opacity(0.09), .cyan.opacity(0.04), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $candidateToReview) { item in
            NearbyPlacePreview(item: item) {
                store.assign(item)
                candidateToReview = nil
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("AQUÍESTUVE")
                    .font(.caption.weight(.bold)).tracking(2.4)
                    .foregroundStyle(.secondary)
                Text("Pulse")
                    .font(.system(size: 37, weight: .bold, design: .rounded))
            }
            Spacer()
            Label(location.walkMode ? "Paseo" : "Ahorro",
                  systemImage: location.walkMode ? "figure.walk" : "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(location.walkMode ? Color.orange : Color.green)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
        }
    }

    private var statsTiles: some View {
        HStack(spacing: 11) {
            countTile(title: "SITIOS HOY", value: "\(namedVisitsToday)",
                      subtitle: "Identificados", icon: "mappin.and.ellipse", tint: .indigo)
            countTile(title: "POR REVISAR", value: "\(pendingToday)",
                      subtitle: "Paradas pendientes", icon: "checklist", tint: .orange)
        }
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("¿Dónde podrías estar?", systemImage: "sparkle.magnifyingglass")
                    .font(.title3.weight(.bold))
                Spacer()
                Button("Explorar") { openExplorer = true }
                    .font(.subheadline.weight(.semibold))
            }
            if candidates.isEmpty {
                noCandidateCard
            } else {
                ForEach(candidates) { item in
                    candidateCard(item)
                }
            }
        }
    }

    private var noCandidateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sin candidatos recientes en la memoria local")
                .font(.subheadline.weight(.medium))
            Text("Abre Explorar una vez para consultar la zona. Pulse reutilizará los resultados, sin búsquedas periódicas.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Buscar establecimientos") { openExplorer = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func candidateCard(_ item: PlaceCandidate) -> some View {
        Button {
            candidateToReview = item
        } label: {
            HStack(spacing: 13) {
                Image(systemName: item.displaySymbol)
                    .font(.title2)
                    .foregroundStyle(item.categoryGroup.color)
                    .frame(width: 42, height: 42)
                    .background(item.categoryGroup.color.opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.headline).foregroundStyle(.primary).lineLimit(1)
                    Text("\(item.categoryLabel) · \(item.distance.readableDistance)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(13)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Tu día en movimiento", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.headline)
                Spacer()
                Text("\(recentToday.count) tramos")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if recentToday.isEmpty {
                Text("Las estancias detectadas aparecerán aquí. No necesitas tener Pulse abierto.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(recentToday.prefix(5)) { stay in
                    todayRow(stay)
                }
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func todayRow(_ stay: Stay) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(stay.placeID == nil ? Color.orange : Color.green)
                .frame(width: 9, height: 9)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.place(for: stay)?.name ?? "Parada por identificar")
                    .font(.subheadline.weight(.semibold))
                Text("\(stay.arrival.formatted(date: .omitted, time: .shortened)) · \(stay.duration.readableDuration)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var reconciliationNotice: some View {
        if store.reconciledAtLaunch > 0 {
            Label("\(store.reconciledAtLaunch) registros solapados reunidos al abrir la app",
                  systemImage: "checkmark.shield")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var privacyFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield")
            Text("Pulse usa datos locales y eventos de iOS. No activa rastreo continuo ni consultas de mapas en segundo plano.")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }

    private var pulseHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(location.walkMode ? location.mobilityHint : "Modo normal · bajo consumo",
                      systemImage: location.walkMode ? "figure.walk.motion" : "location.circle")
                    .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: "waveform.path").font(.title2)
            }.foregroundStyle(.white.opacity(0.82))
            if let stay = store.activeStay {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.place(for: stay)?.name ?? "Posible estancia en curso")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text("Aquí desde hace \(stay.duration(asOf: context.date).readableDuration)")
                            .font(.subheadline)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(location.coordinate == nil ? "Buscando tu ubicación" : "Tu día, a tu ritmo")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text(location.walkMode ? "Se observan pausas reales, sin crear entradas continuamente." :
                         "AquíEstuve detecta visitas de forma pasiva, incluso con la pantalla apagada.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.84))
                }
            }
            HStack(spacing: 10) {
                Button { openExplorer = true } label: {
                    Label("Ver lugares", systemImage: "map")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(.white, in: Capsule()).foregroundStyle(.indigo)
                }
                Button { location.setWalkMode(!location.walkMode) } label: {
                    Label(location.walkMode ? "Terminar paseo" : "Iniciar paseo", systemImage: "figure.walk")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .background(.white.opacity(0.16), in: Capsule())
                        .foregroundStyle(.white)
                }
            }.buttonStyle(.plain)
            if let error = location.errorText {
                Text(error).font(.caption).foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(21)
        .background(LinearGradient(colors: [.indigo, .purple, .blue],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24))
    }

    private func countTile(title: String, value: String, subtitle: String,
                           icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title).font(.caption2.weight(.bold)).tracking(0.8)
                Spacer()
                Image(systemName: icon)
            }.foregroundStyle(tint)
            Text(value).font(.system(size: 32, weight: .bold, design: .rounded))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
