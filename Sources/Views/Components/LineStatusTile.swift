import SwiftUI

/// Grid tile for a single line - Apple Maps style
struct LineStatusTile: View {
    let line: LineStatus
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = BadgeSize.regular.dimension
    @ScaledMetric(relativeTo: .caption2) private var dotSize: CGFloat = 8

    private var statusColor: Color {
        StatusColor.color(for: line.status)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Line badge - prominent
                lineBadgeView
                    .frame(width: badgeSize, height: badgeSize)

                // Line name
                Text("Linea \(line.lineNumber)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Status indicator
                statusPill
            }
            .frame(maxWidth: .infinity, minHeight: 100) // Garantizar altura minima
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: line.hasIssues ? 1.5 : 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16)) // Area tactil completa
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(line.lineName), \(line.status.rawValue)")
        .accessibilityHint(line.hasIssues ? "Toca para ver detalles" : "Buen servicio")
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
                    .fill(LineColor.color(for: line.lineNumber).gradient)

                Text(line.lineNumber)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Status Pill

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: dotSize, height: dotSize)

            Text(statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(MaterialOpacity.light), in: Capsule())
    }

    private var statusText: String {
        if line.incidentCount > 1 {
            return "\(line.incidentCount) inc."
        }
        return StatusColor.shortText(for: line.status)
    }

    // MARK: - Background

    @ViewBuilder
    private var tileBackground: some View {
        if reduceTransparency {
            // Solid background for reduced transparency
            Color(white: colorScheme == .dark ? 0.15 : 0.95)
        } else if line.hasIssues {
            statusColor.opacity(MaterialOpacity.subtle)
                .background(.ultraThinMaterial)
        } else {
            Color.clear
                .background(.ultraThinMaterial)
        }
    }

    private var borderColor: Color {
        if line.hasIssues {
            return statusColor.opacity(MaterialOpacity.borderStrong)
        } else {
            return Color.secondary.opacity(MaterialOpacity.border)
        }
    }
}

// MARK: - Grid Layout Helper

struct LineStatusGrid: View {
    let lines: [LineStatus]
    let onTapLine: (LineStatus) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        // Adaptar columnas al size class
        let count = sizeClass == .regular ? 5 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(lines) { line in
                LineStatusTile(line: line) {
                    onTapLine(line)
                }
            }
        }
    }
}

#Preview("Grid") {
    ScrollView {
        LineStatusGrid(
            lines: [
                LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular, affectedStations: []),
                LineStatus(lineNumber: "2", transportType: .metrobus, status: .intervention, affectedStations: ["La Joya"]),
                LineStatus(lineNumber: "3", transportType: .metrobus, status: .regular, affectedStations: []),
                LineStatus(lineNumber: "4", transportType: .metrobus, status: .suspended, affectedStations: ["Buenavista"]),
                LineStatus(lineNumber: "5", transportType: .metrobus, status: .regular, affectedStations: []),
                LineStatus(lineNumber: "6", transportType: .metrobus, status: .delayed, affectedStations: ["Centro Medico"]),
                LineStatus(lineNumber: "7", transportType: .metrobus, status: .regular, affectedStations: [])
            ],
            onTapLine: { _ in }
        )
        .padding()
    }
}

#Preview("Large Text") {
    LineStatusGrid(
        lines: [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .intervention, affectedStations: ["Indios Verdes"]),
            LineStatus(lineNumber: "2", transportType: .metrobus, status: .regular, affectedStations: [])
        ],
        onTapLine: { _ in }
    )
    .padding()
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}

#Preview("Dark Mode") {
    LineStatusGrid(
        lines: [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .intervention, affectedStations: ["Indios Verdes"]),
            LineStatus(lineNumber: "2", transportType: .metrobus, status: .regular, affectedStations: []),
            LineStatus(lineNumber: "3", transportType: .metrobus, status: .suspended, affectedStations: ["Etiopia"]),
            LineStatus(lineNumber: "4", transportType: .metrobus, status: .regular, affectedStations: [])
        ],
        onTapLine: { _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
