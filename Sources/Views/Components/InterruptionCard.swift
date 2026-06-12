import SwiftUI

// entre xxs(4) y xs(8): densidad de chips del mockup
private let chipSpacing: CGFloat = 6

/// Tarjeta de tramo suspendido del timeline (Figma "Vista interrupción").
/// Fondo OPACO a propósito: el material translúcido dejaba sangrar las filas
/// colapsadas como manchas ilegibles (iteración Figma 2026-06-12).
struct InterruptionCard: View {
    let segment: InterruptedSegment
    let lastUpdated: Date

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            header
            affectedSummary
            if !segment.alternatives.isEmpty {
                Text("QUÉ PUEDES HACER")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, Spacing.xxs)
                chips
            }
        }
        .padding(Layout.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium)
                .strokeBorder(StatusColors.critical, lineWidth: 2)
        )
        .accessibilityElement(children: .ignore)
        // Fase 2: cuando los chips sean tappables, cambiar a .contain y dar a
        // cada AlternativeChip su propio label + .accessibilityAddTraits(.isButton).
        .accessibilityLabel(accessibilitySummary)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
            Image(systemName: segment.incident.status.icon)
                .foregroundStyle(StatusColors.critical)
            Text(headerTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StatusColors.critical)
            Spacer(minLength: Spacing.xs)
            Text(RelativeAge.text(since: lastUpdated))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var headerTitle: String {
        segment.incident.status == .protest ? "MANIFESTACIÓN" : "SERVICIO INTERRUMPIDO"
    }

    private var affectedSummary: some View {
        let names = segment.stations.map(\.name)
        let range = names.count == 1
            ? names[0]
            : "\(names.first ?? "") – \(names.last ?? "")"
        let count = names.count == 1 ? "" : " (\(names.count) estaciones)"
        return Text("Sin servicio: \(Text(range).font(.caption.weight(.semibold)))\(count)")
            .font(.caption)
            .foregroundStyle(.primary)
    }

    private var chips: some View {
        let alts = segment.alternatives
        return VStack(alignment: .leading, spacing: chipSpacing) {
            HStack(spacing: chipSpacing) {
                ForEach(alts.prefix(2), id: \.self) { alt in
                    AlternativeChip(alternative: alt)
                }
            }
            if alts.count > 2 {
                AlternativeChip(alternative: alts[2])
            }
        }
    }

    private var cardBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #else
        Color.gray.opacity(0.12)
        #endif
    }

    private var accessibilitySummary: String {
        let stations = segment.stations.map(\.name).joined(separator: ", ")
        var parts = ["\(headerTitle.capitalized). Sin servicio: \(stations)."]
        for alt in segment.alternatives {
            switch alt {
            case .transfer(let c, let at):
                parts.append("Alternativa: \(c.system.displayName) línea \(c.line) en \(at.name).")
            case .walk(let minutes, let from, let to):
                parts.append("A pie desde \(from.name) hasta \(to.name): aproximadamente \(minutes) minutos.")
            }
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Chip

private struct AlternativeChip: View {
    let alternative: Alternative
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(textColor)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, chipSpacing)
        .background(baseColor.opacity(0.14), in: Capsule())
        // Hit target ≥44pt listo para fase 2 (chips tappables); hoy informativos.
        .contentShape(Capsule().inset(by: -10))
    }

    private var icon: String {
        switch alternative {
        case .transfer(let c, _):
            return c.system == .suburbano ? "tram.fill" : "train.side.front.car"
        case .walk:
            return "figure.walk.motion"
        }
    }

    private var label: String {
        switch alternative {
        case .transfer(let c, let at):
            let prefix = c.system == .metro ? "L\(c.line)" : "\(c.system.displayName) \(c.line)"
            return "\(prefix), \(at.name)"
        case .walk(let minutes, let from, _):
            return "A pie desde \(from.name): ~\(minutes) min"
        }
    }

    private var baseColor: Color {
        switch alternative {
        case .transfer(let c, _): return Color(hexString: c.brandColorHex) ?? .secondary
        case .walk: return .blue
        }
    }

    /// AA sobre el tinte al 14%: oscurece la marca en light, aclara en dark.
    /// (Iteración Figma: #E81F8C daba 2.7:1; mezclado al 35% con negro ≈ 5:1.)
    private var textColor: Color {
        colorScheme == .dark
            ? baseColor.mix(with: .white, by: 0.35)
            : baseColor.mix(with: .black, by: 0.35)
    }
}

// MARK: - Preview

#Preview("Interrupción L1") {
    let l1 = MBRouteOrder.orderedStations(for: "1")
    let incident = Incident(status: .suspended, affectedStations: ["Sonora - Chilpancingo"])
    let items = TimelinePlanner.resolve(stations: l1, incidents: [incident], reversed: false)
    let segment = items.compactMap {
        if case .interruptedSegment(let s) = $0 { return s } else { return nil }
    }.first!
    return InterruptionCard(segment: segment, lastUpdated: .now.addingTimeInterval(-720))
        .padding()
}
