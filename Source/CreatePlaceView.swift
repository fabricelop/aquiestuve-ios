import SwiftUI
import MapKit

struct CreatePlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: VisitStore
    let initial: GeoPoint
    @State private var point: GeoPoint
    @State private var name = ""
    @State private var category = "Personal"
    @State private var assignToCurrent = true
    @State private var chooseCategory = false

    init(initial: GeoPoint, assignToCurrentByDefault: Bool = true) {
        self.initial = initial
        _point = State(initialValue: initial)
        _assignToCurrent = State(initialValue: assignToCurrentByDefault)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Lugar privado") {
                    TextField("Nombre: Casa, casa de un amigo…", text: $name)
                        .textInputAutocapitalization(.words)
                    HStack {
                        Text("Categoría")
                        Spacer()
                        Text(category).foregroundStyle(.secondary)
                    }
                    Button("Buscar entre todas las categorías") { chooseCategory = true }
                    TextField("O escribir una categoría propia", text: $category)
                    Toggle("Asignar a la visita actual", isOn: $assignToCurrent)
                }
                Section("Posición (mantén pulsado para ajustar)") {
                    DraggablePlaceMap(point: $point)
                        .frame(height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Text(String(format: "%.5f, %.5f", point.latitude, point.longitude))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Section {
                    Text("Este sitio solamente se guarda en tu iPhone. No se publica en Apple Maps ni OpenStreetMap.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Nuevo lugar")
            .sheet(isPresented: $chooseCategory) { CategoryPickerView(selection: $category) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let place = store.createPersonalPlace(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                              category: category, at: point)
                        if assignToCurrent {
                            store.assign(store.savedCandidate(for: place, near: point))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct DraggablePlaceMap: UIViewRepresentable {
    @Binding var point: GeoPoint
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.setRegion(MKCoordinateRegion(center: point.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)), animated: false)
        let marker = MKPointAnnotation()
        marker.coordinate = point.coordinate
        map.addAnnotation(marker)
        let longPress = UILongPressGestureRecognizer(target: context.coordinator,
                                                     action: #selector(Coordinator.dragPin(_:)))
        map.addGestureRecognizer(longPress)
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        if let marker = map.annotations.first(where: { $0 is MKPointAnnotation }) as? MKPointAnnotation {
            marker.coordinate = point.coordinate
        }
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: DraggablePlaceMap
        init(_ parent: DraggablePlaceMap) { self.parent = parent }
        @objc func dragPin(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let map = gesture.view as? MKMapView else { return }
            parent.point = GeoPoint(map.convert(gesture.location(in: map), toCoordinateFrom: map))
        }
    }
}
