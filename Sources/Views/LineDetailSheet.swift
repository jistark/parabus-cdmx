import SwiftUI

/// Compact detail sheet for a line
struct LineDetailSheet: View {
    let line: LineStatus
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // Dynamic Type support - unified badge size
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = BadgeSize.regular.dimension

    private var statusColor: Color {
        StatusColor.color(for: line.status)
    }

    private var lineColor: Color {
        LineColor.color(for: line.lineNumber)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Compact header
                    compactHeader
                        .padding(.top, 8)

                    // Incidents timeline (if any)
                    if !line.incidents.isEmpty {
                        incidentsSection
                    }

                    // Service info
                    serviceInfoSection

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
            }
            #if os(iOS)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    // MARK: - Compact Header

    private var compactHeader: some View {
        HStack(spacing: 16) {
            // Line badge - unified 48pt size
            lineBadgeView
                .frame(width: badgeSize, height: badgeSize)

            // Line info
            VStack(alignment: .leading, spacing: 4) {
                Text(line.lineName)
                    .font(.title2.weight(.semibold))

                // Status pill
                statusPill
            }

            Spacer()
        }
        .padding(16)
        .background(headerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lineName), \(line.status.rawValue)")
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
                    .fill(lineColor.gradient)

                Text(line.lineNumber)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: StatusColor.icon(for: line.status))
                .font(.caption.weight(.semibold))
                .symbolEffect(.pulse, options: .repeating, isActive: shouldPulse && !reduceMotion)

            Text(StatusColor.displayText(for: line.status))
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(MaterialOpacity.light), in: Capsule())
    }

    @ViewBuilder
    private var headerBackground: some View {
        if reduceTransparency {
            Color(white: colorScheme == .dark ? 0.15 : 0.95)
        } else if line.status.isNormal {
            LinearGradient(
                colors: [StatusColor.good.opacity(MaterialOpacity.light), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(.ultraThinMaterial)
        } else {
            LinearGradient(
                colors: [statusColor.opacity(MaterialOpacity.light), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Incidents Section

    private var incidentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(StatusColor.warning)
                Text(line.incidentCount == 1 ? "Incidente" : "\(line.incidentCount) incidentes")
                    .font(.headline)
            }

            // Compact timeline - incidents sorted by severity (most severe first)
            CompactStationTimeline(
                incidents: sortedIncidents,
                lineColor: lineColor
            )
        }
    }

    // MARK: - Service Info Section

    private var serviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Informacion")
                    .font(.headline)
            }

            // Info rows
            VStack(spacing: 0) {
                infoRow(
                    icon: "tram.fill",
                    label: "Sistema",
                    value: line.transportType.displayName
                )

                Divider().padding(.leading, 40)

                infoRow(
                    icon: "number",
                    label: "Linea",
                    value: line.lineNumber
                )

                Divider().padding(.leading, 40)

                infoRow(
                    icon: StatusColor.icon(for: line.status),
                    iconColor: statusColor,
                    label: "Estado",
                    value: line.status.rawValue
                )

                if !line.affectedStations.isEmpty {
                    Divider().padding(.leading, 40)

                    infoRow(
                        icon: "mappin.and.ellipse",
                        iconColor: StatusColor.warning,
                        label: "Afectadas",
                        value: "\(line.affectedStations.count) estacion\(line.affectedStations.count == 1 ? "" : "es")"
                    )
                }
            }
            .background(
                reduceTransparency
                    ? AnyShapeStyle(Color(white: colorScheme == .dark ? 0.15 : 0.92))
                    : AnyShapeStyle(Color.secondary.opacity(MaterialOpacity.subtle)),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
    }

    private func infoRow(
        icon: String,
        iconColor: Color = .secondary,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(label)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
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
