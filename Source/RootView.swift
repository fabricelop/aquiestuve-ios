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
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { NowView() }
                .tabItem { Label("Ahora", systemImage: "location.circle.fill") }.tag(0)
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
            guard url.scheme == "aquiestuve", url.host == "place",
                  let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value else { return }
            router.requestedPlaceID = id
            tab = 0
        }
    }
}
