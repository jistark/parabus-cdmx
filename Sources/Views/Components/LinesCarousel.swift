import SwiftUI

/// Horizontal scrolling carousel showing all lines
struct LinesCarousel: View {
    let lines: [LineStatus]
    /// Line number of the currently selected card (inline detail open on the
    /// home). When non-nil, the selected card gets a stroke + scale affordance
    /// and the rest dim so the selection pops. Defaults to nil so call sites
    /// without a selection model are unaffected.
    var selectedLineNumber: String? = nil
    let onSelect: (LineStatus) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sortedLines) { line in
                    LineCarouselCard(
                        line: line,
                        isSelected: line.lineNumber == selectedLineNumber,
                        isDimmed: selectedLineNumber != nil && line.lineNumber != selectedLineNumber
                    )
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
    /// Selected affordance: line-color stroke + slight scale (stroke only
    /// under Reduce Motion).
    var isSelected: Bool = false
    /// True for the non-selected cards while ANY selection is active, so the
    /// selected one pops (Figma focus behavior).
    var isDimmed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        // Selection stroke drawn slightly outside the card bounds so the
        // 70-pt layout (and inter-card spacing) never shifts; the carousel's
        // `.scrollClipDisabled()` keeps it from being clipped at the edges.
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(lineColor, lineWidth: 2)
                    .padding(-6)
            }
        }
        .scaleEffect(isSelected && !reduceMotion ? 1.05 : 1.0)
        .opacity(isDimmed ? 0.6 : 1.0)
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: isSelected
        )
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: isDimmed
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Línea \(line.lineNumber), \(statusText)")
        .accessibilityAddTraits(line.hasIssues ? .updatesFrequently : [])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        // "Aviso" — there IS an incident, we just couldn't bucket it.
        // The detail sheet shows the operator's words.
        case .unknown: return "Aviso"
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

#Preview("Selected Line") {
    VStack {
        LinesCarousel(
            lines: [
                LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular),
                LineStatus(lineNumber: "2", transportType: .metrobus, status: .intervention, affectedStations: ["Iztacalco"]),
                LineStatus(lineNumber: "3", transportType: .metrobus, status: .regular),
                LineStatus(lineNumber: "4", transportType: .metrobus, status: .delayed, affectedStations: ["Buenavista"]),
            ],
            selectedLineNumber: "4",
            onSelect: { _ in }
        )
    }
    .padding(.vertical)
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}
