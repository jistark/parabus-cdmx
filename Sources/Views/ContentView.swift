import CoreLocation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import UserNotifications
#endif

struct ContentView: View {
    @Environment(MetrobusViewModel.self) private var viewModel
    @Environment(NotificationRouter.self) private var notificationRouter
    @State private var selectedLine: LineStatus?

    /// Location for the "Ahora" card. The home never prompts — it only
    /// requests a fix when permission was already granted (the map view
    /// owns the pre-prompt flow).
    @State private var locationCoordinator = LocationCoordinator()
    @State private var homeVM = HomeViewModel()
    @State private var showingSettings = false
    @State private var showingStationDetail = false
    /// Briefly true after a failed pull-to-refresh so the hero header shows
    /// "No se pudo actualizar" for ~3 seconds before reverting to the timestamp.
    @State private var showRefreshFailure = false
    /// Tracks whether the home tab is on screen, so scenePhase changes don't
    /// re-arm home polling while another tab is visible.
    @State private var isHomeVisible = false
    /// In-app notification pre-prompt (moved from the retired AlertsView,
    /// spec 3 B2 — same first-visit trigger, now on the home).
    @State private var showPermissionPrePrompt = false
    @Namespace private var heroNamespace

    @AppStorage(ParabusConstants.favoriteLinesKey, store: ParabusConstants.sharedDefaults)
    private var favoriteLines: String = ParabusConstants.defaultFavoriteLines
    @AppStorage("homeLineFilter") private var homeLineFilter = "favorites"
    /// Tracks whether we've already shown the in-app pre-prompt offering
    /// to enable notifications. Once true, never shown again — user can
    /// still flip the master toggle in Settings.
    @AppStorage("hasShownNotificationPrePrompt") private var hasShownPrePrompt = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
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
                #if os(iOS)
                UINotificationFeedbackGenerator()
                    .notificationOccurred(viewModel.refreshFailed ? .warning : .success)
                if viewModel.refreshFailed {
                    showRefreshFailure = true
                    try? await Task.sleep(for: .seconds(3))
                    showRefreshFailure = false
                }
                #endif
            }
            .task {
                isHomeVisible = true
                if locationCoordinator.authStatus == .authorized {
                    locationCoordinator.requestLocation()
                }
                homeVM.resolveDeck(userCoordinate: locationCoordinator.latestLocation, favoriteLines: favoriteLinesArray)
                await homeVM.loadServiceColors()
                await homeVM.activate()
                await viewModel.loadStatus()
                await maybeShowPermissionPrePrompt()
            }
            .onChange(of: locationCoordinator.latestLocation) { _, _ in
                reResolveDeck()
            }
            .onChange(of: favoriteLines) { _, _ in
                reResolveDeck()
            }
            .onChange(of: scenePhase) { _, newPhase in
                Task {
                    if newPhase == .active && isHomeVisible { await homeVM.activate() }
                    else if newPhase != .active { await homeVM.deactivate() }
                }
            }
            .onAppear { isHomeVisible = true }
            .onDisappear {
                isHomeVisible = false
                Task { await homeVM.deactivate() }
            }
            // Keep the inline detail in sync across refreshes: the view model
            // rebuilds `LineStatus` values, and `selectedLine` holds a copy —
            // re-point it at the fresh value (or clear it if the line vanished)
            // so the inline detail live-updates.
            .onChange(of: viewModel.allLines) { _, newLines in
                guard let current = selectedLine else { return }
                selectedLine = newLines.first { $0.lineNumber == current.lineNumber }
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
            .confirmationDialog(
                "¿Quieres saber cuándo hay incidentes?",
                isPresented: $showPermissionPrePrompt,
                titleVisibility: .visible
            ) {
                Button("Activar notificaciones") {
                    Task { await requestNotificationsAndPersist() }
                }
                Button("Ahora no", role: .cancel) {
                    // Persist that we showed it so we don't pester them.
                    hasShownPrePrompt = true
                }
            } message: {
                Text("Te avisaremos sobre suspensiones, retrasos o manifestaciones en tus líneas favoritas. Puedes ajustar qué tipos en Ajustes.")
            }
        }
    }

    // MARK: - Notification permission flow

    /// On first ever visit to the home (and only if the user hasn't already
    /// answered), show our pre-prompt. Pre-prompts before the system
    /// dialog have substantially better grant rates than asking cold.
    /// Moved from the retired AlertsView (spec 3 B2).
    private func maybeShowPermissionPrePrompt() async {
        guard !hasShownPrePrompt else { return }
        // Don't show if the system has already given an answer (e.g., user
        // toggled the master switch in Settings first, which already
        // triggered the system dialog).
        #if os(iOS)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            hasShownPrePrompt = true
            return
        }
        #endif
        showPermissionPrePrompt = true
    }

    private func requestNotificationsAndPersist() async {
        hasShownPrePrompt = true
        #if os(iOS)
        let granted = await BackgroundRefreshManager.shared.requestNotificationPermission()
        notificationsEnabled = granted
        await notificationRouter.refreshPermission()
        #endif
    }

    /// If the router has a tapped-notification deep link, surface it by
    /// selecting the corresponding line (the inline detail opens below the
    /// carousel) and scrolling it into view. Clears the link so it isn't
    /// re-applied on subsequent appears — same consume semantics as the
    /// retired AlertsView.
    private func consumePendingDeepLink(proxy: ScrollViewProxy) {
        guard let link = notificationRouter.pendingDeepLink else { return }
        if let line = viewModel.allLines.first(where: { $0.lineNumber == link.lineNumber }) {
            selectedLine = line
            // Next runloop hop so the inline detail exists before we scroll.
            Task { @MainActor in
                if reduceMotion {
                    proxy.scrollTo("lineDetail", anchor: .top)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        proxy.scrollTo("lineDetail", anchor: .top)
                    }
                }
            }
        }
        notificationRouter.pendingDeepLink = nil
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
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .modifier(GlassCircleButton())
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
                // Progress indicator shown while the network request is in
                // flight. controlSize(.small) is one step up from .mini so
                // it sits comfortably next to caption text in the header.
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Actualizando…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Actualizando estado del servicio")
            } else if showRefreshFailure {
                // Transient "failed" copy shown for ~3 s after a PTR error.
                // Plain text swap — no animation needed for Reduce Motion.
                Text("No se pudo actualizar")
                    .font(.caption)
                    .foregroundStyle(StatusColors.warning)
                    .accessibilityLabel("No se pudo actualizar el estado del servicio")
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
                        ? String(localized: "Datos desactualizados. \(description)")
                        : description
                )
            }
        }
        .padding(.horizontal, Layout.screenMargin)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollViewReader { proxy in
            scrollContent(proxy: proxy)
        }
    }

    private func scrollContent(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            // No LiquidGlassContainer here — wrapping all sections in
            // GlassEffectContainer made AlertCard's tinted glass blur into a
            // smeary block that hid its content. The container is designed for
            // cards that morph as they appear/disappear, not for static stacked
            // sections. Each `.surface(_:)` already renders its own glass;
            // that's enough.
            // Home rhythm (Figma spacing pass): the deck hugs its content
            // (NowDeck measures the tallest card), so sectionSpacing (24)
            // lands header→card ≈ 24pt and dots→"Tus líneas" ≈ 28pt — the
            // deck's 16pt dot clearance keeps the page dots tight under the
            // card instead of drifting into the section gap.
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

                    LinesCarousel(
                        lines: carouselLines,
                        selectedLineNumber: selectedLine?.lineNumber
                    ) { line in
                        triggerHaptic()
                        // Tap toggles: re-tapping the selected line deselects.
                        if selectedLine?.lineNumber == line.lineNumber {
                            selectedLine = nil
                        } else {
                            selectedLine = line
                        }
                    }
                }

                // 2b. Inline line detail (Figma home polish A2): replaces the
                // old LineDetailSheet on the home. While a line is selected it
                // becomes the focus — the general alert sections below hide.
                if let selectedLine {
                    LineInlineDetail(line: selectedLine) {
                        triggerHaptic()
                        self.selectedLine = nil
                    }
                    .padding(.horizontal, Layout.cardInset)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .id("lineDetail")  // scroll target for deep links
                }

                if selectedLine == nil {
                    // 3. Active Incidents (real-time urgent issues: delays, suspensions)
                    if !urgentIncidents.isEmpty {
                        urgentIncidentsSection
                    }

                    // 4. Station Interventions (maintenance/obras at specific stations)
                    if !interventionIncidents.isEmpty {
                        stationInterventionsSection
                    }

                    // 5. Scheduled closures (from maintenance calendar, filtered for deduplication)
                    if viewModel.hasMaintenanceToday {
                        scheduledClosuresSection
                    }

                    // 6. All clear: when nothing above rendered, say so instead
                    // of trailing off into empty space.
                    if urgentIncidents.isEmpty && interventionIncidents.isEmpty && !viewModel.hasMaintenanceToday {
                        AllClearBanner(
                            title: String(localized: "Todo bien"),
                            message: String(localized: "Sin incidentes al momento")
                        )
                    }
                }
            }
            .padding(.vertical, Layout.cardInset)
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                value: selectedLine
            )
        }
        // Without this, a content set shorter than the viewport (e.g. a day
        // with zero incidents) doesn't bounce, so pull-to-refresh never
        // engages and its spinner never appears.
        .scrollBounceBehavior(.always, axes: .vertical)
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8),
            value: viewModel.lines.map(\.id)
        )
        // Deep links: mainContent only renders once status has loaded, so a
        // cold launch from a notification tap consumes here on first appear
        // (the old AlertsView consumed after loadStatus in its .task); warm
        // taps land via the onChange.
        .task {
            consumePendingDeepLink(proxy: proxy)
        }
        .onChange(of: notificationRouter.pendingDeepLink) { _, _ in
            consumePendingDeepLink(proxy: proxy)
        }
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
                    isToday: true,
                    onSelectLine: { lineNumber in
                        triggerHaptic()
                        selectedLine = viewModel.allLines.first { $0.lineNumber == lineNumber }
                    }
                )
            }
        }
    }

    /// Re-resolve the deck and re-point the polling surface if the visible
    /// entry actually changed. Called on location updates and favorites changes.
    private func reResolveDeck() {
        let before = homeVM.visibleEntry?.id
        homeVM.resolveDeck(userCoordinate: locationCoordinator.latestLocation, favoriteLines: favoriteLinesArray)
        if homeVM.visibleEntry?.id != before {
            Task { await homeVM.visibleCardChanged() }
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

/// Circular Liquid Glass button for hero-header icon buttons (gear, etc.).
/// iOS 26: native `.buttonStyle(.glass)` with `.buttonBorderShape(.circle)`.
/// Pre-26 / macOS: 36-pt ultraThinMaterial circle, gear in `.secondary`.
/// The 44-pt content shape is preserved on both paths.
private struct GlassCircleButton: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .contentShape(Circle().size(CGSize(width: 44, height: 44)))
        } else {
            legacyCircle(content)
        }
        #else
        legacyCircle(content)
        #endif
    }

    @ViewBuilder
    private func legacyCircle(_ content: Content) -> some View {
        content
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: Circle())
            .contentShape(Circle().size(CGSize(width: 44, height: 44)))
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
