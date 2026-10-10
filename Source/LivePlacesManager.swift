import ActivityKit
import Foundation
import Combine

@MainActor
final class LivePlacesManager: ObservableObject {
    static let shared = LivePlacesManager()
    @Published private(set) var enabled = !Activity<LivePlaceAttributes>.activities.isEmpty
    @Published private(set) var status = ""
    private var lastRefreshAt: Date = .distantPast
    private var lastRefreshPoint: GeoPoint?
    private init() {}

    func refreshIfUseful(near center: GeoPoint) async {
        guard enabled, !Activity<LivePlaceAttributes>.activities.isEmpty else { return }
        // A location fix must not continuously rebuild the Lock Screen UI.
        if Date().timeIntervalSince(lastRefreshAt) < 180,
           (lastRefreshPoint?.distance(to: center) ?? 0) < 100 { return }
        await refresh(near: center)
    }

    func start(near center: GeoPoint?) {
        let bundledWidget = Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("AquiEstuveLiveWidget.appex")
        guard let widget = bundledWidget,
              FileManager.default.fileExists(atPath: widget.path) else {
            status = "La firma actual no incluye la extensión. La app principal sigue funcionando."
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Activa Actividades en directo para AquíEstuve en Ajustes del iPhone."
            return
        }
        if !Activity<LivePlaceAttributes>.activities.isEmpty {
            enabled = true
            if let center { Task { await refresh(near: center) } }
            return
        }
        let options = center.map { suggestions(near: $0) } ?? []
        let attributes = LivePlaceAttributes(sessionID: UUID().uuidString)
        let content = LivePlaceAttributes.ContentState(updatedAt: Date(),
            title: "¿Dónde estás?", options: options)
        do {
            _ = try Activity.request(attributes: attributes,
                  content: ActivityContent(state: content, staleDate: Date().addingTimeInterval(1800)),
                  pushType: nil)
            enabled = true
            status = "Panel iniciado. Toca un sitio para abrir su ficha y confirmarlo."
        } catch {
            enabled = false
            status = "No se pudo iniciar la Actividad en directo: \(error.localizedDescription)"
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
    }

    func stop() {
        Task {
            for activity in Activity<LivePlaceAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            enabled = false
            status = "Panel cerrado."
        }
    }

    private func suggestions(near center: GeoPoint) -> [LivePlaceOption] {
        // This cache is local and capped: no background geocoding or periodic network requests.
        let options = NearbyNotificationCache.suggestions(for: center)
        return options.prefix(3).map { item in
            LivePlaceOption(id: item.id, title: String(item.name.prefix(32)),
                            distance: item.distance.readableDistance)
        }
    }
}
