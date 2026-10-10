import SwiftUI
import CoreLocation
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var store: VisitStore
    @State private var export: ExportFile?
    @StateObject private var live = LivePlacesManager.shared
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
            Section("Paseos (opcional)") {
                Toggle("Modo Paseo: detectar paradas cortas", isOn: Binding(
                    get: { location.walkMode },
                    set: { location.setWalkMode($0) }
                ))
                Text("Sin este modo, iOS sigue detectando visitas con bajo consumo, pero puede omitir paradas cortas. El modo Paseo emplea GPS más preciso, exige movimiento sostenido para cerrar estancias y finaliza como máximo en 3 horas.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Cuando vuelvas, entra en Historial → Pendientes para confirmar o descartar las paradas observadas.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let error = location.errorText {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }
            }
            Section("Avisos") {
                Button("Autorizar avisos de visitas sin identificar") {
                    LocalNotifications.requestPermission()
                }
                Button("Probar notificación de pantalla bloqueada") {
                    LocalNotifications.sendTestNotification(near: location.coordinate)
                }
                Text("Esta prueba envía un aviso después de 5 segundos. No crea una visita ni prueba la detección GPS. Bloquea el iPhone para comprobar si aparece.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Pantalla de bloqueo · Actividad en directo") {
                if live.enabled {
                    Button("Cerrar panel de lugares") { live.stop() }
                } else {
                    Button("Mostrar lugares en pantalla de bloqueo") {
                        live.start(near: location.coordinate)
                    }
                }
                Button("Prueba visual del panel (sin GPS ni visitas)") { live.startVisualTest() }
                Button("Ver diagnóstico de iOS y extensión") { live.inspect() }
                if !live.status.isEmpty { Text(live.status).font(.caption) }
                if !live.diagnosticText.isEmpty {
                    Text(live.diagnosticText).font(.caption.monospaced()).textSelection(.enabled)
                }
                Text("La actividad de iOS es experimental: si su interfaz no aparece, usa Pulse dentro de la app. El panel muestra hasta tres candidatos recientes. Tocar un lugar abre su ficha para confirmar; no registra visitas por accidente. No consulta GPS por su cuenta y puede dejar de actualizarse si iOS no despierta la app. iOS limita su duración.")
                    .font(.footnote).foregroundStyle(.secondary)
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
                LabeledContent("Versión", value: "0.14 · Radar y Guía")
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
