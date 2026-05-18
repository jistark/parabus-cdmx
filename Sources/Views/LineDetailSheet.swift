import SwiftUI

/// Detail sheet for a single line. Surfaces the line identity + every
/// incident with its affected stations and explanatory info.
///
/// Layout intentionally tight: header (line + status), incidents timeline,
/// done. The previous "Información" section duplicated everything already in
/// the header (Sistema/Línea/Estado/Afectadas count) — removed.
struct LineDetailSheet: View {
    let line: LineStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Dynamic Type support - unified badge size
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = Layout.badgeRegular

    private var statusColor: Color {
        StatusColors.color(for: line.status)
    }

    private var lineColor: Color {
        LineColors.color(for: line.lineNumber)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                compactHeader
                    .padding(.top, Spacing.sm)

                if !line.incidents.isEmpty {
                    incidentsSection
                } else {
                    allClearMessage
                        .padding(.top, Spacing.lg)
                }

                Spacer(minLength: Spacing.xl)
            }
            .padding(.horizontal, Layout.cardInset)
        }
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #endif
    }

    /// Shown when the sheet opens for a line with no active incidents — the
    /// header already says "Servicio Normal", but a friendly confirmation
    /// avoids leaving the user staring at a near-empty sheet wondering if
    /// data failed to load.
    private var allClearMessage: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(StatusColors.good)
            Text("Sin incidentes reportados")
                .font(BrandTypography.lineLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Compact Header

    private var compactHeader: some View {
        HStack(spacing: Layout.cardInset) {
            // Line badge — canonical component handles fallback + shadow + Tipo Movin
            LineBadge(number: line.lineNumber, transportType: line.transportType, size: .large)
                .frame(width: badgeSize, height: badgeSize)

            // Line info
            VStack(alignment: .leading, spacing: 4) {
                Text(line.lineName)
                    .font(BrandTypography.displayMedium)

                statusPill
            }

            Spacer()
        }
        .padding(Layout.cardInset)
        .surface(
            line.status.isNormal ? .base : .elevated,
            cornerRadius: Layout.cornerRadiusLarge - 4,
            tint: line.status.isNormal ? nil : statusColor
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lineName), \(line.status.accessibilityLabel)")
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: StatusColors.icon(for: line.status))
                .font(.caption.weight(.semibold))
                .symbolEffect(.pulse, options: .repeating, isActive: shouldPulse && !reduceMotion)

            Text(StatusColors.displayText(for: line.status))
                .font(BrandTypography.statusLabel)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs - 2)
        .background(statusColor.opacity(SurfaceOpacity.tintLight), in: Capsule())
    }

    // MARK: - Incidents Section

    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: Layout.inlineSpacing) {
            // Section header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(StatusColors.warning)
                Text(line.incidentCount == 1 ? "Incidente" : "\(line.incidentCount) incidentes")
                    .font(BrandTypography.lineLabel)
            }

            // Compact timeline - incidents sorted by severity (most severe first)
            CompactStationTimeline(
                incidents: sortedIncidents,
                lineColor: lineColor
            )
        }
    }

    // MARK: - Helpers

    /// Incidents sorted by severity (suspended > delayed > intervention > unknown > regular)
    private var sortedIncidents: [Incident] {
        line.incidents.sorted { $0.status > $1.status }
    }

    private var shouldPulse: Bool {
        line.status == .suspended || line.status == .delayed
    }
}

// MARK: - Previews

#Preview("With Issues") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "2",
        transportType: .metrobus,
        status: .intervention,
        affectedStations: ["La Joya", "Iztacalco", "UAM-I"],
        additionalInfo: "Por mantenimiento a la estacion"
    ))
}

#Preview("Normal Service") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "1",
        transportType: .metrobus,
        status: .regular,
        affectedStations: []
    ))
}

#Preview("Multiple Incidents") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "1",
        transportType: .metrobus,
        incidents: [
            Incident(
                status: .intervention,
                affectedStations: ["Indios Verdes", "Potrero"],
                info: "Mantenimiento de estacion"
            ),
            Incident(
                status: .delayed,
                affectedStations: ["Buenavista"],
                info: "Alta afluencia de usuarios"
            ),
            Incident(
                status: .suspended,
                affectedStations: ["La Raza"],
                info: "Cierre temporal por obras"
            )
        ]
    ))
}

#Preview("Large Text") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "4",
        transportType: .metrobus,
        status: .suspended,
        affectedStations: ["San Lazaro"]
    ))
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}

#Preview("Dark Mode") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "4",
        transportType: .metrobus,
        status: .suspended,
        affectedStations: ["San Lazaro", "Mixcoac"]
    ))
    .preferredColorScheme(.dark)
}
