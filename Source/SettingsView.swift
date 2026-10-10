import SwiftUI
import CoreLocation
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var store: VisitStore
    @State private var export: ExportFile?
    @StateObject private var live = LivePlacesManager.shared
    @State private var showDetailedOptions = false
    @State private var showLiveDiagnostics = false
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
            Section("Detección de estancias") {
                Toggle("Movimiento inteligente", isOn: Binding(
                    get: { location.smartMotionEnabled },
                    set: { location.setSmartMotion($0) }
                ))
                .tint(.indigo)
                Label(location.smartMotionEnabled ? location.smartMotionStatus : "Modo ahorro · visitas pasivas de iOS",
                      systemImage: location.smartMotionEnabled ? "figure.walk.motion" : "leaf")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Si lo activas, los indicios de actividad física pueden iniciar comprobaciones GPS breves; no es seguimiento continuo y iOS puede retrasarlas al suspender la app. Sin activarlo, se siguen registrando visitas habituales.")
                    .font(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("Paseo detallado manual", isExpanded: $showDetailedOptions) {
                    Toggle("Detectar paradas cortas durante un paseo", isOn: Binding(
                        get: { location.walkMode },
                        set: { location.setWalkMode($0) }
                    ))
                    Text("GPS más preciso durante un máximo de tres horas. Tiene prioridad sobre el modo inteligente y consume más batería.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = location.errorText {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Pantalla de bloqueo") {
                if live.enabled {
                    Button("Cerrar panel de lugares") { live.stop() }
                } else {
                    Button("Mostrar lugares en pantalla de bloqueo") {
                        live.start(near: location.coordinate)
                    }
                }
                if !live.status.isEmpty { Text(live.status).font(.caption).foregroundStyle(.secondary) }
                DisclosureGroup("Diagnóstico de Actividad en directo", isExpanded: $showLiveDiagnostics) {
                    Button("Prueba visual del panel (sin GPS ni visitas)") { live.startVisualTest() }
                    Button("Ver diagnóstico de iOS y extensión") { live.inspect() }
                    if !live.diagnosticText.isEmpty {
                        Text(live.diagnosticText).font(.caption.monospaced()).textSelection(.enabled)
                    }
                    Text("Que la actividad esté activa no demuestra que WidgetKit haya dibujado la extensión. Si la prueba no se ve, hay que comprobar su registro y firma al instalarla con Sideloadly.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Avisos") {
                Button("Autorizar avisos de visitas sin identificar") { LocalNotifications.requestPermission() }
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
                LabeledContent("Versión", value: "0.15 · Radar inteligente")
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
