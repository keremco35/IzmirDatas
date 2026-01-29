import MapKit
import SwiftUI

@MainActor
final class LiveMapViewModel: ObservableObject {
    @Published var positions: [VehiclePosition] = []
    @Published var isRefreshing = false
    @Published var lastError: String?

    private let repository: DatasetsRepository
    private var loopTask: Task<Void, Never>?

    init(repository: DatasetsRepository) {
        self.repository = repository
    }

    func start() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func refresh() async {
        if isRefreshing { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let items = try await repository.fetchVehiclePositions()
            positions = items
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct LiveMapView: View {
    @StateObject private var viewModel: LiveMapViewModel
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.423734, longitude: 27.142826),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )

    init(repository: DatasetsRepository) {
        _viewModel = StateObject(wrappedValue: LiveMapViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    ForEach(viewModel.positions) { position in
                        Marker(position.routeNumber ?? "Otobüs", coordinate: CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude))
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }

                if let lastError = viewModel.lastError {
                    Text(lastError)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Canlı Konum")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        if viewModel.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Yenile")
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

#Preview {
    LiveMapView(repository: DatasetsRepository())
}
