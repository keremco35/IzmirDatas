import SwiftUI

@MainActor
final class TimetableViewModel: ObservableObject {
    @Published var entries: [TimetableEntry] = []
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
            entries = try await repository.fetchTimetable(forceRefresh: forceRefresh)
            lastError = nil
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

enum TimetableScope: String, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }
}

struct TimetableView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: TimetableViewModel

    @State private var scope: TimetableScope = .daily
    @State private var serviceDay: ServiceDay = .weekday
    @State private var direction: Direction = .outbound

    init(repository: DatasetsRepository) {
        _viewModel = StateObject(wrappedValue: TimetableViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.selectedRoute == nil {
                    ContentUnavailableView(
                        "Hareket saatleri",
                        systemImage: "calendar",
                        description: Text("Önce bir hat seçin. İsterseniz bir durak da seçerek filtreleyebilirsiniz.")
                    )
                } else if viewModel.isLoading && viewModel.entries.isEmpty {
                    ProgressView()
                } else if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "Kayıt bulunamadı",
                        systemImage: "clock.badge.exclamationmark",
                        description: Text(viewModel.lastError ?? "Seçili hat/durak için uygun kayıt bulunamadı.")
                    )
                } else {
                    List {
                        Section {
                            Picker("Görünüm", selection: $scope) {
                                Text("Günlük").tag(TimetableScope.daily)
                                Text("Haftalık").tag(TimetableScope.weekly)
                            }
                            .pickerStyle(.segmented)

                            Picker("Gün", selection: $serviceDay) {
                                Text("Hafta içi").tag(ServiceDay.weekday)
                                Text("Cumartesi").tag(ServiceDay.saturday)
                                Text("Pazar").tag(ServiceDay.sunday)
                            }
                            .pickerStyle(.segmented)
                            .opacity(scope == .daily ? 1 : 0)
                            .frame(height: scope == .daily ? nil : 0)

                            Picker("Yön", selection: $direction) {
                                Text("Gidiş").tag(Direction.outbound)
                                Text("Dönüş").tag(Direction.inbound)
                            }
                            .pickerStyle(.segmented)
                        }

                        if scope == .daily {
                            Section(header: Text("Saatler")) {
                                ForEach(dailyEntries) { entry in
                                    TimetableRow(entry: entry)
                                }
                            }
                        } else {
                            ForEach(ServiceDay.allCases, id: \.self) { day in
                                let items = weeklyEntries(for: day)
                                if !items.isEmpty {
                                    Section(header: Text(title(for: day))) {
                                        ForEach(items) { entry in
                                            TimetableRow(entry: entry)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saatler")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.load(forceRefresh: true) }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private var filteredEntries: [TimetableEntry] {
        guard let route = appState.selectedRoute else { return [] }
        let stopId = appState.selectedStop?.id

        return viewModel.entries
            .filter { $0.routeNumber == route.number }
            .filter { entry in
                guard let stopId else { return true }
                guard let entryStopId = entry.stopId else { return true }
                return entryStopId == stopId
            }
            .filter { $0.direction == direction }
    }

    private var dailyEntries: [TimetableEntry] {
        filteredEntries
            .filter { $0.serviceDay == serviceDay }
            .sorted(by: { $0.time < $1.time })
    }

    private func weeklyEntries(for day: ServiceDay) -> [TimetableEntry] {
        filteredEntries
            .filter { $0.serviceDay == day }
            .sorted(by: { $0.time < $1.time })
    }

    private func title(for day: ServiceDay) -> String {
        switch day {
        case .weekday: "Hafta içi"
        case .saturday: "Cumartesi"
        case .sunday: "Pazar"
        }
    }
}

private struct TimetableRow: View {
    let entry: TimetableEntry

    var body: some View {
        HStack {
            Text(entry.time)
                .font(.headline.monospacedDigit())
            Spacer()
            HStack(spacing: 8) {
                if entry.wheelchairAccessible == true {
                    Image(systemName: "figure.roll")
                }
                if entry.bikeRack == true {
                    Image(systemName: "bicycle")
                }
                if entry.electric == true {
                    Image(systemName: "bolt.car")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TimetableView(repository: DatasetsRepository())
        .environmentObject(AppState())
}
