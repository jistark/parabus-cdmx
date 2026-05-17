import SwiftUI

// MARK: - Alerts Tab View
/// Displays incident timeline and active disruptions
/// Design: DESIGN_SYSTEM.md Section 6.4

struct AlertsView: View {
    @State private var viewModel = MetrobusViewModel()
    @State private var showFavoritesOnly = true
    @State private var expandedIncidentID: UUID?
    @State private var selectedLine: LineStatus?

    @AppStorage("favoriteLines") private var favoriteLines: String = "1,2,3"
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
                await syncIncidentHistory()
            }
            .task {
                await viewModel.loadStatus()
                await syncIncidentHistory()
            }
            .sheet(item: $selectedLine) { line in
                LineDetailSheet(line: line)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
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

                // Timeline history (today's incidents)
                timelineSection

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
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(StatusColors.critical)
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(activeIncidentCount) incidente\(activeIncidentCount == 1 ? "" : "s") activo\(activeIncidentCount == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))

                Text(showFavoritesOnly ? "en tus lineas favoritas" : "en todas las lineas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(StatusColors.critical.opacity(0.1), in: RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium)
                .strokeBorder(StatusColors.critical.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Current Incidents Section

    private var currentIncidentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack {
                Text("Incidentes actuales")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)

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

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section header
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("Historial de hoy")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            // Timeline entries would come from IncidentHistoryManager
            // For now, show a placeholder if no history
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("El historial se actualiza con cada consulta")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, Spacing.lg)
            }
            .padding(.horizontal, Spacing.md)
        }
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

    // MARK: - Sync Incident History

    private func syncIncidentHistory() async {
        await IncidentHistoryManager.shared.syncWithCurrentStatus(viewModel.allLines)
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                .frame(width: 44)

                // Line badge
                lineBadgeView
                    .frame(width: 36, height: 36)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(line.lineName)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        // Status badge
                        Text(StatusColors.shortText(for: line.status))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.15), in: Capsule())
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
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium))
            .overlay(cardBorder)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lineName), \(line.status.rawValue)")
        .accessibilityHint("Toca para ver detalles")
    }

    @ViewBuilder
    private var lineBadgeView: some View {
        if let image = TransitImageLoader.loadOfficialImage(for: line) {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                Circle()
                    .fill(LineColor.color(for: line.lineNumber).gradient)

                Text(line.lineNumber)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            Color(white: colorScheme == .dark ? 0.15 : 0.95)
        } else if isActive {
            statusColor.opacity(0.08)
                .background(.ultraThinMaterial)
        } else {
            Color.clear.background(.ultraThinMaterial)
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium)
            .strokeBorder(
                isActive ? statusColor.opacity(0.3) : Color.secondary.opacity(0.15),
                lineWidth: isActive ? 1 : 0.5
            )
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(closures.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, Spacing.lg)

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
