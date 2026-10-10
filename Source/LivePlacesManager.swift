import ActivityKit
import Foundation
import Combine

@MainActor
final class LivePlacesManager: ObservableObject {
    static let shared = LivePlacesManager()
    @Published private(set) var enabled = !Activity<LivePlaceAttributes>.activities.isEmpty
    @Published private(set) var status = ""
    @Published private(set) var diagnosticText = ""
    private var lastRefreshAt: Date = .distantPast
    private var lastRefreshPoint: GeoPoint?
    private init() {}

    func inspect() {
        let ext = Bundle.main.builtInPlugInsURL?.appendingPathComponent("AquiEstuveLiveWidget.appex")
        let installed = ext.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let activities = Activity<LivePlaceAttributes>.activities
        enabled = !activities.isEmpty
        let states = activities.map { "\($0.id.prefix(6)): \(String(describing: $0.activityState))" }
            .joined(separator: ", ")
        diagnosticText = "Extensión: \(installed ? "incluida" : "no encontrada") · Permiso iOS: \(ActivityAuthorizationInfo().areActivitiesEnabled ? "activo" : "desactivado") · Actividades: \(activities.count)" + (states.isEmpty ? "" : " · " + states)
    }

    func refreshIfUseful(near center: GeoPoint) async {
        guard enabled, !Activity<LivePlaceAttributes>.activities.isEmpty else { return }
        if Date().timeIntervalSince(lastRefreshAt) < 180,
           (lastRefreshPoint?.distance(to: center) ?? 0) < 100 { return }
        await refresh(near: center)
    }

    private func requestActivity(center: GeoPoint?, diagnostic: Bool) {
        let bundledWidget = Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("AquiEstuveLiveWidget.appex")
        guard let widget = bundledWidget,
              FileManager.default.fileExists(atPath: widget.path) else {
            status = "No se encuentra la extensión; revisa su firma e instalación."
            inspect()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Activa Actividades en directo para AquíEstuve en Ajustes del iPhone."
            inspect()
            return
        }
        let options = diagnostic ? [] : (center.map { suggestions(near: $0) } ?? [])
        let attributes = LivePlaceAttributes(sessionID: UUID().uuidString)
        let content = LivePlaceAttributes.ContentState(updatedAt: Date(),
            title: diagnostic ? "Prueba visual" : "¿Dónde estás?", options: options, diagnostic: diagnostic)
        do {
            _ = try Activity.request(attributes: attributes,
                  content: ActivityContent(state: content, staleDate: Date().addingTimeInterval(1800)),
                  pushType: nil)
            enabled = true
            status = diagnostic
                ? "Prueba solicitada a iOS. Comprueba pantalla bloqueada y Dynamic Island; no registra visitas."
                : "Panel solicitado a iOS. Comprueba si lo muestra en la pantalla bloqueada."
            inspect()
        } catch {
            enabled = false
            status = "iOS rechazó la actividad: \(error.localizedDescription)"
            inspect()
        }
    }

    func start(near center: GeoPoint?) {
        if !Activity<LivePlaceAttributes>.activities.isEmpty {
            enabled = true
            if let center { Task { await refresh(near: center) } }
            inspect()
            return
        }
        requestActivity(center: center, diagnostic: false)
    }

    /// Start a deliberately simple activity: no candidates, GPS or Link rows.
    /// If compact UI appears but this does not expand, report an extension rendering issue.
    func startVisualTest() {
        Task {
            for activity in Activity<LivePlaceAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            requestActivity(center: nil, diagnostic: true)
        }
    }

    func refresh(near center: GeoPoint) async {
        guard !Activity<LivePlaceAttributes>.activities.isEmpty else { return }
        lastRefreshAt = Date()
        lastRefreshPoint = center
        let content = LivePlaceAttributes.ContentState(updatedAt: Date(),
            title: "¿Dónde estás?", options: suggestions(near: center))
        for activity in Activity<LivePlaceAttributes>.activities {
            await activity.update(ActivityContent(state: content,
                                  staleDate: Date().addingTimeInterval(1800)))
        }
        enabled = true
        inspect()
    }

    func stop() {
        Task {
            for activity in Activity<LivePlaceAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            enabled = false
            status = "Panel cerrado."
            inspect()
        }
    }

    private func suggestions(near center: GeoPoint) -> [LivePlaceOption] {
        NearbyNotificationCache.suggestions(for: center).prefix(3).map { item in
            LivePlaceOption(id: item.id, title: String(item.name.prefix(32)),
                            distance: item.distance.readableDistance)
        }
    }
}
