import SwiftUI

/// Inline line detail rendered on the home between the carousel and the
/// alert sections when a carousel line is selected (Figma home polish, A2).
/// Compact sibling of `LineDetailSheet` (which still serves the map and
/// alerts surfaces): identity + status chip header, then the affected-segment
/// timeline (or a compact all-clear), with the same card chrome as AlertCard.
struct LineInlineDetail: View {
    let line: LineStatus
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var statusColor: Color { StatusColors.color(for: line.status) }
    private var lineColor: Color { LineColors.color(for: line.lineNumber) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header

            if line.hasIssues {
                AffectedSegmentTimeline(
                    incidents: line.incidents,
                    lineColor: lineColor
                )
            } else {
                allClearRow
            }
        }
        .padding(Layout.cardInset)
        .surface(.elevated, cornerRadius: Layout.cornerRadiusMedium, tint: lineColor)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium, style: .continuous)
                .strokeBorder(lineColor.opacity(SurfaceOpacity.border), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            LineBadge(number: line.lineNumber, transportType: line.transportType, size: .small)
                .frame(width: 28, height: 28)

            Text(line.lineName)
                .brandTitle(BrandTypography.lineLabel)

            statusChip

            Spacer(minLength: Spacing.xs)

            Text(RelativeAge.text(since: line.lastUpdated))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .contentShape(Circle().size(CGSize(width: 44, height: 44)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Cerrar detalle de línea"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(line.lineName), \(line.status.accessibilityLabel), \(RelativeAge.text(since: line.lastUpdated))"
        )
    }

    /// Status chip — mirrors the pill in LineDetailSheet's hero header.
    private var statusChip: some View {
        HStack(spacing: 4) {
            Image(systemName: StatusColors.icon(for: line.status))
                .font(.caption.weight(.semibold))
                .symbolEffect(.pulse, options: .repeating,
                              isActive: StatusColors.shouldPulse(for: line.status) && !reduceMotion)

            Text(line.status.displayName)
                .brandTitle(BrandTypography.statusLabel)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs - 2)
        .background(statusColor.opacity(SurfaceOpacity.tintLight), in: Capsule())
        .lineLimit(1)
    }

    // MARK: - All clear

    /// Compact inline all-clear — AllClearBanner's 48-pt icon + xl padding is
    /// section-sized; this card needs a single tight row.
    private var allClearRow: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(StatusColors.good)
            Text("Sin incidentes reportados")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Con incidentes") {
    LineInlineDetail(
        line: LineStatus(
            lineNumber: "4",
            transportType: .metrobus,
            incidents: [
                Incident(
                    status: .protest,
                    affectedStations: ["Buenavista", "Revolución", "Hidalgo"],
                    info: "Manifestación bloquea circulación en Paseo de la Reforma"
                ),
                Incident(
                    status: .delayed,
                    affectedStations: ["Campeche", "Sonora"],
                    info: "Retraso de 15 min por desviación de ruta"
                )
            ],
            lastUpdated: Date(timeIntervalSinceNow: -420)
        ),
        onClose: {}
    )
    .padding()
}

#Preview("Sin incidentes") {
    LineInlineDetail(
        line: LineStatus(
            lineNumber: "1",
            transportType: .metrobus,
            status: .regular,
            lastUpdated: Date(timeIntervalSinceNow: -60)
        ),
        onClose: {}
    )
    .padding()
}

#Preview("Dark Mode") {
    LineInlineDetail(
        line: LineStatus(
            lineNumber: "6",
            transportType: .metrobus,
            status: .suspended,
            affectedStations: ["Aragón", "Villa de Aragón"],
            additionalInfo: "Servicio suspendido por operativo especial",
            lastUpdated: Date(timeIntervalSinceNow: -180)
        ),
        onClose: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
