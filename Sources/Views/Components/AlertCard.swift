import SwiftUI

/// Rich inline alert for the home (spec 2 §4, Figma "Con Alert"): the full
/// story with zero taps — type + affected segment + descriptions + age.
/// Tap still opens LineDetailSheet. Superseded the old compact banner
/// (deleted with spec 2).
struct AlertCard: View {
    let line: LineStatus
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var statusColor: Color { StatusColors.color(for: line.status) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header
                AffectedSegmentTimeline(
                    incidents: line.incidents,
                    lineColor: LineColors.color(for: line.lineNumber)
                )
            }
            .padding(Layout.cardInset)
            .surface(.elevated, cornerRadius: Layout.cornerRadiusMedium, tint: statusColor)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(statusColor.opacity(SurfaceOpacity.border), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(line.lineName), \(line.status.accessibilityLabel), \(relativeAge)")
        .accessibilityHint(String(localized: "Toca para ver el detalle de la línea"))
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            LineBadge(number: line.lineNumber, transportType: line.transportType, size: .small)
                .frame(width: 28, height: 28)

            HStack(spacing: 4) {
                Image(systemName: StatusColors.icon(for: line.status))
                    .font(.subheadline.weight(.semibold))
                    .symbolEffect(.pulse, options: .repeating,
                                  isActive: StatusColors.shouldPulse(for: line.status) && !reduceMotion)
                Text(line.status.displayName)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(statusColor)

            Spacer()

            Text(relativeAge)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Shared formatter — see `RelativeAge` for the rationale ("act." prefix,
    /// no RelativeDateTimeFormatter).
    private var relativeAge: String {
        RelativeAge.text(since: line.lastUpdated)
    }
}

#Preview("L4 Protesta") {
    AlertCard(
        line: LineStatus(
            lineNumber: "4",
            lineName: "Línea 4",
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
        onTap: {}
    )
    .padding()
}

#Preview("Dark Mode") {
    AlertCard(
        line: LineStatus(
            lineNumber: "4",
            lineName: "Línea 4",
            transportType: .metrobus,
            incidents: [
                Incident(
                    status: .protest,
                    affectedStations: ["Buenavista", "Revolución"],
                    info: "Manifestación bloquea circulación"
                )
            ],
            lastUpdated: Date(timeIntervalSinceNow: -180)
        ),
        onTap: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
