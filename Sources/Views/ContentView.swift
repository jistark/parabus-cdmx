import CoreLocation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(MetrobusViewModel.self) private var viewModel
    @State private var selectedLine: LineStatus?

    /// Location for the "Ahora" card. The home never prompts — it only
    /// requests a fix when permission was already granted (the map view
    /// owns the pre-prompt flow).
    @State private var locationCoordinator = LocationCoordinator()
    @State private var homeVM = HomeViewModel()
    @State private var showingSettings = false
    @State private var showingStationDetail = false
    @Namespace private var heroNamespace

    @AppStorage(ParabusConstants.favoriteLinesKey, store: ParabusConstants.sharedDefaults)
    private var favoriteLines: String = ParabusConstants.defaultFavoriteLines
    @AppStorage("homeLineFilter") private var homeLineFilter = "favorites"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var favoriteLinesArray: [String] {
        FavoriteLines.parse(favoriteLines)
    }

    /// True when showing skeleton (first load with no cached data)
    private var showSkeleton: Bool {
        viewModel.lines.isEmpty && viewModel.isLoading && !viewModel.hasError
    }

    /// Stale data indicator: upstream flagged its response as cached/partial,
    /// or the last refresh failed while showing cached data.
    private var showsStaleWarning: Bool {
        viewModel.isStale || viewModel.sourceWarning != nil
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
                if locationCoordinator.authStatus == .authorized {
                    locationCoordinator.requestLocation()
                }
                homeVM.resolveDeck(userCoordinate: locationCoordinator.latestLocation, favoriteLines: favoriteLinesArray)
                await homeVM.loadServiceColors()
                await homeVM.activate()
                await viewModel.loadStatus()
            }
            .onChange(of: locationCoordinator.latestLocation) { _, _ in
                homeVM.resolveDeck(userCoordinate: locationCoordinator.latestLocation, favoriteLines: favoriteLinesArray)
            }
            .onChange(of: scenePhase) { _, newPhase in
                Task {
                    if newPhase == .active { await homeVM.activate() }
                    else { await homeVM.deactivate() }
                }
            }
            .onDisappear { Task { await homeVM.deactivate() } }
            .sheet(item: $selectedLine) { line in
                LineDetailSheet(line: line)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingStationDetail) {
                if let entry = homeVM.visibleEntry {
                    StationDetailSheet(
                        station: entry.station,
                        lineStatus: lineStatus(for: entry.station)
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .modifier(ZoomFromHero(id: "nowCard", namespace: heroNamespace))
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationDetents([.medium, .large])
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
        HStack(spacing: Spacing.sm) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .accessibilityLabel(String(localized: "Ajustes"))

            Text("PARABÚS")
                .brandTitle(BrandTypography.displayLarge)
                // VoiceOver: the title announces the network state up front
                // ("Parabús. 2 líneas con incidentes") while the gear stays
                // a separately reachable element.
                .accessibilityLabel(Text("Parabús. \(viewModel.statusSummary)"))
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if viewModel.isRefreshing {
                RefreshingIndicator()
            } else if let description = viewModel.lastUpdatedDescription {
                // Warning tint when the data is stale (upstream served
                // cache, refresh failed, or cache aged out) — the
                // timestamp itself is the staleness signal.
                HStack(spacing: 4) {
                    if showsStaleWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                    }
                    Text(description)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(showsStaleWarning ? StatusColors.warning : Color.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    showsStaleWarning
                        ? "Datos desactualizados. \(description)"
                        : description
                )
            }
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

                // 1. "Ahora": the swipeable station deck — the station the
                // traveler needs right now (plus commute stations), with
                // next arrivals. Fills the answer-shaped hole the home had
                // when service was all-normal. Cards pad inside the pager.
                if !homeVM.deck.isEmpty {
                    NowDeck(deck: homeVM.deck, visibleIndex: Binding(
                        get: { homeVM.visibleIndex },
                        set: { newValue in
                            homeVM.visibleIndex = newValue
                            Task { await homeVM.visibleCardChanged() }
                        }
                    )) { entry in
                        Button {
                            triggerHaptic()
                            showingStationDetail = true
                        } label: {
                            StationNowCard(
                                station: entry.station,
                                source: entry.source,
                                distanceMeters: distanceMeters(to: entry.station),
                                commute: entry.id == homeVM.deck.first?.id ? homeVM.commuteContext : nil,
                                lineStatus: lineStatus(for: entry.station)?.status,
                                liveRows: homeVM.legacyStations.contains(entry.id)
                                    ? nil
                                    : homeVM.arrivals[entry.id]?.rows,
                                serviceColors: homeVM.serviceColors
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(String(localized: "Ver todas las llegadas"))
                    }
                    .matchedTransitionSource(id: "nowCard", in: heroNamespace)
                }

                // 2. Lines Carousel — "Tus líneas" by default, switchable to
                // all lines via the header menu (timestamp moved to the hero
                // header).
                VStack(alignment: .leading, spacing: Layout.inlineSpacing) {
                    HStack {
                        Menu {
                            Picker("Filtro", selection: $homeLineFilter) {
                                Text("Tus líneas").tag("favorites")
                                Text("Todas las líneas").tag("all")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(homeLineFilter == "favorites" ? "Tus líneas" : "Todas las líneas")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Layout.screenMargin)

                    LinesCarousel(lines: carouselLines) { line in
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

                // 5. All clear: when nothing above rendered, say so instead
                // of trailing off into empty space.
                if urgentIncidents.isEmpty && interventionIncidents.isEmpty && !viewModel.hasMaintenanceToday {
                    AllClearBanner(
                        title: String(localized: "Todo bien"),
                        message: String(localized: "Sin incidentes al momento")
                    )
                }
            }
            .padding(.vertical, Layout.cardInset)
        }
        // Without this, a content set shorter than the viewport (e.g. a day
        // with zero incidents) doesn't bounce, so pull-to-refresh never
        // engages and its spinner never appears.
        .scrollBounceBehavior(.always, axes: .vertical)
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8),
            value: viewModel.lines.map(\.id)
        )
    }

    // MARK: - Lines Carousel Filter

    /// Carousel content for the "Tus líneas" / "Todas las líneas" toggle.
    /// Falls back to all lines whenever the favorites filter would yield an
    /// empty section.
    private var carouselLines: [LineStatus] {
        guard homeLineFilter == "favorites", !favoriteLinesArray.isEmpty else {
            return viewModel.allLines
        }
        let favorites = FavoriteLines.asSet(favoriteLines)
        let filtered = viewModel.allLines.filter { favorites.contains($0.lineNumber) }
        return filtered.isEmpty ? viewModel.allLines : filtered // never an empty section
    }

    // MARK: - Incident Categories

    /// Lines with urgent real-time issues (delays, suspensions) - filtered
    /// by favorites, most severe first (shared severity ordering).
    private var urgentIncidents: [LineStatus] {
        IncidentGrouping.grouped(
            viewModel.linesWithIssues
                .filter { favoriteLinesArray.contains($0.lineNumber) }
                .filter { $0.status == .delayed || $0.status == .suspended || $0.status == .protest }
        )
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

            // Alert cards (full story with zero taps)
            VStack(spacing: Spacing.xs) {
                ForEach(urgentIncidents) { line in
                    AlertCard(line: line) {
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

            // Intervention cards
            VStack(spacing: Spacing.xs) {
                ForEach(interventionIncidents) { line in
                    AlertCard(line: line) {
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

    /// Real-time status for the line serving a station.
    private func lineStatus(for station: GTFSStation) -> LineStatus? {
        viewModel.allLines.first { $0.lineNumber == station.lineNumber }
    }

    private func distanceMeters(to station: GTFSStation) -> Double? {
        guard let coordinate = locationCoordinator.latestLocation else { return nil }
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(
                latitude: station.coordinate.latitude,
                longitude: station.coordinate.longitude
            ))
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
            Label("Sin información", systemImage: "tray")
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
            Label("Sin conexión", systemImage: "wifi.slash")
        } description: {
            Text("No pudimos obtener el estado del servicio.\nVerifica tu conexión a internet.")
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

/// Zoom transition from the hero card (iOS-only API; no-op on the SwiftPM
/// macOS test target).
private struct ZoomFromHero: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationTransition(.zoom(sourceID: id, in: namespace))
        #else
        content
        #endif
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
