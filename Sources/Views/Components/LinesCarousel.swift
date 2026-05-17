import SwiftUI

/// Horizontal scrolling carousel showing all lines
struct LinesCarousel: View {
    let lines: [LineStatus]
    let onSelect: (LineStatus) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sortedLines) { line in
                    LineCarouselCard(line: line)
                        .onTapGesture {
                            onSelect(line)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
    }

    private var sortedLines: [LineStatus] {
        lines.sorted {
            let num1 = Int($0.lineNumber) ?? 99
            let num2 = Int($1.lineNumber) ?? 99
            return num1 < num2
        }
    }
}

// MARK: - Line Carousel Card

struct LineCarouselCard: View {
    let line: LineStatus

    var body: some View {
        VStack(spacing: Spacing.xs) {
            // Line badge with status indicator overlay
            ZStack(alignment: .bottomTrailing) {
                LineBadge(number: line.lineNumber, transportType: line.transportType, size: .large)
                    .shadow(color: lineColor.opacity(0.3), radius: 4, y: 2)

                if line.hasIssues {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Image(systemName: statusIcon)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 4, y: 4)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Status text
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(line.hasIssues ? statusColor : .secondary)
                .lineLimit(1)
        }
        .frame(width: 70)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Línea \(line.lineNumber), \(statusText)")
        .accessibilityAddTraits(line.hasIssues ? .updatesFrequently : [])
    }

    private var lineColor: Color {
        LineColors.color(for: line.lineNumber)
    }

    private var statusColor: Color {
        StatusColors.color(for: line.status)
    }

    /// Simplified glyphs that render legibly at 20×20.
    /// Differs from `StatusColors.icon(for:)` (full-color symbols) because
    /// these go inside a tiny solid-color circle — we need stroke-only or
    /// minimal-fill variants to keep white-on-color contrast.
    private var statusIcon: String {
        switch line.status {
        case .regular: return "checkmark"
        case .intervention: return "wrench.fill"
        case .limited: return "arrow.left.arrow.right"
        case .delayed: return "clock.fill"
        case .suspended: return "xmark"
        case .protest: return "megaphone.fill"
        case .unknown: return "questionmark"
        }
    }

    private var statusText: String {
        if !line.hasIssues {
            return "Normal"
        }
        switch line.status {
        case .regular: return "Buen servicio"
        case .intervention: return "Obras"
        case .limited: return "Limitado"
        case .delayed: return "Retrasos"
        case .suspended: return "Suspendida"
        case .protest: return "Protestas"
        case .unknown: return "Otra"
        }
    }
}

// MARK: - Preview

#Preview("Lines Carousel") {
    VStack {
        LinesCarousel(
            lines: [
                LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular),
                LineStatus(lineNumber: "2", transportType: .metrobus, status: .intervention, affectedStations: ["Iztacalco"]),
                LineStatus(lineNumber: "3", transportType: .metrobus, status: .regular),
                LineStatus(lineNumber: "4", transportType: .metrobus, status: .delayed, affectedStations: ["Buenavista"]),
                LineStatus(lineNumber: "5", transportType: .metrobus, status: .regular),
                LineStatus(lineNumber: "6", transportType: .metrobus, status: .suspended, affectedStations: ["Aragon"]),
                LineStatus(lineNumber: "7", transportType: .metrobus, status: .regular),
            ],
            onSelect: { _ in }
        )
    }
    .padding(.vertical)
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}
