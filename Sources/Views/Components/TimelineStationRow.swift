import SwiftUI

/// Fila del timeline: columna de riel (línea + nodo) y detalle (nombre,
/// badges de correspondencia, "Estás aquí"). Vista tonta — todo viene del
/// planner salvo `isCurrent`, que es estado de runtime (ubicación).
struct TimelineStationRow: View {
    let item: TimelineStation
    let lineColor: Color
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            TimelineRail(
                color: lineColor,
                style: .solid,
                node: item.isTerminal ? .terminal : .regular,
                nodeTint: item.rowStatus.map(StatusColors.color(for:))
            )
            detail
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: Spacing.xs) {
                Text(item.station.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                if isCurrent {
                    Text("Estás aquí")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.5)))
                }
            }
            if !item.correspondences.isEmpty {
                correspondenceBadges
            }
            if let status = item.rowStatus {
                Text(status.displayName)
                    .font(.caption2)
                    .foregroundStyle(StatusColors.color(for: status))
            }
        }
    }

    private var correspondenceBadges: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(item.correspondences, id: \.self) { c in
                CorrespondenceBadge(correspondence: c)
            }
        }
        .accessibilityLabel(
            "Transbordos: " + item.correspondences
                .map { "\($0.system.displayName) \($0.line)" }.joined(separator: ", ")
        )
    }
}

// MARK: - Badge de correspondencia (pill estilo mockup)

struct CorrespondenceBadge: View {
    let correspondence: Correspondence
    @ScaledMetric(relativeTo: .caption2) private var badgeFontSize: CGFloat = 9

    var body: some View {
        Text(label)
            .font(.system(size: badgeFontSize, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(hexString: correspondence.brandColorHex) ?? .secondary,
                        in: RoundedRectangle(cornerRadius: 4))
            .lineLimit(1)
    }

    private var label: String {
        switch correspondence.system {
        case .metro: return "METRO L\(correspondence.line)"
        case .metrobus: return "MB LÍNEA \(correspondence.line)"
        case .suburbano: return "SUBURBANO"
        case .cablebus: return "CABLEBÚS L\(correspondence.line)"
        case .trolebus: return "TROLEBÚS L\(correspondence.line)"
        }
    }
}

// MARK: - Riel

/// Columna fija de 24pt: línea vertical continua o punteada + nodo.
/// Cada fila dibuja su propio segmento — sin overlays absolutos.
struct TimelineRail: View {
    enum LineStyle { case solid, dashed, none /* usado por LineTimelineView (tramo interrumpido) */ }
    enum Node { case regular, terminal, ghost /* usado por LineTimelineView (tramo interrumpido) */, none }

    let color: Color
    let style: LineStyle
    let node: Node
    var nodeTint: Color? = nil

    var body: some View {
        ZStack(alignment: .top) {
            if style != .none {
                RailLine(dashed: style == .dashed, color: color)
            }
            // centra el nodo en la franja del nombre (minHeight de fila)
            nodeView
                .frame(height: 44)
        }
        .frame(width: 24)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    /// Platform-adaptive "page/window background" fill for node interiors.
    /// Extracted here so `@ViewBuilder switch` (Swift 6) never nests `#if`.
    private var nodeFill: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    @ViewBuilder
    private var nodeView: some View {
        switch node {
        case .regular:
            Circle()
                .fill(nodeFill)
                .overlay(Circle().strokeBorder(nodeTint ?? color, lineWidth: 2.5))
                .frame(width: 12, height: 12)
        case .terminal:
            Circle()
                .fill(nodeFill)
                .overlay(Circle().strokeBorder(color, lineWidth: 3))
                .overlay(Circle().fill(color).frame(width: 5, height: 5))
                .frame(width: 18, height: 18)
        case .ghost:
            Circle().strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                .frame(width: 9, height: 9)
        case .none:
            EmptyView()
        }
    }
}

private struct RailLine: View {
    let dashed: Bool
    let color: Color

    var body: some View {
        // Ancho fijo de 24pt (lo impone TimelineRail) — centro constante en 12.
        // Canvas se ajusta al alto propuesto sin segunda pasada de layout.
        Canvas { ctx, size in
            var p = Path()
            p.move(to: CGPoint(x: 12, y: 0))
            p.addLine(to: CGPoint(x: 12, y: size.height))
            ctx.stroke(
                p,
                with: .color(dashed ? Color.secondary.opacity(0.45) : color),
                style: StrokeStyle(lineWidth: 3, dash: dashed ? [4, 5] : [])
            )
        }
    }
}

#Preview("Filas L1") {
    let l1 = MBRouteOrder.orderedStations(for: "1")
    let items = TimelinePlanner.resolve(stations: l1, incidents: [], reversed: false)
    return ScrollView {
        VStack(spacing: 0) {
            ForEach(items.prefix(10)) { item in
                if case .station(let s) = item {
                    TimelineStationRow(item: s, lineColor: LineColors.color(for: "1"),
                                       isCurrent: s.station.name == "Insurgentes")
                }
            }
        }
        .padding(.horizontal)
    }
}
