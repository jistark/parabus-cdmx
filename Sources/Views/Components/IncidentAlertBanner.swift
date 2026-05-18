import SwiftUI

/// Alert banner for lines with active incidents - Apple Maps style
struct IncidentAlertBanner: View {
    let line: LineStatus
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Dynamic Type support - unified badge size
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = Layout.badgeRegular

    private var statusColor: Color {
        StatusColors.color(for: line.status)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Layout.inlineSpacing) {
                // Line badge - unified 48pt size
                lineBadgeView
                    .frame(width: badgeSize, height: badgeSize)

                // Incident info
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.lineName)
                        .brandTitle(BrandTypography.lineLabel)
                        .foregroundStyle(.primary)

                    Text(incidentSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Status badge + chevron
                HStack(spacing: Spacing.xs) {
                    statusBadge

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Layout.cardInset)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: Layout.alertRowMinHeight)
            .surface(.elevated, cornerRadius: Layout.cornerRadiusMedium, tint: statusColor)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(statusColor.opacity(SurfaceOpacity.border), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(line.lineName), \(line.status.accessibilityLabel)")
        .accessibilityHint("Toca para ver detalles")
    }

    // MARK: - Line Badge

    private var lineBadgeView: some View {
        LineBadge(number: line.lineNumber, transportType: line.transportType, size: .regular)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: StatusColors.icon(for: line.status))
                .font(.caption2.weight(.semibold))
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    isActive: StatusColors.shouldPulse(for: line.status) && !reduceMotion
                )

            Text(StatusColors.shortText(for: line.status))
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, Layout.pillInset)
        .padding(.vertical, Spacing.xs - 2)
        .background(statusColor.opacity(SurfaceOpacity.tintLight), in: Capsule())
    }

    // MARK: - Summary

    private var incidentSummary: String {
        if line.incidentCount > 1 {
            return "\(line.incidentCount) incidentes en \(line.affectedStations.count) estaciones"
        }

        if line.affectedStations.isEmpty {
            return line.status.rawValue
        }

        if line.affectedStations.count == 1 {
            return line.affectedStations[0]
        }

        return "\(line.affectedStations[0]) y \(line.affectedStations.count - 1) mas"
    }

}

#Preview("Single Banner") {
    VStack(spacing: 12) {
        IncidentAlertBanner(
            line: LineStatus(
                lineNumber: "2",
                transportType: .metrobus,
                status: .intervention,
                affectedStations: ["La Joya", "Iztacalco"],
                additionalInfo: "Mantenimiento"
            ),
            onTap: {}
        )

        IncidentAlertBanner(
            line: LineStatus(
                lineNumber: "4",
                transportType: .metrobus,
                status: .suspended,
                affectedStations: ["Buenavista"]
            ),
            onTap: {}
        )

        IncidentAlertBanner(
            line: LineStatus(
                lineNumber: "6",
                transportType: .metrobus,
                status: .delayed,
                affectedStations: ["Centro Medico", "Etiopia"]
            ),
            onTap: {}
        )
    }
    .padding()
}

#Preview("Large Text") {
    IncidentAlertBanner(
        line: LineStatus(
            lineNumber: "1",
            transportType: .metrobus,
            status: .intervention,
            affectedStations: ["Indios Verdes"]
        ),
        onTap: {}
    )
    .padding()
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}

#Preview("Dark Mode") {
    IncidentAlertBanner(
        line: LineStatus(
            lineNumber: "1",
            transportType: .metrobus,
            status: .suspended,
            affectedStations: ["Indios Verdes", "Potrero"]
        ),
        onTap: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
