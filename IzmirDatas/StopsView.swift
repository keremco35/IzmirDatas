import CoreLocation
import SwiftUI

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startUpdates()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}

@MainActor
final class StopsViewModel: ObservableObject {
    @Published var allStops: [Stop] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let repository: DatasetsRepository

    init(repository: DatasetsRepository) {
        self.repository = repository
    }

    func load(forceRefresh: Bool = false) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            allStops = try await repository.fetchStops(forceRefresh: forceRefresh)
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct StopsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: StopsViewModel
    @StateObject private var locationService = LocationService()

    @State private var radiusMeters: Double = 1000
    @State private var query = ""
    @State private var onlySelectedRouteStops = false

    init(repository: DatasetsRepository) {
        _viewModel = StateObject(wrappedValue: StopsViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if needsLocationPrompt {
                    ContentUnavailableView(
                        "Konum gerekli",
                        systemImage: "location.slash",
                        description: Text("Yakındaki durakları listelemek için konum izni vermeniz gerekir.")
                    )
                    .padding()
                    .safeAreaInset(edge: .bottom) {
                        Button("Konum İzni Ver") {
                            locationService.requestAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                } else if viewModel.isLoading && viewModel.allStops.isEmpty {
                    ProgressView()
                } else if filteredStops.isEmpty {
                    ContentUnavailableView(
                        "Durak bulunamadı",
                        systemImage: "mappin.slash",
                        description: Text(viewModel.lastError ?? "Filtreyi genişletmeyi deneyin.")
                    )
                } else {
                    List(filteredStops) { stop in
                        Button {
                            appState.selectedStop = stop
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stop.name)
                                        .font(.headline)
                                    Text("ID: \(stop.id)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let distanceText = distanceText(for: stop) {
                                    Text(distanceText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Duraklar")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Durak ara")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Yarıçap", selection: $radiusMeters) {
                            Text("250 m").tag(250.0)
                            Text("500 m").tag(500.0)
                            Text("1 km").tag(1000.0)
                            Text("2 km").tag(2000.0)
                            Text("5 km").tag(5000.0)
                        }

                        Toggle("Sadece seçili hat durakları", isOn: $onlySelectedRouteStops)
                            .disabled(appState.selectedRoute == nil)
                    } label: {
                        Label("Filtre", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sıfırla") {
                        appState.selectedStop = nil
                    }
                    .disabled(appState.selectedStop == nil)
                }
            }
            .refreshable {
                await viewModel.load(forceRefresh: true)
            }
            .task {
                await viewModel.load()
                if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                    locationService.startUpdates()
                }
            }
        }
    }

    private var needsLocationPrompt: Bool {
        switch locationService.authorizationStatus {
        case .notDetermined, .restricted, .denied:
            return true
        default:
            return false
        }
    }

    private var filteredStops: [Stop] {
        guard let current = locationService.lastLocation else {
            return []
        }

        let routeFilter = appState.selectedRoute
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return viewModel.allStops
            .filter { stop in
                let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                return current.distance(from: stopLocation) <= radiusMeters
            }
            .filter { stop in
                if onlySelectedRouteStops, let route = routeFilter {
                    return stop.passingRouteNumbers.contains(where: { $0 == route.number })
                }
                return true
            }
            .filter { stop in
                guard !trimmed.isEmpty else { return true }
                return stop.name.localizedCaseInsensitiveContains(trimmed) || stop.id.localizedCaseInsensitiveContains(trimmed)
            }
            .sorted { a, b in
                let da = current.distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude))
                let db = current.distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
                return da < db
            }
    }

    private func distanceText(for stop: Stop) -> String? {
        guard let current = locationService.lastLocation else { return nil }
        let d = current.distance(from: CLLocation(latitude: stop.latitude, longitude: stop.longitude))
        if d < 1000 {
            return "\(Int(d)) m"
        }
        return String(format: "%.1f km", d / 1000.0)
    }
}

#Preview {
    StopsView(repository: DatasetsRepository())
        .environmentObject(AppState())
}
