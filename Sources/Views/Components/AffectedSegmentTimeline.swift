import SwiftUI

/// Figma-fidelity affected-segment timeline for alert cards (spec 2.1, A4):
/// per-incident pin badges + dotted connector + station names + incident
/// description. Multiple incidents stack with `Spacing.md` separation.
///
/// Age / timestamp: intentionally NOT rendered here. The worker exposes only
/// `LineStatus.lastUpdated` (the fetch time), not a per-incident timestamp.
/// Per-incident first-seen tracking is a spec-3 candidate. The card's header
/// already displays "act. hace N min" once per card — a second age label here
/// would duplicate data we don't have at incident granularity.
///
/// `CompactStationTimeline` is kept unchanged; it serves `LineDetailSheet`.
struct AffectedSegmentTimeline: View {
    let incidents: [Incident]
    let lineColor: Color

    // MARK: - Layout constants

    /// Fixed width for the badge column so names and description text all
    /// share the same leading edge.
    private let badgeColumnWidth: CGFloat = 22
    /// Badge corner radius — rounded-square feel at 22pt.
    private let badgeCornerRadius: CGFloat = 6
    /// Dot size for the dotted connector.
    private let dotSize: CGFloat = 2.5

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(Array(incidents.enumerated()), id: \.offset) { _, incident in
                incidentBlock(incident)
            }
        }
    }

    // MARK: - Incident block

    private func incidentBlock(_ incident: Incident) -> some View {
        let stations = incident.affectedStations.isEmpty
            ? ["Toda la línea"]
            : incident.affectedStations
        let statusColor = StatusColors.color(for: incident.status)

        // Accessibility: merge the whole block into one element for VoiceOver.
        let a11yLabel = accessibilityLabel(stations: stations, info: incident.info)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stations.enumerated()), id: \.offset) { index, station in
                // Station row
                stationRow(station: station, statusColor: statusColor)

                // Dotted connector — shown between consecutive stations, not after the last.
                if index < stations.count - 1 {
                    dottedConnector
                }
            }

            // Incident description, padded to align with station names.
            if let info = incident.info, !info.isEmpty {
                descriptionRow(info)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11yLabel)
    }

    // MARK: - Station row

    private func stationRow(station: String, statusColor: Color) -> some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            // Pin badge — 22pt rounded-square filled with the incident status color.
            ZStack {
                RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous)
                    .fill(statusColor)
                    .frame(width: badgeColumnWidth, height: badgeColumnWidth)

                Image(systemName: "mappin")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: badgeColumnWidth) // fixed-width column

            // Station name — SF footnote semibold, uppercased, secondary tint.
            // spec-2 typography note: the Figma crop shows SF caps, NOT Movin.
            // We use .footnote.weight(.semibold) + .textCase(.uppercase) to match.
            Text(station)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Dotted connector

    /// Three small tertiary dots aligned under the badge column.
    private var dottedConnector: some View {
        HStack(spacing: 0) {
            // Align dots under the center of the badge column.
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: dotSize, height: dotSize)
                }
            }
            .frame(width: badgeColumnWidth) // matches badge column width
            .padding(.vertical, 2)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Description row

    private func descriptionRow(_ info: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            // Invisible spacer matching the badge column so text aligns with names.
            Color.clear
                .frame(width: badgeColumnWidth, height: 0)

            Text(info)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.xs)
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(stations: [String], info: String?) -> String {
        var parts: [String] = []

        if stations == ["Toda la línea"] {
            parts.append("Toda la línea afectada")
        } else {
            parts.append(stations.joined(separator: ", "))
        }

        if let info = info, !info.isEmpty {
            parts.append(info)
        }

        return parts.joined(separator: ". ")
    }
}

// MARK: - Previews

#Preview("1 incident — 2 stations") {
    AffectedSegmentTimeline(
        incidents: [
            Incident(
                status: .protest,
                affectedStations: ["Buenavista", "Revolución"],
                info: "Manifestación bloquea circulación en Paseo de la Reforma"
            )
        ],
        lineColor: LineColors.line4
    )
    .padding()
}

#Preview("2 incidents") {
    AffectedSegmentTimeline(
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
        lineColor: LineColors.line4
    )
    .padding()
}

#Preview("Toda la línea") {
    AffectedSegmentTimeline(
        incidents: [
            Incident(
                status: .suspended,
                affectedStations: [],
                info: "Servicio suspendido por operativo especial"
            )
        ],
        lineColor: LineColors.line1
    )
    .padding()
}

#Preview("Dark mode") {
    AffectedSegmentTimeline(
        incidents: [
            Incident(
                status: .protest,
                affectedStations: ["Buenavista", "Revolución"],
                info: "Manifestación bloquea circulación"
            ),
            Incident(
                status: .delayed,
                affectedStations: ["Campeche"],
                info: "Retraso de 10 min"
            )
        ],
        lineColor: LineColors.line4
    )
    .padding()
    .preferredColorScheme(.dark)
}
