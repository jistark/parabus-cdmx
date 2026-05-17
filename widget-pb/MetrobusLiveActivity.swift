import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

@available(iOS 16.2, *)
struct MetrobusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MetrobusDisruptionAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(context.state.statusColor.opacity(0.2))
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (when long-pressed)
                DynamicIslandExpandedRegion(.leading) {
                    LineBadgeView(lineNumber: context.attributes.lineNumber)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    StatusBadgeView(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.lineName)
                        .font(.custom("TipoMovinCDMX-Bold", size: 17, relativeTo: .headline))
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedContentView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }

            } compactLeading: {
                // Compact left side
                LineBadgeView(lineNumber: context.attributes.lineNumber, size: .compact)
            } compactTrailing: {
                // Compact right side
                HStack(spacing: 4) {
                    Image(systemName: context.state.statusIcon)
                        .foregroundStyle(context.state.statusColor)
                    Text(shortStatusText(for: context.state))
                        .font(.caption2.weight(.medium))
                }
            } minimal: {
                // Minimal view (when multiple activities)
                ZStack {
                    Circle()
                        .fill(WidgetLineColor.color(for: context.attributes.lineNumber))
                    Text(context.attributes.lineNumber)
                        .font(.custom("TipoMovinCDMX-Bold", size: 11, relativeTo: .caption2))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
            .keylineTint(context.state.statusColor)
        }
    }

    /// Compact pill labels. Severity mapping mirrors `ServiceStatus.severity`
    /// (post REVIEW HIGH-17). Long forms in `StatusPill.statusText` below.
    private func shortStatusText(for state: MetrobusDisruptionAttributes.ContentState) -> String {
        switch state.statusSeverity {
        case 6: return "Marcha"
        case 5: return "Susp."
        case 4: return "Retraso"
        case 3: return "Lim."
        case 2: return "Obra"
        default: return "OK"
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let attributes: MetrobusDisruptionAttributes
    let state: MetrobusDisruptionAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            // Line badge
            LineBadgeView(lineNumber: attributes.lineNumber, size: .large)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Line name + status
                HStack {
                    Text(attributes.lineName)
                        .font(.custom("TipoMovinCDMX-Bold", size: 17, relativeTo: .headline))

                    Spacer()

                    StatusPill(state: state)
                }

                // Affected stations
                if !state.affectedStations.isEmpty {
                    Text(stationsText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Additional info
                if let info = state.additionalInfo, !info.isEmpty {
                    Text(info)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                // Time indicators
                HStack {
                    Label {
                        Text(attributes.startedAt, style: .relative)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("Act. \(state.updatedAt, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var stationsText: String {
        if state.affectedStations.count == 1 {
            return state.affectedStations[0]
        } else {
            return state.affectedStations.joined(separator: ", ")
        }
    }

    private var accessibilityText: String {
        var text = "\(attributes.lineName), \(state.status)"
        if !state.affectedStations.isEmpty {
            text += ". Estaciones afectadas: \(stationsText)"
        }
        return text
    }
}

// MARK: - Expanded Dynamic Island Content

@available(iOS 16.2, *)
struct ExpandedContentView: View {
    let attributes: MetrobusDisruptionAttributes
    let state: MetrobusDisruptionAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Affected stations
            if !state.affectedStations.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(state.affectedStations.joined(separator: ", "))
                        .font(.caption)
                        .lineLimit(2)
                }
            }

            // Duration and update time
            HStack {
                Label {
                    Text(attributes.startedAt, style: .relative)
                } icon: {
                    Image(systemName: "hourglass")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer()

                if let info = state.additionalInfo {
                    Text(info)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct LineBadgeView: View {
    let lineNumber: String
    var size: BadgeSize = .regular

    enum BadgeSize {
        case compact, regular, large

        var dimension: CGFloat {
            switch self {
            case .compact: return 24
            case .regular: return 32
            case .large: return 44
            }
        }

        /// Tipo Movin CDMX Bold, scaled relative to the system text style most
        /// appropriate for the badge size. Custom font registered via
        /// UIAppFonts in widget-pb/Info.plist.
        var font: Font {
            switch self {
            case .compact: return .custom("TipoMovinCDMX-Bold", size: 11, relativeTo: .caption2)
            case .regular: return .custom("TipoMovinCDMX-Bold", size: 13, relativeTo: .caption)
            case .large:   return .custom("TipoMovinCDMX-Bold", size: 17, relativeTo: .headline)
            }
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(WidgetLineColor.color(for: lineNumber).gradient)
                .frame(width: size.dimension, height: size.dimension)

            Text(lineNumber)
                .font(size.font)
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .accessibilityLabel("Línea \(lineNumber)")
    }
}

@available(iOS 16.2, *)
struct StatusBadgeView: View {
    let state: MetrobusDisruptionAttributes.ContentState

    var body: some View {
        Image(systemName: state.statusIcon)
            .font(.title3.weight(.semibold))
            .foregroundStyle(state.statusColor)
            .symbolEffect(.pulse, options: .repeating, isActive: state.statusSeverity >= 4)
    }
}

@available(iOS 16.2, *)
struct StatusPill: View {
    let state: MetrobusDisruptionAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.statusIcon)
                .font(.caption2.weight(.semibold))

            Text(statusText)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(state.statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(state.statusColor.opacity(0.15), in: Capsule())
    }

    private var statusText: String {
        switch state.statusSeverity {
        case 6: return "Manifestación"
        case 5: return "Suspendido"
        case 4: return "Con retraso"
        case 3: return "Servicio limitado"
        case 2: return "Intervención"
        default: return "Normal"
        }
    }
}

// MARK: - Previews

@available(iOS 16.2, *)
#Preview("Lock Screen", as: .content, using: MetrobusDisruptionAttributes(
    lineNumber: "2",
    lineName: "Linea 2",
    startedAt: Date().addingTimeInterval(-1800)
)) {
    MetrobusLiveActivity()
} contentStates: {
    MetrobusDisruptionAttributes.ContentState(
        status: "Intervencion en la estacion",
        statusSeverity: 3,
        affectedStations: ["La Joya", "Iztacalco"],
        additionalInfo: "Por mantenimiento",
        updatedAt: Date()
    )
}

@available(iOS 16.2, *)
#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: MetrobusDisruptionAttributes(
    lineNumber: "4",
    lineName: "Linea 4",
    startedAt: Date().addingTimeInterval(-3600)
)) {
    MetrobusLiveActivity()
} contentStates: {
    MetrobusDisruptionAttributes.ContentState(
        status: "Servicio Suspendido",
        statusSeverity: 4,
        affectedStations: ["Buenavista"],
        additionalInfo: nil,
        updatedAt: Date()
    )
}

@available(iOS 16.2, *)
#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: MetrobusDisruptionAttributes(
    lineNumber: "1",
    lineName: "Linea 1",
    startedAt: Date().addingTimeInterval(-900)
)) {
    MetrobusLiveActivity()
} contentStates: {
    MetrobusDisruptionAttributes.ContentState(
        status: "Servicio con Retraso",
        statusSeverity: 2,
        affectedStations: ["Indios Verdes", "Potrero", "La Raza"],
        additionalInfo: "Alta afluencia de usuarios",
        updatedAt: Date()
    )
}
