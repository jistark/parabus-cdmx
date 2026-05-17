import SwiftUI

/// Compact detail sheet for a line
struct LineDetailSheet: View {
    let line: LineStatus
    @Environment(\.dismiss) private var dismiss
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

    // MARK: - Service Info Section

    private var serviceInfoSection: some View {
        VStack(alignment: .leading, spacing: Layout.inlineSpacing) {
            // Section header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Información")
                    .font(BrandTypography.lineLabel)
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
                    icon: StatusColors.icon(for: line.status),
                    iconColor: statusColor,
                    label: "Estado",
                    value: line.status.rawValue
                )

                if !line.affectedStations.isEmpty {
                    Divider().padding(.leading, 40)

                    infoRow(
                        icon: "mappin.and.ellipse",
                        iconColor: StatusColors.warning,
                        label: "Afectadas",
                        value: "\(line.affectedStations.count) estación\(line.affectedStations.count == 1 ? "" : "es")"
                    )
                }
            }
            .surface(.base, cornerRadius: Layout.cornerRadiusSmall + 4)
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
