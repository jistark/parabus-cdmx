import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @State private var viewModel = MetrobusViewModel()
    @State private var selectedLine: LineStatus?

    @AppStorage("favoriteLines") private var favoriteLines: String = "1,2,3"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var favoriteLinesArray: [String] {
        favoriteLines.split(separator: ",").map(String.init)
    }

    /// True when showing skeleton (first load with no cached data)
    private var showSkeleton: Bool {
        viewModel.lines.isEmpty && viewModel.isLoading && !viewModel.hasError
    }

    var body: some View {
        NavigationStack {
            Group {
                if showSkeleton {
                    skeletonView
                } else if viewModel.isEmpty && !viewModel.hasError {
                    emptyView
                } else if viewModel.hasError {
                    errorView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Parabús")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .background(Color(.systemGroupedBackground))
            #endif
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadStatus()
            }
            .sheet(item: $selectedLine) { line in
                LineDetailSheet(line: line)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Lines Carousel (all lines at a glance)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Lineas")
                            .font(.headline)
                        Spacer()

                        // Show refreshing indicator or last updated time
                        if viewModel.isRefreshing {
                            RefreshingIndicator()
                        } else if let description = viewModel.lastUpdatedDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    LinesCarousel(lines: viewModel.allLines) { line in
                        triggerHaptic()
                        selectedLine = line
                    }
                }

                // 2. Active Incidents (real-time urgent issues: delays, suspensions)
                if !urgentIncidents.isEmpty {
                    urgentIncidentsSection
                }

                // 3. Station Interventions (maintenance/obras at specific stations)
                if !interventionIncidents.isEmpty {
                    stationInterventionsSection
                }

                // 4. Scheduled closures (from maintenance calendar, filtered for deduplication)
                if viewModel.hasMaintenanceToday {
                    scheduledClosuresSection
                }
            }
            .padding(.vertical, 16)
        }
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8),
            value: viewModel.lines.map(\.id)
        )
    }

    // MARK: - Incident Categories

    /// Lines with urgent real-time issues (delays, suspensions) - filtered by favorites
    private var urgentIncidents: [LineStatus] {
        viewModel.linesWithIssues
            .filter { favoriteLinesArray.contains($0.lineNumber) }
            .filter { $0.status == .delayed || $0.status == .suspended || $0.status == .protest }
            .sorted { $0.status > $1.status }
    }

    /// Lines with station interventions (maintenance/obras) - filtered by favorites
    private var interventionIncidents: [LineStatus] {
        viewModel.linesWithIssues
            .filter { favoriteLinesArray.contains($0.lineNumber) }
            .filter { $0.status == .intervention || $0.status == .limited }
            .sorted { $0.lineNumber.localizedStandardCompare($1.lineNumber) == .orderedAscending }
    }

    // MARK: - Urgent Incidents Section

    private var urgentIncidentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(StatusColors.critical)
                Text("Incidentes activos")
                    .font(.headline)
            }
            .padding(.horizontal, 20)

            // Alert banners
            VStack(spacing: 8) {
                ForEach(urgentIncidents) { line in
                    IncidentAlertBanner(line: line) {
                        triggerHaptic()
                        selectedLine = line
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Station Interventions Section

    private var stationInterventionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(StatusColors.warning)
                Text("Estaciones cerradas")
                    .font(.headline)
            }
            .padding(.horizontal, 20)

            // Intervention banners
            VStack(spacing: 8) {
                ForEach(interventionIncidents) { line in
                    IncidentAlertBanner(line: line) {
                        triggerHaptic()
                        selectedLine = line
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Scheduled Closures Section

    /// Closures filtered by favorite lines
    private var filteredClosures: [ScheduledClosure] {
        viewModel.deduplicatedTodaysClosures.filter { favoriteLinesArray.contains($0.lineNumber) }
    }

    private var scheduledClosuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("Cierres programados")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 20)

            // Closures content
            if filteredClosures.isEmpty {
                // No closures for favorite lines
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("Sin cierres en tus líneas")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                MaintenanceSection(
                    closures: filteredClosures,
                    title: "", // We already show the header
                    icon: "calendar.badge.clock",
                    isToday: true
                )
            }
        }
    }

    // MARK: - Haptic Feedback

    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    // MARK: - Skeleton Loading State

    private var skeletonView: some View {
        ScrollView {
            ContentSkeleton(incidentCardCount: 2)
        }
        .scrollDisabled(true)
    }

    // MARK: - Empty State

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Sin informacion", systemImage: "tray")
        } description: {
            Text("No hay datos de servicio disponibles.\nDesliza hacia abajo para actualizar.")
        } actions: {
            Button {
                Task { await viewModel.loadStatus() }
            } label: {
                Label("Actualizar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Error State

    private var errorView: some View {
        ContentUnavailableView {
            Label("Sin conexion", systemImage: "wifi.slash")
        } description: {
            Text("No pudimos obtener el estado del servicio.\nVerifica tu conexion a internet.")
        } actions: {
            Button {
                Task { await viewModel.loadStatus() }
            } label: {
                Label("Reintentar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Preview

#Preview("Normal") {
    ContentView()
}

#Preview("Large Text") {
    ContentView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}
