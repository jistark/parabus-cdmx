import SwiftUI
#if os(iOS)
import UserNotifications
#endif

// MARK: - Alerts Tab View
/// Displays incident timeline and active disruptions
/// Design: DESIGN_SYSTEM.md Section 6.4

struct AlertsView: View {
    @Environment(MetrobusViewModel.self) private var viewModel
    @Environment(NotificationRouter.self) private var notificationRouter
    @State private var showFavoritesOnly = true
    @State private var expandedIncidentID: UUID?
    @State private var selectedLine: LineStatus?
    @State private var showPermissionPrePrompt = false

    @AppStorage("favoriteLines") private var favoriteLines: String = "1,2,3"
    /// Tracks whether we've already shown the in-app pre-prompt offering
    /// to enable notifications. Once true, never shown again — user can
    /// still flip the master toggle in Settings.
    @AppStorage("hasShownNotificationPrePrompt") private var hasShownPrePrompt = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var favoriteLinesSet: Set<String> {
        Set(favoriteLines.split(separator: ",").map(String.init))
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
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .background(Color(.systemGroupedBackground))
            #endif
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
            Text("Mis Lineas").tag(true)
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
                    allClearBanner
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
                // Protests (most urgent)
                ForEach(protestLines) { line in
                    TimelineEntryCard(
                        line: line,
                        isActive: true,
                        onTap: { selectedLine = line }
                    )
                }

                // Suspended
                ForEach(suspendedLines) { line in
                    TimelineEntryCard(
                        line: line,
                        isActive: true,
                        onTap: { selectedLine = line }
                    )
                }

                // Delayed
                ForEach(delayedLines) { line in
                    TimelineEntryCard(
                        line: line,
                        isActive: true,
                        onTap: { selectedLine = line }
                    )
                }

                // Limited
                ForEach(limitedLines) { line in
                    TimelineEntryCard(
                        line: line,
                        isActive: true,
                        onTap: { selectedLine = line }
                    )
                }

                // Intervention
                ForEach(interventionLines) { line in
                    TimelineEntryCard(
                        line: line,
                        isActive: true,
                        onTap: { selectedLine = line }
                    )
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

    private var protestLines: [LineStatus] {
        filteredLinesWithIssues.filter { $0.status == .protest }
    }

    private var suspendedLines: [LineStatus] {
        filteredLinesWithIssues.filter { $0.status == .suspended }
    }

    private var delayedLines: [LineStatus] {
        filteredLinesWithIssues.filter { $0.status == .delayed }
    }

    private var limitedLines: [LineStatus] {
        filteredLinesWithIssues.filter { $0.status == .limited }
    }

    private var interventionLines: [LineStatus] {
        filteredLinesWithIssues.filter { $0.status == .intervention }
    }

    // MARK: - All Clear Banner

    private var allClearBanner: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            VStack(spacing: Spacing.xs) {
                Text("Sin incidentes")
                    .font(.headline)

                Text(showFavoritesOnly
                    ? "Tus lineas favoritas operan con normalidad"
                    : "Todas las lineas operan con normalidad")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Empty State

    private var emptyAlertsView: some View {
        ContentUnavailableView {
            Label("Sin informacion", systemImage: "tray")
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
            Label("Sin conexion", systemImage: "wifi.slash")
        } description: {
            Text("No pudimos obtener las alertas.\nVerifica tu conexion a internet.")
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

// MARK: - Timeline Entry Card

struct TimelineEntryCard: View {
    let line: LineStatus
    let isActive: Bool
    let onTap: () -> Void

    private var statusColor: Color {
        StatusColors.color(for: line.status)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                // Time / Status indicator
                VStack(spacing: 4) {
                    if isActive {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(statusColor.opacity(0.3), lineWidth: 4)
                            )
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .frame(width: Layout.minTouchTarget)

                // Line badge — uses the canonical component
                LineBadge(number: line.lineNumber, transportType: line.transportType, size: .small)
                    .frame(width: 36, height: 36)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(line.lineName)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        // Status pill
                        Text(StatusColors.shortText(for: line.status))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(SurfaceOpacity.tintMedium), in: Capsule())
                    }

                    if !line.affectedStations.isEmpty {
                        Text(line.affectedStations.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let info = line.additionalInfo {
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Layout.cardInset)
            .padding(.vertical, Spacing.sm)
            .surface(
                isActive ? .elevated : .base,
                cornerRadius: Layout.cornerRadiusMedium,
                tint: isActive ? statusColor : nil
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium)
                    .strokeBorder(
                        isActive ? statusColor.opacity(0.3) : Color.secondary.opacity(0.15),
                        lineWidth: isActive ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lineName), \(line.status.accessibilityLabel)")
        .accessibilityHint("Toca para ver detalles")
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
