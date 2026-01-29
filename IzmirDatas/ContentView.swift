import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedRoute: Route?
    @Published var selectedStop: Stop?
}

struct ContentView: View {
    @StateObject private var appState = AppState()
    private let repository = DatasetsRepository()

    var body: some View {
        TabView {
            LiveMapView(repository: repository)
                .tabItem { Label("Harita", systemImage: "map") }

            RoutesView(repository: repository)
                .tabItem { Label("Hatlar", systemImage: "list.bullet") }

            StopsView(repository: repository)
                .tabItem { Label("Duraklar", systemImage: "mappin.and.ellipse") }

            TimetableView(repository: repository)
                .tabItem { Label("Saatler", systemImage: "clock") }
        }
        .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
