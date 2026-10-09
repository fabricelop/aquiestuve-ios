import SwiftUI
import CoreLocation
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var store: VisitStore
    @State private var export: ExportFile?
    var body: some View {
        Form {
            Section("Localización") {
                LabeledContent("Permiso", value: permissionName)
                if location.authorization == .notDetermined {
                    Button("Permitir ubicación") { location.requestAccess() }
                } else if location.authorization == .authorizedWhenInUse {
                    Button("Solicitar permiso Siempre") { location.requestBackgroundAccess() }
                } else if location.authorization == .denied {
                    Link("Abrir Ajustes de iOS", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
                Label("Para registrar visitas con el iPhone bloqueado, usa ubicación 'Siempre' y ubicación precisa.",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Avisos") {
                Button("Autorizar avisos de visitas sin identificar") {
                    LocalNotifications.requestPermission()
                }
            }
            Section("Datos y privacidad") {
                LabeledContent("Lugares guardados", value: "\(store.places.count)")
                LabeledContent("Visitas registradas", value: "\(store.stays.count)")
                Button("Exportar historial CSV") {
                    if let url = store.exportCSV() { export = ExportFile(url: url) }
                }
                Button("Copia completa JSON") {
                    if let url = store.exportJSON() { export = ExportFile(url: url) }
                }
                Text("No hay cuenta, seguimiento de terceros ni servidor propio. Los datos personales se guardan localmente. Apple Maps y OpenStreetMap reciben las consultas de lugares cuando las solicitas.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Acerca de") {
                LabeledContent("Versión", value: "0.1 · MVP")
                LabeledContent("Coste", value: "0 €")
                Text("La detección de visitas de iOS no es inmediata ni garantiza reconocer dos negocios contiguos. Puedes corregir cualquier estancia en Historial.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Datos © OpenStreetMap contributors (ODbL).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error = store.lastError {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Ajustes")
        .sheet(item: $export) { file in
            SystemShareSheet(items: [file.url])
        }
    }
    private var permissionName: String {
        switch location.authorization {
        case .authorizedAlways: return "Siempre"
        case .authorizedWhenInUse: return "Solo al usar"
        case .denied: return "Denegado"
        case .restricted: return "Restringido"
        case .notDetermined: return "Sin decidir"
        @unknown default: return "Desconocido"
        }
    }
}

private struct ExportFile: Identifiable { let id = UUID(); let url: URL }
private struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
