import SwiftUI
#if os(iOS)
import UserNotifications
#endif

// MARK: - Alerts Tab View
/// Displays incident timeline and active disruptions
/// Design: DESIGN_SYSTEM.md Section 6.4
///
/// DEPRECATION (spec 3): this tab dies with the 3+search tab bar. Its
/// reusable machinery already lives in Components/ and Models/ (spec 2 §5);
/// what remains here is tab-only UI. Deep-link handling migrates to the
/// home in spec 3 — do not remove it before that.

struct AlertsView: View {
    @Environment(MetrobusViewModel.self) private var viewModel
    @Environment(NotificationRouter.self) private var notificationRouter
    @State private var showFavoritesOnly = true
    @State private var expandedIncidentID: UUID?
    @State private var selectedLine: LineStatus?
    @State private var showPermissionPrePrompt = false

    @AppStorage(ParabusConstants.favoriteLinesKey, store: ParabusConstants.sharedDefaults)
    private var favoriteLines: String = ParabusConstants.defaultFavoriteLines
    /// Tracks whether we've already shown the in-app pre-prompt offering
    /// to enable notifications. Once true, never shown again — user can
    /// still flip the master toggle in Settings.
    @AppStorage("hasShownNotificationPrePrompt") private var hasShownPrePrompt = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var favoriteLinesSet: Set<String> {
        FavoriteLines.asSet(favoriteLines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter toggle
                filterPicker

                // Content
                Group {
                    if viewModel.isEmpty && !viewModel.hasError {
                        emptyAlertsView
                    } else if viewModel.hasError {
                        errorView
                    } else {
                        timelineContent
                    }
                }
            }
            .navigationTitle("Alertas")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            #endif
            // .always: short content (no incidents) otherwise doesn't bounce,
            // so pull-to-refresh can't engage.
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadStatus()
                await maybeShowPermissionPrePrompt()
                consumePendingDeepLink()
            }
            // Tab switched to Alerts via a notification tap — present the
            // affected line's sheet so the user lands directly on detail.
            .onChange(of: notificationRouter.pendingDeepLink) { _, _ in
                consumePendingDeepLink()
            }
            .sheet(item: $selectedLine) { line in
                LineDetailSheet(line: line)
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

    /// On first ever visit to Alerts (and only if the user hasn't already
    /// answered), show our pre-prompt. Pre-prompts before the system
    /// dialog have substantially better grant rates than asking cold.
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
    /// opening the corresponding line's detail sheet. Clears the link so
    /// it isn't re-applied on subsequent appears.
    private func consumePendingDeepLink() {
        guard let link = notificationRouter.pendingDeepLink else { return }
        if let line = viewModel.allLines.first(where: { $0.lineNumber == link.lineNumber }) {
            selectedLine = line
        }
        notificationRouter.pendingDeepLink = nil
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filtro", selection: $showFavoritesOnly) {
            Text("Mis líneas").tag(true)
            Text("Todas").tag(false)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Active incidents summary
                if activeIncidentCount > 0 {
                    activeIncidentsSummary
                }

                // Current incidents by severity
                if !filteredLinesWithIssues.isEmpty {
                    currentIncidentsSection
                }

                // Scheduled maintenance
                if viewModel.hasMaintenanceToday && !filteredClosures.isEmpty {
                    maintenanceSection
                }

                // All clear message when no current issues
                if filteredLinesWithIssues.isEmpty && !viewModel.hasMaintenanceToday {
                    AllClearBanner(
                        title: "Sin incidentes",
                        message: showFavoritesOnly
                            ? "Tus líneas favoritas operan con normalidad"
                            : "Todas las líneas operan con normalidad"
                    )
                    .padding(.top, Spacing.xl)
                }
            }
            .padding(.vertical, Spacing.md)
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
            value: showFavoritesOnly
        )
    }

    // MARK: - Active Incidents Summary

    private var activeIncidentCount: Int {
        filteredLinesWithIssues.reduce(0) { $0 + $1.incidentCount }
    }

    private var activeIncidentsSummary: some View {
        HStack(spacing: Layout.inlineSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(StatusColors.critical)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(activeIncidentCount) incidente\(activeIncidentCount == 1 ? "" : "s") activo\(activeIncidentCount == 1 ? "" : "s")")
                    .brandTitle(BrandTypography.lineLabel)

                Text(showFavoritesOnly ? "en tus líneas favoritas" : "en todas las líneas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Layout.cardInset)
        .surface(.elevated, cornerRadius: Layout.cornerRadiusMedium, tint: StatusColors.critical)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium)
                .strokeBorder(StatusColors.critical.opacity(SurfaceOpacity.borderStrong - 0.1), lineWidth: 1)
        )
        .padding(.horizontal, Layout.cardInset)
        .padding(.bottom, Layout.cardInset)
    }

    // MARK: - Current Incidents Section

    private var currentIncidentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack {
                Text("Incidentes actuales")
                    .brandTitle(BrandTypography.lineLabel)
                Spacer()
            }
            .padding(.horizontal, Layout.screenMargin)

            // Grouped by severity
            VStack(spacing: Spacing.xs) {
                ForEach(IncidentGrouping.grouped(filteredLinesWithIssues)) { line in
                    TimelineEntryCard(line: line, isActive: true, onTap: { selectedLine = line })
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Maintenance Section

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            MaintenanceAlertSection(closures: filteredClosures)
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Filtered Data

    private var filteredLinesWithIssues: [LineStatus] {
        let lines = viewModel.linesWithIssues
        if showFavoritesOnly {
            return lines.filter { favoriteLinesSet.contains($0.lineNumber) }
        }
        return lines
    }

    private var filteredClosures: [ScheduledClosure] {
        let closures = viewModel.deduplicatedTodaysClosures
        if showFavoritesOnly {
            return closures.filter { favoriteLinesSet.contains($0.lineNumber) }
        }
        return closures
    }

    // MARK: - Empty State

    private var emptyAlertsView: some View {
        ContentUnavailableView {
            Label("Sin información", systemImage: "tray")
        } description: {
            Text("No hay datos disponibles.\nDesliza hacia abajo para actualizar.")
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
            Text("No pudimos obtener las alertas.\nVerifica tu conexión a internet.")
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

// MARK: - Maintenance Alert Section

struct MaintenanceAlertSection: View {
    let closures: [ScheduledClosure]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section Header
            HStack(spacing: Spacing.xs) {
                Image(systemName: "clock.badge.xmark")
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.semibold))

                Text("Cierres programados")
                    .brandTitle(BrandTypography.lineLabel)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(closures.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(SurfaceOpacity.tintLight), in: Capsule())
            }
            .padding(.horizontal, Layout.screenMargin)

            // Maintenance cards
            MaintenanceSection(
                closures: closures,
                title: "",
                icon: "calendar.badge.clock",
                isToday: true
            )
        }
    }
}

// MARK: - Previews

#Preview("With Alerts") {
    AlertsView()
}

#Preview("Large Text") {
    AlertsView()
        .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}

#Preview("Dark Mode") {
    AlertsView()
        .preferredColorScheme(.dark)
}
