import SwiftUI
import Combine

@MainActor
final class PlaceDeepLinkRouter: ObservableObject {
    static let shared = PlaceDeepLinkRouter()
    @Published var requestedPlaceID: String?
}

struct RootView: View {
    @EnvironmentObject private var store: VisitStore
    @StateObject private var router = PlaceDeepLinkRouter.shared
    @State private var tab = 0
    @State private var openExplorer = false
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                PulseView(openExplorer: $openExplorer)
                    .navigationDestination(isPresented: $openExplorer) { NowView() }
            }
                .tabItem { Label("Radar", systemImage: "scope") }.tag(0)
            NavigationStack { HistoryView() }
                .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }.tag(1)
            NavigationStack { StatisticsView() }
                .tabItem { Label("Estadísticas", systemImage: "chart.bar.xaxis") }.tag(2)
            NavigationStack { SavedPlacesView() }
                .tabItem { Label("Lugares", systemImage: "mappin.and.ellipse") }.tag(3)
            NavigationStack { SettingsView() }
                .tabItem { Label("Ajustes", systemImage: "gearshape") }.tag(4)
        }
        .tint(.indigo)
        .onOpenURL { url in
            guard url.scheme == "aquiestuve" else { return }
            if url.host == "place" {
                if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value {
                    router.requestedPlaceID = id
                }
            } else if url.host != "places" { return }
            tab = 0
            openExplorer = true
        }
    }
}
