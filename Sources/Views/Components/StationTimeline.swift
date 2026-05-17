import SwiftUI

/// Compact timeline used in LineDetailSheet to show incidents per line.
///
/// History: this file also contained a fuller `StationTimeline` variant with
/// per-station rows + connecting track styling, but it was never referenced
/// outside its own #Preview and was deleted along with the parallel
/// LineRowView / StatusHeroCard / LineStatusGrid surfaces (Phase 2 of
/// REVIEW.md cleanup).
struct CompactStationTimeline: View {
    let incidents: [Incident]
    let lineColor: Color

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var statusBadgeSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(incidents.enumerated()), id: \.offset) { index, incident in
                compactIncidentRow(incident, index: index + 1, isLast: index == incidents.count - 1)
            }
        }
        .padding(12)
        .background(
            reduceTransparency
                ? AnyShapeStyle(Color(white: colorScheme == .dark ? 0.15 : 0.92))
                : AnyShapeStyle(Color.secondary.opacity(MaterialOpacity.subtle)),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private func compactIncidentRow(_ incident: Incident, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(StatusColor.color(for: incident.status).opacity(MaterialOpacity.medium))
                    .frame(width: statusBadgeSize, height: statusBadgeSize)

                Image(systemName: StatusColor.icon(for: incident.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(StatusColor.color(for: incident.status))
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                // Station(s) or "Toda la linea"
                Text(stationsText(incident))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                // Status + info (full text, no truncation)
                if let info = incident.info, !info.isEmpty {
                    Text(info)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // Status pill
            Text(StatusColor.shortText(for: incident.status))
                .font(.caption2.weight(.medium))
                .foregroundStyle(StatusColor.color(for: incident.status))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StatusColor.color(for: incident.status).opacity(MaterialOpacity.light), in: Capsule())
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, 38)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stationsText(incident)), \(incident.status.rawValue)")
    }

    private func stationsText(_ incident: Incident) -> String {
        if incident.affectedStations.isEmpty {
            return "Toda la linea"
        } else if incident.affectedStations.count == 1 {
            return incident.affectedStations[0]
        } else {
            return incident.affectedStations.joined(separator: ", ")
        }
    }
}

#Preview("Compact Timeline") {
    CompactStationTimeline(
        incidents: [
            Incident(status: .intervention, affectedStations: ["Indios Verdes", "Potrero"], info: "Mantenimiento de estacion"),
            Incident(status: .delayed, affectedStations: ["Buenavista"], info: "Alta afluencia"),
            Incident(status: .suspended, affectedStations: ["La Raza", "Autobuses del Norte"], info: "Cierre temporal")
        ],
        lineColor: LineColor.line1
    )
    .padding()
}

#Preview("Large Text") {
    CompactStationTimeline(
        incidents: [
            Incident(status: .intervention, affectedStations: ["Centro Medico"], info: "Mantenimiento"),
            Incident(status: .delayed, affectedStations: ["Etiopia"], info: nil)
        ],
        lineColor: LineColor.line6
    )
    .padding()
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}

#Preview("Dark Mode") {
    CompactStationTimeline(
        incidents: [
            Incident(status: .intervention, affectedStations: ["Centro Medico"], info: "Mantenimiento"),
            Incident(status: .delayed, affectedStations: ["Etiopia"], info: nil)
        ],
        lineColor: LineColor.line6
    )
    .padding()
    .preferredColorScheme(.dark)
}
