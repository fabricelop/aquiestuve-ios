import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: VisitStore
    @State private var period: Period = .month

    enum Period: String, CaseIterable {
        case week = "7 días", month = "30 días", year = "365 días"
        var days: Int { self == .week ? 7 : self == .month ? 30 : 365 }
    }

    private var periodStart: Date {
        Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? .distantPast
    }
    private var knownVisits: [Stay] {
        store.stays.filter { $0.placeID != nil && ($0.departure ?? Date()) >= periodStart }
    }
    private var pendingVisits: [Stay] {
        store.stays.filter { $0.placeID == nil && ($0.departure ?? Date()) >= periodStart }
    }
    private func seconds(for stay: Stay, from start: Date) -> TimeInterval {
        max(0, (stay.departure ?? Date()).timeIntervalSince(max(stay.arrival, start)))
    }
    private var knownSeconds: TimeInterval {
        knownVisits.reduce(0) { $0 + seconds(for: $1, from: periodStart) }
    }
    private var previousVisits: [Stay] {
        let before = Calendar.current.date(byAdding: .day, value: -period.days, to: periodStart) ?? .distantPast
        return store.stays.filter {
            $0.placeID != nil && ($0.departure ?? Date()) >= before && $0.arrival < periodStart
        }
    }
    private var previousSeconds: TimeInterval {
        let before = Calendar.current.date(byAdding: .day, value: -period.days, to: periodStart) ?? .distantPast
        return previousVisits.reduce(0) {
            $0 + max(0, min($1.departure ?? Date(), periodStart).timeIntervalSince(max($1.arrival, before)))
        }
    }
    private var ranked: [(place: Place, visits: Int, seconds: Double)] {
        store.places.compactMap { place in
            let matches = knownVisits.filter { $0.placeID == place.id }
            guard !matches.isEmpty else { return nil }
            return (place, matches.count, matches.reduce(0) { $0 + seconds(for: $1, from: periodStart) })
        }.sorted { $0.seconds > $1.seconds }
    }
    private var byGroup: [(group: PlaceGroup, seconds: Double, count: Int)] {
        PlaceGroup.allCases.filter { $0 != .all }.compactMap { group in
            let matching = ranked.filter { $0.place.categoryGroup == group }
            let total = matching.reduce(0) { $0 + $1.seconds }
            let count = matching.reduce(0) { $0 + $1.visits }
            return count > 0 ? (group, total, count) : nil
        }.sorted { $0.seconds > $1.seconds }
    }
    private var lastSevenDays: [(date: Date, seconds: TimeInterval)] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { ago in
            guard let day = Calendar.current.date(byAdding: .day, value: -ago, to: today),
                  let end = Calendar.current.date(byAdding: .day, value: 1, to: day) else { return nil }
            let total = knownVisits.reduce(0.0) { sum, visit in
                let actualEnd = visit.departure ?? Date()
                return sum + max(0, min(actualEnd, end).timeIntervalSince(max(visit.arrival, day)))
            }
            return (day, total)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Periodo", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                HStack(spacing: 10) {
                    statCard("Visitas identificadas", value: "\(knownVisits.count)", icon: "checkmark.circle")
                    statCard("Tiempo registrado", value: knownSeconds.readableDuration, icon: "clock")
                }
                HStack(spacing: 10) {
                    statCard("Sitios diferentes", value: "\(Set(knownVisits.compactMap(\.placeID)).count)", icon: "map")
                    statCard("Pendientes de revisar", value: "\(pendingVisits.count)", icon: "questionmark.circle")
                }
                HStack(spacing: 10) {
                    statCard("Media por visita", value: (knownVisits.isEmpty ? 0 : knownSeconds / Double(knownVisits.count)).readableDuration,
                             icon: "chart.bar")
                    statCard("Periodo anterior", value: previousSeconds.readableDuration, icon: "calendar")
                }
                if knownSeconds > 0 && previousSeconds > 0 {
                    let difference = (knownSeconds - previousSeconds) / previousSeconds * 100
                    Text(String(format: "%+.0f %% de tiempo registrado respecto al periodo anterior", difference))
                        .font(.caption).foregroundStyle(.secondary)
                }

                Text("Tiempo por categoría").font(.title3.bold())
                if byGroup.isEmpty {
                    Text("Cuando confirmes visitas, aparecerán sus categorías.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(byGroup, id: \.group.id) { entry in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label(entry.group.title, systemImage: entry.group.symbol)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(entry.group.color)
                                Spacer()
                                Text("\(entry.count) visitas · \(entry.seconds.readableDuration)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                Capsule().fill(entry.group.color.opacity(0.85))
                                    .frame(width: max(3, geo.size.width * entry.seconds / max(1, knownSeconds)))
                            }
                            .frame(height: 9)
                        }
                    }
                }

                Text("Actividad de los últimos 7 días").font(.title3.bold())
                let most = max(1, lastSevenDays.map(\.seconds).max() ?? 1)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(lastSevenDays, id: \.date) { day in
                        VStack(spacing: 4) {
                            Text(day.seconds.readableDuration)
                                .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                            GeometryReader { geo in
                                VStack {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.indigo.opacity(0.75))
                                        .frame(height: max(3, geo.size.height * day.seconds / most))
                                }
                            }
                            .frame(height: 105)
                            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text("Dónde pasas más tiempo").font(.title3.bold())
                if ranked.isEmpty {
                    ContentUnavailableView("Sin estadísticas", systemImage: "chart.bar",
                        description: Text("Identifica una visita desde Historial o confirma tu ubicación en Ahora."))
                } else {
                    let top = max(1, ranked.first?.seconds ?? 1)
                    ForEach(ranked.prefix(15), id: \.place.id) { entry in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(entry.place.name).font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(entry.visits) veces · \(entry.seconds.readableDuration)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                Capsule().fill(entry.place.categoryGroup.color.opacity(0.8))
                                    .frame(width: max(3, geo.size.width * entry.seconds / top))
                            }
                            .frame(height: 8)
                        }
                    }
                }
                Text("Los tiempos son estimaciones. Las paradas pendientes y los intervalos sin observar no se incluyen. El gráfico puede reflejar solapamientos que hayas confirmado por error; corrígelos en Historial.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Estadísticas")
    }

    private func statCard(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).minimumScaleFactor(0.65).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 85, alignment: .leading)
        .padding(10)
        .background(Color.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}
