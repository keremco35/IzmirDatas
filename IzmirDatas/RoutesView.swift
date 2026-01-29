import SwiftUI

@MainActor
final class RoutesViewModel: ObservableObject {
    @Published var routes: [Route] = []
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
            routes = try await repository.fetchRoutes(forceRefresh: forceRefresh)
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct RoutesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RoutesViewModel
    @State private var query = ""

    init(repository: DatasetsRepository) {
        _viewModel = StateObject(wrappedValue: RoutesViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.routes.isEmpty {
                    ProgressView()
                } else if viewModel.routes.isEmpty {
                    ContentUnavailableView("Hatlar", systemImage: "rectangle.stack", description: Text(viewModel.lastError ?? "Veri bulunamadı."))
                } else {
                    List(filteredRoutes, selection: selectionBinding) { route in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(route.name)
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text(route.number)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let from = route.from, let to = route.to {
                                    Text("\(from) → \(to)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.selectedRoute = route
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Hatlar")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Hat ara")
            .refreshable {
                await viewModel.load(forceRefresh: true)
            }
            .task {
                await viewModel.load()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sıfırla") {
                        appState.selectedRoute = nil
                    }
                    .disabled(appState.selectedRoute == nil)
                }
            }
        }
    }

    private var filteredRoutes: [Route] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.routes }
        return viewModel.routes.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.number.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var selectionBinding: Binding<Set<String>> {
        Binding(
            get: { appState.selectedRoute.map { [$0.id] } ?? [] },
            set: { newValue in
                guard let id = newValue.first else {
                    appState.selectedRoute = nil
                    return
                }
                appState.selectedRoute = viewModel.routes.first(where: { $0.id == id })
            }
        )
    }
}

#Preview {
    RoutesView(repository: DatasetsRepository())
        .environmentObject(AppState())
}
