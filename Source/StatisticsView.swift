import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject private var store: VisitStore
    @State private var period: Period = .month
    enum Period: String, CaseIterable { case week = "7 días", month = "30 días", year = "365 días"
        var days: Int { self == .week ? 7 : self == .month ? 30 : 365 }
    }
    private var visits: [Stay] {
        let start = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? .distantPast
        return store.stays.filter { ($0.departure ?? Date()) >= start && $0.placeID != nil }
    }
    private var seconds: TimeInterval {
        let start = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? .distantPast
        return visits.reduce(0) { total, visit in
            total + max(0, (visit.departure ?? Date()).timeIntervalSince(max(visit.arrival, start)))
        }
    }
    private var ranked: [(Place, Int, TimeInterval)] {
        store.places.compactMap { place in
            let matching = visits.filter { $0.placeID == place.id }
            guard !matching.isEmpty else { return nil }
            let start = Calendar.current.date(byAdding: .day, value: -period.days, to: Date()) ?? .distantPast
            return (place, matching.count, matching.reduce(0) {
                $0 + max(0, ($1.departure ?? Date()).timeIntervalSince(max($1.arrival, start)))
            })
        }.sorted { $0.2 > $1.2 }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Periodo", selection: $period) {
                    ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                HStack(spacing: 12) {
                    statCard("Visitas", value: "\(visits.count)", icon: "checkmark.circle")
                    statCard("Tiempo", value: seconds.readableDuration, icon: "clock")
                }
                HStack(spacing: 12) {
                    statCard("Sitios distintos", value: "\(Set(visits.compactMap(\.placeID)).count)", icon: "map")
                    let avg = visits.isEmpty ? 0 : seconds / Double(visits.count)
                    statCard("Media por visita", value: avg.readableDuration, icon: "chart.bar")
                }
                Text("Dónde pasas más tiempo").font(.title3.bold())
                if ranked.isEmpty {
                    ContentUnavailableView("Sin datos para este periodo", systemImage: "chart.bar",
                        description: Text("Confirma algunas estancias para empezar a ver estadísticas."))
                } else {
                    let maxValue = max(1, ranked.first?.2 ?? 1)
                    ForEach(ranked.prefix(15), id: \.0.id) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.0.name).fontWeight(.medium)
                                Spacer()
                                Text("\(entry.1) veces · \(entry.2.readableDuration)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                Capsule().fill(Color.indigo.opacity(0.85))
                                    .frame(width: max(2, geo.size.width * entry.2 / maxValue))
                            }
                            .frame(height: 9)
                        }
                    }
                }
                Text("Las horas son estimaciones basadas en las llegadas y salidas detectadas o corregidas. El tiempo sin lugar identificado no se incluye.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Estadísticas")
    }
    private func statCard(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 85, alignment: .leading)
        .padding(12)
        .background(Color.indigo.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}
