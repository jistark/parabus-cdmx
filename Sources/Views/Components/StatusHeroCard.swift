import SwiftUI

/// Hero card showing overall system status - Apple Maps style
struct StatusHeroCard: View {
    let lines: [LineStatus]
    let lastUpdated: Date?
    let onRefresh: () async -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isRefreshing = false

    // Dynamic Type support
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = BadgeSize.large.dimension
    @ScaledMetric(relativeTo: .body) private var refreshButtonSize: CGFloat = 44

    private var linesWithIssues: [LineStatus] {
        lines.filter { $0.hasIssues }
    }

    private var allClear: Bool {
        linesWithIssues.isEmpty
    }

    private var totalIncidents: Int {
        linesWithIssues.reduce(0) { $0 + max(1, $1.incidentCount) }
    }

    private var statusColor: Color {
        if allClear {
            return StatusColor.good
        } else if linesWithIssues.contains(where: { $0.status == .suspended }) {
            return StatusColor.alert
        } else {
            return StatusColor.warning
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main status area
            HStack(spacing: 16) {
                // Status icon - large and prominent
                statusIcon
                    .frame(width: iconSize, height: iconSize)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Refresh button
                Button {
                    Task {
                        isRefreshing = true
                        await onRefresh()
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: refreshButtonSize, height: refreshButtonSize)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .rotationEffect(.degrees(isRefreshing && !reduceMotion ? 360 : 0))
                .animation(
                    isRefreshing && !reduceMotion
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: isRefreshing
                )
                .accessibilityLabel("Actualizar")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Last updated footer
            if let lastUpdated {
                Divider()
                    .padding(.horizontal, 16)

                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Actualizado \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
                .padding(.vertical, 10)
            }
        }
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusTitle). \(statusSubtitle)")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(MaterialOpacity.medium))

            Circle()
                .strokeBorder(statusColor.opacity(MaterialOpacity.border), lineWidth: 2)

            Image(systemName: statusIconName)
                .font(.title.weight(.semibold))
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, options: .repeating, isActive: !allClear && !reduceMotion)
        }
    }

    private var statusIconName: String {
        if allClear {
            return "checkmark.circle.fill"
        } else if linesWithIssues.contains(where: { $0.status == .suspended }) {
            return "exclamationmark.triangle.fill"
        } else {
            return "info.circle.fill"
        }
    }

    // MARK: - Status Text

    private var statusTitle: String {
        if allClear {
            return "Todo en orden"
        } else if linesWithIssues.count == 1 {
            return "1 linea afectada"
        } else {
            return "\(linesWithIssues.count) lineas afectadas"
        }
    }

    private var statusSubtitle: String {
        if allClear {
            return "Todas las lineas operando normal"
        } else if totalIncidents == 1 {
            return "1 incidente activo"
        } else {
            return "\(totalIncidents) incidentes activos"
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var heroBackground: some View {
        if reduceTransparency {
            // Solid background for reduced transparency
            Color(white: colorScheme == .dark ? 0.15 : 0.95)
        } else {
            LinearGradient(
                colors: [
                    statusColor.opacity(MaterialOpacity.light),
                    statusColor.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(.ultraThinMaterial)
        }
    }
}

#Preview("All Clear") {
    StatusHeroCard(
        lines: [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular, affectedStations: []),
            LineStatus(lineNumber: "2", transportType: .metrobus, status: .regular, affectedStations: [])
        ],
        lastUpdated: Date(),
        onRefresh: {}
    )
    .padding()
}

#Preview("With Issues") {
    StatusHeroCard(
        lines: [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .intervention, affectedStations: ["Indios Verdes"]),
            LineStatus(lineNumber: "2", transportType: .metrobus, status: .suspended, affectedStations: ["La Joya"]),
            LineStatus(lineNumber: "3", transportType: .metrobus, status: .regular, affectedStations: [])
        ],
        lastUpdated: Date().addingTimeInterval(-300),
        onRefresh: {}
    )
    .padding()
}

#Preview("Large Text") {
    StatusHeroCard(
        lines: [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .intervention, affectedStations: ["Buenavista"])
        ],
        lastUpdated: Date(),
        onRefresh: {}
    )
    .padding()
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}

#Preview("Dark Mode") {
    StatusHeroCard(
        lines: [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .intervention, affectedStations: ["Buenavista"])
        ],
        lastUpdated: Date(),
        onRefresh: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
