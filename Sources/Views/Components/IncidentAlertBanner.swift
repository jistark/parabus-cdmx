import SwiftUI

/// Alert banner for lines with active incidents - Apple Maps style
struct IncidentAlertBanner: View {
    let line: LineStatus
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // Dynamic Type support - unified badge size
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = Layout.badgeRegular

    private var statusColor: Color {
        StatusColors.color(for: line.status)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Line badge - unified 48pt size
                lineBadgeView
                    .frame(width: badgeSize, height: badgeSize)

                // Incident info
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.lineName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(incidentSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Status badge + chevron
                HStack(spacing: 8) {
                    statusBadge

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64) // Garantizar altura tactil
            .background(bannerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(statusColor.opacity(SurfaceOpacity.border), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(line.lineName), \(incidentSummary)")
        .accessibilityHint("Toca para ver detalles")
    }

    // MARK: - Line Badge

    @ViewBuilder
    private var lineBadgeView: some View {
        if let image = TransitImageLoader.loadOfficialImage(for: line) {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                Circle()
                    .fill(LineColors.color(for: line.lineNumber).gradient)

                Text(line.lineNumber)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: StatusColors.icon(for: line.status))
                .font(.caption2.weight(.semibold))
                .symbolEffect(.pulse, options: .repeating, isActive: line.status == .suspended && !reduceMotion)

            Text(statusText)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(SurfaceOpacity.tintLight), in: Capsule())
    }

    private var statusText: String {
        switch line.status {
        case .regular: return "OK"
        case .intervention: return "Obra"
        case .limited: return "Limitado"
        case .delayed: return "Retraso"
        case .suspended: return "Suspendido"
        case .protest: return "Protestas"
        case .unknown: return "?"
        }
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

    // MARK: - Background

    @ViewBuilder
    private var bannerBackground: some View {
        if reduceTransparency {
            Color(white: colorScheme == .dark ? 0.15 : 0.95)
        } else {
            statusColor.opacity(SurfaceOpacity.tintSubtle)
                .background(.ultraThinMaterial)
        }
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
