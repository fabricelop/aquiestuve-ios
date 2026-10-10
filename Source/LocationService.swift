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
    @Published private(set) var walkMode = false
    private var stationaryStart: CLLocation?
    private var latestStationary: CLLocation?
    private var departingSince: Date?
    @Published private(set) var mobilityHint = "Ubicación pasiva"
    private let manager = CLLocationManager()
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
        let savedStart = UserDefaults.standard.object(forKey: "ae_walk_start") as? Date
        walkMode = savedStart.map { Date().timeIntervalSince($0) < 3 * 3600 } ?? false
        startIfAllowed()
    }

    func activate() { startIfAllowed() }
    func requestAccess() { manager.requestWhenInUseAuthorization() }
    func requestBackgroundAccess() { manager.requestAlwaysAuthorization() }

    func setWalkMode(_ enabled: Bool) {
        guard authorization == .authorizedAlways || !enabled else {
            errorText = "Para registrar un paseo con la app bloqueada debes autorizar ubicación Siempre."
            return
        }
        if !enabled { completeStationaryStop() }
        walkMode = enabled
        if enabled {
            UserDefaults.standard.set(Date(), forKey: "ae_walk_start")
            stationaryStart = nil
            latestStationary = nil
            departingSince = nil
        } else {
            UserDefaults.standard.removeObject(forKey: "ae_walk_start")
            mobilityHint = "Ubicación pasiva"
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.distanceFilter = kCLDistanceFilterNone
        }
        startIfAllowed()
    }

    private func completeStationaryStop() {
        guard let first = stationaryStart, let last = latestStationary,
              last.timestamp.timeIntervalSince(first.timestamp) >= 80 else { return }
        VisitStore.shared.receiveWalkStop(position: GeoPoint(first.coordinate),
                                          arrival: first.timestamp, departure: last.timestamp)
        stationaryStart = nil
        latestStationary = nil
        departingSince = nil
    }

    private func observeWalk(_ point: CLLocation) {
        guard walkMode, point.horizontalAccuracy >= 0 && point.horizontalAccuracy <= 55 else { return }
        if let start = UserDefaults.standard.object(forKey: "ae_walk_start") as? Date,
           Date().timeIntervalSince(start) > 3 * 3600 {
            setWalkMode(false)
            return
        }
        // GPS jitter and unreliable instantaneous speed are NOT proof of departure.
        // A dwell is one continuous episode until movement is sustained outside its
        // tolerance zone. Never emit periodic visits just because fixes keep coming.
        guard let first = stationaryStart else {
            if point.speed >= 0 && point.speed < 1.0 {
                stationaryStart = point
                latestStationary = point
                departingSince = nil
                mobilityHint = "Posible parada"
            } else if point.speed >= 2.0 {
                mobilityHint = "En movimiento"
            }
            return
        }
        let delta = point.distance(from: first)
        let departureEvidence = delta > 115 && point.speed >= 1.5
        if departureEvidence {
            if let since = departingSince,
               point.timestamp.timeIntervalSince(since) >= 45 {
                completeStationaryStop()
                mobilityHint = "En movimiento"
            } else if departingSince == nil {
                departingSince = point.timestamp
            }
            return
        }
        // Treat single far-away readings as noise; require sustained travel.
        departingSince = nil
        if delta <= 110 { latestStationary = point }
        mobilityHint = "Parada en curso"
    }

    func startIfAllowed() {
        authorization = manager.authorizationStatus
        if authorization == .authorizedAlways {
            manager.startMonitoringVisits()
            manager.startMonitoringSignificantLocationChanges()
        }
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.requestLocation()
        }
        if walkMode && authorization == .authorizedAlways {
            manager.activityType = .fitness
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            manager.distanceFilter = kCLDistanceFilterNone
            manager.pausesLocationUpdatesAutomatically = false
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            manager.startUpdatingLocation()
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
        observeWalk(location)
        Task { await LivePlacesManager.shared.refreshIfUseful(near: GeoPoint(location.coordinate)) }
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
        Task { await LivePlacesManager.shared.refresh(near: GeoPoint(visit.coordinate)) }
    }
}

@MainActor
enum LocalNotifications {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    static func sendTestNotification(near point: GeoPoint?) {
        let center = UNUserNotificationCenter.current()
        let choices = point.map { NearbyNotificationCache.suggestions(for: $0) } ?? []
        let category = UNNotificationCategory(identifier: "AE_TEST_NOTIFICATION",
            actions: [UNNotificationAction(identifier: "AE_OPEN", title: "Abrir AquíEstuve",
                                           options: [.foreground])], intentIdentifiers: [], options: [])
        center.getNotificationCategories { existing in
            center.setNotificationCategories(existing.union([category]))
            let content = UNMutableNotificationContent()
            content.title = "Prueba de AquíEstuve"
            content.body = choices.isEmpty
                ? "Aviso de prueba. Las visitas reales aparecerán cuando iOS las detecte."
                : "Prueba de lugares conocidos: " + choices.map(\.name).joined(separator: " · ")
            content.categoryIdentifier = "AE_TEST_NOTIFICATION"
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
        }
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
    static func candidate(withID id: String) -> PlaceCandidate? {
        if let data = try? Data(contentsOf: fileURL),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            return snapshot.candidates.first(where: { $0.id == id })
        }
        return nil
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
            if $0.relevanceScore != $1.relevanceScore { return $0.relevanceScore > $1.relevanceScore }
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
