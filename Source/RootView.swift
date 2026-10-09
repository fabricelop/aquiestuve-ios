import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: VisitStore
    var body: some View {
        TabView {
            NavigationStack { NowView() }
                .tabItem { Label("Ahora", systemImage: "location.circle.fill") }
            NavigationStack { HistoryView() }
                .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }
            NavigationStack { StatisticsView() }
                .tabItem { Label("Estadísticas", systemImage: "chart.bar.xaxis") }
            NavigationStack { SavedPlacesView() }
                .tabItem { Label("Lugares", systemImage: "mappin.and.ellipse") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .tint(.indigo)
    }
}
