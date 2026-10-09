import SwiftUI
import MapKit

struct NowView: View {
    @EnvironmentObject private var store: VisitStore
    @EnvironmentObject private var location: LocationService
    @StateObject private var search = NearbySearch()
    @State private var radius = 250.0
    @State private var showAll = false
    @State private var createPlace = false

    private var displayed: [PlaceCandidate] { showAll ? search.candidates : Array(search.candidates.prefix(7)) }

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
                    ContentUnavailableView("Sin estancia activa", systemImage: "location.slash",
                        description: Text("Elige un lugar para registrar una visita o deja que iOS detecte una estancia."))
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
                        ForEach(displayed) { item in
                            Marker(item.name, coordinate: item.position.coordinate)
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
                    HStack {
                        Text("\(search.candidates.count) encontrados · Apple: \(search.appleCount) · OSM: \(search.osmCount)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(showAll ? "Sugeridos" : "Ver todos") { showAll.toggle() }
                            .font(.subheadline.weight(.semibold))
                    }
                    ForEach(displayed) { item in
                        Button {
                            store.assign(item)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.source == .personal ? "house.fill" : "mappin.circle.fill")
                                    .font(.title2).foregroundStyle(.indigo)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name).fontWeight(.semibold).foregroundStyle(.primary)
                                    Text("\(item.category) · \(item.distance.readableDistance)" +
                                         (item.visits > 0 ? " · \(item.visits) visitas" : ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.activeStay?.placeID == item.savedID && item.savedID != nil {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                } else { Image(systemName: "checkmark.circle").foregroundStyle(.secondary) }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    if search.candidates.isEmpty && !search.loading {
                        Text("No hay resultados todavía. Prueba a actualizar, ampliar el radio o crear un lugar.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button { Task { await search.addOSM(near: position, radius: radius) } } label: {
                            Label("Ampliar con OSM", systemImage: "globe.europe.africa")
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
                    Text("© OpenStreetMap contributors · Resultados sujetos a disponibilidad. No se hacen consultas continuas.")
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
    }
}
