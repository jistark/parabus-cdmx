import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MetrobusStatusProvider: TimelineProvider {
    typealias Entry = MetrobusStatusEntry

    func placeholder(in context: Context) -> MetrobusStatusEntry {
        MetrobusStatusEntry(date: Date(), data: .placeholder, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (MetrobusStatusEntry) -> Void) {
        let data = WidgetCacheReader.load() ?? .placeholder
        let entry = MetrobusStatusEntry(date: Date(), data: data, isPlaceholder: context.isPreview)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetrobusStatusEntry>) -> Void) {
        let currentDate = Date()
        let data = WidgetCacheReader.load() ?? .placeholder

        // Refresh every 15 minutes normally, 5 minutes if stale
        let refreshInterval: TimeInterval = data.isStale ? 5 * 60 : 15 * 60
        let nextRefresh = currentDate.addingTimeInterval(refreshInterval)

        let entry = MetrobusStatusEntry(date: currentDate, data: data, isPlaceholder: false)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct MetrobusStatusEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
    let isPlaceholder: Bool
}

// MARK: - Widget Definition

struct MetrobusStatusWidget: Widget {
    let kind: String = ParabusConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetrobusStatusProvider()) { entry in
            MetrobusStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Estado Metrobús")
        .description("Estado actual de las líneas del Metrobús CDMX")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Router

struct MetrobusStatusWidgetView: View {
    let entry: MetrobusStatusEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if entry.isPlaceholder {
                SkeletonView(family: family)
            } else if entry.data.allClear {
                AllClearView(data: entry.data, family: family)
            } else {
                ActiveIncidentsView(data: entry.data, family: family)
            }
        }
    }
}

// MARK: - Header (shared across all states)

private struct WidgetHeader: View {
    let updatedAt: Date
    let isStale: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Metrobús")
                .font(.custom("TipoMovinCDMX-Bold", size: 14, relativeTo: .footnote))
                .textCase(.uppercase)

            if isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Datos desactualizados")
            }

            Spacer()

            Text(updatedAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - All Clear State

private struct AllClearView: View {
    let data: WidgetData
    let family: WidgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(updatedAt: data.updatedAt, isStale: data.isStale)
            Spacer()
            WidgetHeroStatus(
                icon: "checkmark.circle.fill",
                title: "Todo en orden",
                subtitle: family == .systemSmall
                    ? "\(data.lines.count) líneas operando"
                    : "\(data.lines.count) líneas operando normal",
                tint: .green
            )
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Metrobús. Todas las líneas operando normal. Actualizado \(data.updatedAt.formatted(date: .omitted, time: .shortened))")
    }
}

// MARK: - Active Incidents State

private struct ActiveIncidentsView: View {
    let data: WidgetData
    let family: WidgetFamily

    private var sortedIssues: [WidgetLineStatus] {
        data.linesWithIssues.sorted { $0.status.severity > $1.status.severity }
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    // MARK: Small — hero of worst affected line

    private var smallLayout: some View {
        let worst = sortedIssues.first
        let extraCount = max(0, sortedIssues.count - 1)
        return VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(updatedAt: data.updatedAt, isStale: data.isStale)

            Spacer(minLength: 0)

            if let worst {
                HStack {
                    Spacer()
                    WidgetLineBadge(lineNumber: worst.lineNumber, size: .large)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(worst.status.shortText)
                        .font(.custom("TipoMovinCDMX-Bold", size: 15, relativeTo: .subheadline))
                        .textCase(.uppercase)
                        .foregroundStyle(worst.status.color)
                        .widgetAccentable()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if extraCount > 0 {
                        Text("+ \(extraCount) línea\(extraCount == 1 ? "" : "s") más")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Línea \(worst.lineNumber)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(smallAccessibilityLabel)
    }

    private var smallAccessibilityLabel: String {
        guard let worst = sortedIssues.first else { return "Metrobús sin datos" }
        let extra = max(0, sortedIssues.count - 1)
        let extraText = extra > 0 ? ". Y \(extra) línea\(extra == 1 ? "" : "s") más con incidentes" : ""
        return "Metrobús. Línea \(worst.lineNumber) \(worst.status.displayText)\(extraText)"
    }

    // MARK: Medium — priority-sorted list of affected lines

    private var mediumLayout: some View {
        // Show up to 3 in the list; if there are more, show a "+N más" footer.
        let visible = Array(sortedIssues.prefix(3))
        let remainder = max(0, sortedIssues.count - visible.count)

        return VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(updatedAt: data.updatedAt, isStale: data.isStale)

            Divider()
                .padding(.vertical, 2)

            VStack(spacing: 4) {
                ForEach(visible) { line in
                    IncidentRow(line: line)
                }

                if remainder > 0 {
                    HStack {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("+ \(remainder) línea\(remainder == 1 ? "" : "s") más")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mediumAccessibilityLabel)
    }

    private var mediumAccessibilityLabel: String {
        let count = sortedIssues.count
        let summary = sortedIssues
            .prefix(3)
            .map { "Línea \($0.lineNumber) \($0.status.displayText)" }
            .joined(separator: ", ")
        let extra = max(0, count - 3)
        let extraText = extra > 0 ? ". Y \(extra) más" : ""
        return "Metrobús, \(count) líneas con incidentes: \(summary)\(extraText)"
    }
}

// MARK: - Single Incident Row

private struct IncidentRow: View {
    let line: WidgetLineStatus

    var body: some View {
        HStack(spacing: 10) {
            WidgetLineBadge(lineNumber: line.lineNumber, size: .small)

            Text("Línea \(line.lineNumber)")
                .font(.custom("TipoMovinCDMX-Bold", size: 14, relativeTo: .footnote))
                .textCase(.uppercase)
                .lineLimit(1)

            Spacer(minLength: 4)

            WidgetStatusPill(status: line.status)
        }
    }
}

// MARK: - Skeleton (loading)

private struct SkeletonView: View {
    let family: WidgetFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header skeleton
            HStack {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 70, height: 12)
                Spacer()
                Capsule()
                    .fill(Color.secondary.opacity(0.20))
                    .frame(width: 36, height: 10)
            }

            Spacer(minLength: 0)

            switch family {
            case .systemSmall:
                HStack {
                    Spacer()
                    WidgetBadgeSkeleton(size: .large)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(Color.secondary.opacity(0.25)).frame(width: 100, height: 12)
                    Capsule().fill(Color.secondary.opacity(0.20)).frame(width: 70, height: 10)
                }
            case .systemMedium:
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 10) {
                            WidgetBadgeSkeleton(size: .small)
                            Capsule().fill(Color.secondary.opacity(0.25)).frame(width: 80, height: 12)
                            Spacer()
                            Capsule().fill(Color.secondary.opacity(0.20)).frame(width: 50, height: 16)
                        }
                    }
                }
            default:
                EmptyView()
            }

            Spacer(minLength: 0)
        }
        .accessibilityLabel("Cargando estado del Metrobús")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Previews

#Preview("Small — All Clear", as: .systemSmall) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: false)
}

#Preview("Small — One Incident", as: .systemSmall) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: [
            WidgetLineStatus(id: "1", lineNumber: "1", status: .suspended, affectedStationsCount: 3, incidentCount: 1),
            WidgetLineStatus(id: "2", lineNumber: "2", status: .regular, affectedStationsCount: 0, incidentCount: 0),
            WidgetLineStatus(id: "3", lineNumber: "3", status: .regular, affectedStationsCount: 0, incidentCount: 0),
        ],
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Small — Three Incidents", as: .systemSmall) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: (1...7).map { num in
            let status: WidgetServiceStatus = switch num {
            case 1: .suspended
            case 4: .protest
            case 7: .delayed
            default: .regular
            }
            return WidgetLineStatus(id: "\(num)", lineNumber: "\(num)", status: status,
                                    affectedStationsCount: status == .regular ? 0 : 2,
                                    incidentCount: status == .regular ? 0 : 1)
        },
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Small — Skeleton", as: .systemSmall) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: true)
}

#Preview("Medium — All Clear", as: .systemMedium) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: false)
}

#Preview("Medium — Three Incidents", as: .systemMedium) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: (1...7).map { num in
            let status: WidgetServiceStatus = switch num {
            case 1: .suspended
            case 4: .protest
            case 7: .delayed
            default: .regular
            }
            return WidgetLineStatus(id: "\(num)", lineNumber: "\(num)", status: status,
                                    affectedStationsCount: status == .regular ? 0 : 2,
                                    incidentCount: status == .regular ? 0 : 1)
        },
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Medium — Five Incidents", as: .systemMedium) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: (1...7).map { num in
            let status: WidgetServiceStatus = switch num {
            case 1: .protest
            case 2: .suspended
            case 3: .delayed
            case 4: .limited
            case 5: .intervention
            default: .regular
            }
            return WidgetLineStatus(id: "\(num)", lineNumber: "\(num)", status: status,
                                    affectedStationsCount: status == .regular ? 0 : 2,
                                    incidentCount: status == .regular ? 0 : 1)
        },
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Medium — Skeleton", as: .systemMedium) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: true)
}
