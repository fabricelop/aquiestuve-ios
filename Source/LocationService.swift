import Foundation
import Combine
import CoreLocation
import UserNotifications

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    @Published private(set) var coordinate: GeoPoint?
    @Published private(set) var accuracy: Double?
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var errorText: String?
    private let manager = CLLocationManager()
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
        startIfAllowed()
    }

    func activate() { startIfAllowed() }
    func requestAccess() { manager.requestWhenInUseAuthorization() }
    func requestBackgroundAccess() { manager.requestAlwaysAuthorization() }

    func startIfAllowed() {
        authorization = manager.authorizationStatus
        if authorization == .authorizedAlways {
            manager.startMonitoringVisits()
            manager.startMonitoringSignificantLocationChanges()
        }
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func refreshPosition() {
        guard authorization == .authorizedAlways || authorization == .authorizedWhenInUse else { return }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        startIfAllowed()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        coordinate = GeoPoint(location.coordinate)
        accuracy = location.horizontalAccuracy
        errorText = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorText = error.localizedDescription
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let pending = VisitStore.shared.receiveVisit(position: GeoPoint(visit.coordinate),
            accuracy: visit.horizontalAccuracy, arrival: visit.arrivalDate,
            departure: visit.departureDate == .distantFuture ? nil : visit.departureDate)
        if pending, let visitID = VisitStore.shared.activeStay?.id {
            LocalNotifications.sendConfirmationRequest(near: GeoPoint(visit.coordinate), visitID: visitID)
        }
    }
}

@MainActor
enum LocalNotifications {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    static func sendConfirmationRequest(near point: GeoPoint, visitID: UUID) {
        let center = UNUserNotificationCenter.current()
        let choices = NearbyNotificationCache.suggestions(for: point)
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }
            let categoryID = "AE_PLACES_" + UUID().uuidString
            let actions: [UNNotificationAction] = choices.enumerated().map { index, item in
                UNNotificationAction(identifier: "AE_PLACE_\(index)",
                                     title: "Estoy en " + String(item.name.prefix(38)),
                                     options: [])
            } + [UNNotificationAction(identifier: "AE_OPEN", title: "Ver todos",
                                       options: [.foreground])]
            let category = UNNotificationCategory(identifier: categoryID, actions: actions,
                                                 intentIdentifiers: [], options: [])
            center.getNotificationCategories { old in
                // Keep categories for recently delivered notifications; avoid unlimited growth.
                let preserved = old.filter { !$0.identifier.hasPrefix("AE_PLACES_") }
                let recent = old.filter { $0.identifier.hasPrefix("AE_PLACES_") }
                    .sorted { $0.identifier < $1.identifier }.suffix(19)
                center.setNotificationCategories(Set(preserved + recent + [category]))

                let content = UNMutableNotificationContent()
                content.title = "¿Dónde estás?"
                content.body = choices.isEmpty
                    ? "Visita detectada. Toca para elegir un lugar cercano en AquíEstuve."
                    : "Cerca: " + choices.map { $0.name }.joined(separator: " · ")
                content.categoryIdentifier = categoryID
                content.sound = .default
                let payload = VisitNotificationPayload(visitID: visitID, choices: choices)
                if let data = try? JSONEncoder().encode(payload) {
                    content.userInfo = ["ae_choices": data.base64EncodedString()]
                }
                let request = UNNotificationRequest(identifier: UUID().uuidString,
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
                center.add(request)
            }
        }
    }
}

// A small local cache is intentionally used instead of continuous map queries in
// the background. A CLVisit may arrive late, and stale candidates are ignored.
struct NearbyNotificationCache {
    private struct Snapshot: Codable {
        let recordedAt: Date
        let center: GeoPoint
        let candidates: [PlaceCandidate]
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AquiEstuve", isDirectory: true)
            .appendingPathComponent("nearby-notification-cache.json")
    }

    static func save(_ candidates: [PlaceCandidate], center: GeoPoint) {
        let file = fileURL
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Snapshot(recordedAt: Date(), center: center,
                                                         candidates: Array(candidates.prefix(200))))
            try data.write(to: file, options: .atomic)
            try (file as NSURL).setResourceValue(FileProtectionType.completeUntilFirstUserAuthentication,
                                                  forKey: .fileProtectionKey)
        } catch {
            // Cache failures must not interrupt normal location or history tracking.
        }
    }

    @MainActor
    static func suggestions(for point: GeoPoint) -> [PlaceCandidate] {
        let store = VisitStore.shared
        var choices = store.places
            .filter { $0.position.distance(to: point) <= 180 }
            .map { store.savedCandidate(for: $0, near: point) }

        if let data = try? Data(contentsOf: fileURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
           Date().timeIntervalSince(snapshot.recordedAt) < 3 * 3600,
           snapshot.center.distance(to: point) < 250 {
            choices.append(contentsOf: snapshot.candidates.filter {
                $0.position.distance(to: point) <= 180
            }.map { item in
                var revised = item
                revised.distance = item.position.distance(to: point)
                return revised
            })
        }
        var seen = Set<String>()
        return choices.sorted {
            if ($0.visits > 0) != ($1.visits > 0) { return $0.visits > 0 }
            return $0.distance < $1.distance
        }.filter { seen.insert($0.id).inserted }.prefix(3).map { $0 }
    }
}

private struct VisitNotificationPayload: Codable {
    let visitID: UUID
    let choices: [PlaceCandidate]
}

final class PlaceNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let prefix = "AE_PLACE_"
        guard response.actionIdentifier.hasPrefix(prefix),
              let index = Int(response.actionIdentifier.dropFirst(prefix.count)),
              let encoded = response.notification.request.content.userInfo["ae_choices"] as? String,
              let data = Data(base64Encoded: encoded),
              let payload = try? JSONDecoder().decode(VisitNotificationPayload.self, from: data),
              payload.choices.indices.contains(index) else {
            completionHandler()
            return
        }
        Task { @MainActor in
            // Do not overwrite a visit that has already been resolved in the app.
            if VisitStore.shared.stays.contains(where: {
                $0.id == payload.visitID && $0.status == .unresolved
            }) {
                VisitStore.shared.assign(payload.choices[index], to: payload.visitID)
            }
            completionHandler()
        }
    }
}
