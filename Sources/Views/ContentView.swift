import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(MetrobusViewModel.self) private var viewModel
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
            .navigationTitle("Parabús")     // VoiceOver / multitasking switcher only
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)  // Hero header below takes its place
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
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Hero Header
    //
    // Custom large-title equivalent so we can render the app name in Tipo Movin
    // CDMX (the official MB typeface, which the brand renders in caps). The
    // system `.navigationTitle` is kept hidden so VoiceOver and the app
    // switcher still pick up "Parabús" with normal pronunciation.

    private var heroHeader: some View {
        HStack {
            Text("PARABÚS")
                .brandTitle(BrandTypography.displayLarge)
                .accessibilityHidden(true)   // navigationTitle reads instead
            Spacer()
        }
        .padding(.horizontal, Layout.screenMargin)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            // No LiquidGlassContainer here — wrapping all sections in
            // GlassEffectContainer made the IncidentAlertBanner's tinted glass
            // blur into a smeary block that hid its content. The container is
            // designed for cards that morph as they appear/disappear, not for
            // static stacked sections. Each `.surface(_:)` already renders its
            // own glass; that's enough.
            VStack(spacing: Layout.sectionSpacing) {
                heroHeader

                // 1. Lines Carousel (all lines at a glance)
                VStack(alignment: .leading, spacing: Layout.inlineSpacing) {
                    HStack {
                        Text("Líneas")
                            .brandTitle(BrandTypography.lineLabel)
                        Spacer()

                        if viewModel.isRefreshing {
                            RefreshingIndicator()
                        } else if let description = viewModel.lastUpdatedDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, Layout.screenMargin)

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
            .padding(.vertical, Layout.cardInset)
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
        VStack(alignment: .leading, spacing: Layout.inlineSpacing) {
            // Section header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(StatusColors.critical)
                Text("Incidentes activos")
                    .brandTitle(BrandTypography.lineLabel)
            }
            .padding(.horizontal, Layout.screenMargin)

            // Alert banners
            VStack(spacing: Spacing.xs) {
                ForEach(urgentIncidents) { line in
                    IncidentAlertBanner(line: line) {
                        triggerHaptic()
                        selectedLine = line
                    }
                }
            }
            .padding(.horizontal, Layout.cardInset)
        }
    }

    // MARK: - Station Interventions Section

    private var stationInterventionsSection: some View {
        VStack(alignment: .leading, spacing: Layout.inlineSpacing) {
            // Section header
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundStyle(StatusColors.warning)
                Text("Estaciones cerradas")
                    .brandTitle(BrandTypography.lineLabel)
            }
            .padding(.horizontal, Layout.screenMargin)

            // Intervention banners
            VStack(spacing: Spacing.xs) {
                ForEach(interventionIncidents) { line in
                    IncidentAlertBanner(line: line) {
                        triggerHaptic()
                        selectedLine = line
                    }
                }
            }
            .padding(.horizontal, Layout.cardInset)
        }
    }

    // MARK: - Scheduled Closures Section

    /// Closures filtered by favorite lines
    private var filteredClosures: [ScheduledClosure] {
        viewModel.deduplicatedTodaysClosures.filter { favoriteLinesArray.contains($0.lineNumber) }
    }

    private var scheduledClosuresSection: some View {
        VStack(alignment: .leading, spacing: Layout.inlineSpacing) {
            // Section header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("Cierres programados")
                    .brandTitle(BrandTypography.lineLabel)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, Layout.screenMargin)

            // Closures content
            if filteredClosures.isEmpty {
                // No closures for favorite lines
                HStack {
                    Spacer()
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("Sin cierres en tus líneas")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Layout.screenMargin)
                    Spacer()
                }
                .surface(.base, cornerRadius: Layout.cornerRadiusSmall + 4)
                .padding(.horizontal, Layout.screenMargin)
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
