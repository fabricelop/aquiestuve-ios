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
        if pending { LocalNotifications.sendConfirmationRequest() }
    }
}

enum LocalNotifications {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    static func sendConfirmationRequest() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "¿Dónde estás?"
            content.body = "AquíEstuve ha detectado una visita. Elige el lugar cuando puedas."
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
            center.add(request)
        }
    }
}
