import SwiftUI
import UIKit
import UserNotifications

@main
struct AquiEstuveApp: App {
    @UIApplicationDelegateAdaptor(BackgroundAppDelegate.self) private var appDelegate
    @StateObject private var store = VisitStore.shared
    @StateObject private var location = LocationService.shared

    init() { LocationService.shared.activate() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(location)
        }
    }
}

final class BackgroundAppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = PlaceNotificationDelegate()
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // The CLLocationManager delegate is recreated even when iOS relaunches the app for a visit.
        _ = LocationService.shared
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}
