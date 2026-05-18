import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget
//
// Surfaces an active Metrobús disruption as a Lock Screen banner + Dynamic
// Island. Severity is propagated via `state.statusSeverity` (0-6, mirrors
// ServiceStatus.severity in the main app — see Shared/LiveActivityTypes.swift).

@available(iOS 16.2, *)
struct MetrobusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MetrobusDisruptionAttributes.self) { context in
            LockScreenLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(context.state.statusColor.opacity(0.12))
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    WidgetLineBadge(lineNumber: context.attributes.lineNumber, size: .regular)
                        .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    expandedStatusBadge(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.lineName)
                        .font(.custom("TipoMovinCDMX-Bold", size: 15, relativeTo: .subheadline))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedContentView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }

            } compactLeading: {
                WidgetLineBadge(lineNumber: context.attributes.lineNumber, size: .mini)
            } compactTrailing: {
                HStack(spacing: 3) {
                    Image(systemName: context.state.statusIcon)
                        .foregroundStyle(context.state.statusColor)
                    Text(shortStatusText(for: context.state))
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                }
            } minimal: {
                // Most compact form — just a tiny B with the line number
                WidgetLineBadge(lineNumber: context.attributes.lineNumber, size: .mini)
            }
            .keylineTint(context.state.statusColor)
        }
    }

    @available(iOS 16.2, *)
    private func expandedStatusBadge(state: MetrobusDisruptionAttributes.ContentState) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: state.statusIcon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(state.statusColor)
                .symbolEffect(.pulse, options: .repeating, isActive: state.statusSeverity >= 5)
            Text(shortStatusText(for: state))
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(state.statusColor)
        }
        .padding(.trailing, 4)
    }

    /// Mirrors ServiceStatus.severity in the main app:
    /// protest=6 > suspended=5 > delayed=4 > limited=3 > intervention=2
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

// MARK: - Lock Screen / Banner View

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let attributes: MetrobusDisruptionAttributes
    let state: MetrobusDisruptionAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            WidgetLineBadge(lineNumber: attributes.lineNumber, size: .large)

            VStack(alignment: .leading, spacing: 6) {
                // Header: line name + status pill
                HStack(alignment: .firstTextBaseline) {
                    Text(attributes.lineName)
                        .font(.custom("TipoMovinCDMX-Bold", size: 17, relativeTo: .headline))
                        .textCase(.uppercase)
                        .lineLimit(1)

                    Spacer()

                    StatusBadge(state: state)
                }

                // Affected stations
                if !state.affectedStations.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(state.statusColor)
                        Text(stationsText)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                }

                // Additional info (e.g., reason)
                if let info = state.additionalInfo, !info.isEmpty {
                    Text(info)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Footer: timing
                HStack {
                    Label {
                        Text(attributes.startedAt, style: .relative)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("Act. \(state.updatedAt, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
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
        }
        return state.affectedStations.joined(separator: ", ")
    }

    private var accessibilityText: String {
        var text = "\(attributes.lineName), \(state.status)"
        if !state.affectedStations.isEmpty {
            text += ". Estaciones afectadas: \(stationsText)"
        }
        if let info = state.additionalInfo, !info.isEmpty {
            text += ". \(info)"
        }
        return text
    }
}

// MARK: - Expanded Dynamic Island Bottom

@available(iOS 16.2, *)
struct ExpandedContentView: View {
    let attributes: MetrobusDisruptionAttributes
    let state: MetrobusDisruptionAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            HStack {
                Label {
                    Text(attributes.startedAt, style: .relative)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "hourglass")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer()

                if let info = state.additionalInfo, !info.isEmpty {
                    Text(info)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Status Badge (compact pill for the lock-screen header)

@available(iOS 16.2, *)
struct StatusBadge: View {
    let state: MetrobusDisruptionAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.statusIcon)
                .font(.caption2.weight(.bold))
                .symbolEffect(.pulse, options: .repeating, isActive: state.statusSeverity >= 5)

            Text(statusText)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
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
#Preview("Lock Screen — Suspended", as: .content, using: MetrobusDisruptionAttributes(
    lineNumber: "1",
    lineName: "Línea 1",
    startedAt: Date().addingTimeInterval(-1800)
)) {
    MetrobusLiveActivity()
} contentStates: {
    MetrobusDisruptionAttributes.ContentState(
        status: "Servicio Suspendido",
        statusSeverity: 5,
        affectedStations: ["Indios Verdes", "Potrero", "La Raza"],
        additionalInfo: "Por concentración política",
        updatedAt: Date()
    )
}

@available(iOS 16.2, *)
#Preview("Lock Screen — Protest", as: .content, using: MetrobusDisruptionAttributes(
    lineNumber: "4",
    lineName: "Línea 4",
    startedAt: Date().addingTimeInterval(-600)
)) {
    MetrobusLiveActivity()
} contentStates: {
    MetrobusDisruptionAttributes.ContentState(
        status: "Manifestación",
        statusSeverity: 6,
        affectedStations: ["San Lázaro"],
        additionalInfo: "Marcha rumbo al Zócalo",
        updatedAt: Date()
    )
}

@available(iOS 16.2, *)
#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: MetrobusDisruptionAttributes(
    lineNumber: "4",
    lineName: "Línea 4",
    startedAt: Date().addingTimeInterval(-3600)
)) {
    MetrobusLiveActivity()
} contentStates: {
    MetrobusDisruptionAttributes.ContentState(
        status: "Servicio Suspendido",
        statusSeverity: 5,
        affectedStations: ["Buenavista"],
        additionalInfo: nil,
        updatedAt: Date()
    )
}

@available(iOS 16.2, *)
#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: MetrobusDisruptionAttributes(
    lineNumber: "1",
    lineName: "Línea 1",
    startedAt: Date().addingTimeInterval(-900)
)) {
    MetrobusLiveActivity()
} contentStates: {
    MetrobusDisruptionAttributes.ContentState(
        status: "Servicio con Retraso",
        statusSeverity: 4,
        affectedStations: ["Indios Verdes", "Potrero", "La Raza"],
        additionalInfo: "Alta afluencia de usuarios",
        updatedAt: Date()
    )
}

@available(iOS 16.2, *)
#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: MetrobusDisruptionAttributes(
    lineNumber: "7",
    lineName: "Línea 7",
    startedAt: Date()
)) {
    MetrobusLiveActivity()
} contentStates: {
    MetrobusDisruptionAttributes.ContentState(
        status: "Servicio Limitado",
        statusSeverity: 3,
        affectedStations: ["Etiopía"],
        additionalInfo: nil,
        updatedAt: Date()
    )
}
