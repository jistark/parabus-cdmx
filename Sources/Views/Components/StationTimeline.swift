import SwiftUI

/// Timeline visualization of stations with incidents - Apple Maps transit style
struct StationTimeline: View {
    let incidents: [Incident]
    let lineColor: Color

    // Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var stationDotSize: CGFloat = TimelineSize.stationDot
    @ScaledMetric(relativeTo: .body) private var innerDotSize: CGFloat = TimelineSize.innerDot
    @ScaledMetric(relativeTo: .body) private var trackWidth: CGFloat = TimelineSize.trackWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(incidents.enumerated()), id: \.offset) { index, incident in
                incidentSection(incident, isLast: index == incidents.count - 1)
            }
        }
    }

    @ViewBuilder
    private func incidentSection(_ incident: Incident, isLast: Bool) -> some View {
        if incident.affectedStations.isEmpty {
            // Whole-line incident
            wholeLineRow(incident, isLast: isLast)
        } else {
            // Station-specific incidents
            ForEach(Array(incident.affectedStations.enumerated()), id: \.offset) { stationIndex, station in
                let isLastStation = isLast && stationIndex == incident.affectedStations.count - 1
                stationRow(
                    station: station,
                    status: incident.status,
                    info: stationIndex == 0 ? incident.info : nil,
                    isLast: isLastStation
                )
            }
        }
    }

    private func wholeLineRow(_ incident: Incident, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline track
            VStack(spacing: 0) {
                // Station dot - now 20pts
                ZStack {
                    Circle()
                        .fill(StatusColor.color(for: incident.status))
                        .frame(width: stationDotSize, height: stationDotSize)

                    Image(systemName: iconForStatus(incident.status))
                        .font(.system(size: TimelineSize.statusIcon, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Connecting line
                if !isLast {
                    Rectangle()
                        .fill(lineColor.opacity(MaterialOpacity.border))
                        .frame(width: TimelineSize.connectorWidth)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: trackWidth)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Toda la linea")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(incident.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(StatusColor.color(for: incident.status))

                    if let info = incident.info, !info.isEmpty {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Toda la linea, \(incident.status.rawValue)")
    }

    private func stationRow(station: String, status: ServiceStatus, info: String?, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline track
            VStack(spacing: 0) {
                // Station dot - now 20pts
                ZStack {
                    Circle()
                        .fill(StatusColor.color(for: status))
                        .frame(width: stationDotSize, height: stationDotSize)

                    Circle()
                        .fill(.white)
                        .frame(width: innerDotSize, height: innerDotSize)
                }

                // Connecting line
                if !isLast {
                    Rectangle()
                        .fill(lineColor.opacity(MaterialOpacity.border))
                        .frame(width: TimelineSize.connectorWidth)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: trackWidth)

            // Station content
            VStack(alignment: .leading, spacing: 4) {
                Text(station)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Image(systemName: StatusColor.icon(for: status))
                        .font(.caption2)
                        .foregroundStyle(StatusColor.color(for: status))

                    Text(statusText(status))
                        .font(.caption)
                        .foregroundStyle(StatusColor.color(for: status))

                    if let info = info, !info.isEmpty {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(station), \(statusText(status))")
    }

    // MARK: - Helpers

    private func iconForStatus(_ status: ServiceStatus) -> String {
        switch status {
        case .regular: return "checkmark"
        case .intervention: return "wrench.fill"
        case .limited: return "arrow.left.arrow.right"
        case .delayed: return "clock.fill"
        case .suspended: return "xmark"
        case .protest: return "megaphone.fill"
        case .unknown: return "questionmark"
        }
    }

    private func statusText(_ status: ServiceStatus) -> String {
        switch status {
        case .regular: return "Normal"
        case .intervention: return "Intervencion"
        case .limited: return "Limitado"
        case .delayed: return "Retraso"
        case .suspended: return "Suspendido"
        case .protest: return "Manifestacion"
        case .unknown: return "Desconocido"
        }
    }
}

// MARK: - Compact Timeline (for detail sheet)

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

#Preview("Station Timeline") {
    ScrollView {
        StationTimeline(
            incidents: [
                Incident(status: .intervention, affectedStations: ["Indios Verdes", "Potrero"], info: "Mantenimiento"),
                Incident(status: .delayed, affectedStations: ["Buenavista"], info: "Alta afluencia"),
                Incident(status: .suspended, affectedStations: ["La Raza"], info: "Cierre temporal")
            ],
            lineColor: LineColor.line1
        )
        .padding()
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
