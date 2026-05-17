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
        .configurationDisplayName("Estado Metrobus")
        .description("Estado actual de las lineas del Metrobus CDMX")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Views

struct MetrobusStatusWidgetView: View {
    let entry: MetrobusStatusEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status icon and count
            HStack(spacing: 8) {
                Image(systemName: data.worstStatus.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(data.worstStatus.color)

                Spacer()

                if !data.allClear {
                    Text("\(data.affectedLinesCount)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(data.worstStatus.color)
                }
            }

            Spacer()

            // Status text
            Text(statusTitle)
                .font(.headline)
                .lineLimit(2)

            // Subtitle
            Text(statusSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Last updated
            Text(data.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }

    private var statusTitle: String {
        if data.allClear {
            return "Todo en orden"
        } else if data.affectedLinesCount == 1 {
            return "1 linea afectada"
        } else {
            return "\(data.affectedLinesCount) lineas"
        }
    }

    private var statusSubtitle: String {
        if data.allClear {
            return "Servicio normal"
        } else {
            let worst = data.worstStatus
            return worst.displayText
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let data: WidgetData

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Metrobus CDMX")
                    .font(.headline)

                Spacer()

                if data.isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                Text(data.updatedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Line grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(sortedLines) { line in
                    LineStatusBadge(line: line)
                }
            }

            // Summary
            HStack {
                if data.allClear {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Todas las lineas operando normal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: data.worstStatus.icon)
                        .foregroundStyle(data.worstStatus.color)
                    Text("\(data.affectedLinesCount) linea\(data.affectedLinesCount == 1 ? "" : "s") con incidentes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var sortedLines: [WidgetLineStatus] {
        data.lines.sorted { line1, line2 in
            let num1 = Int(line1.lineNumber) ?? 99
            let num2 = Int(line2.lineNumber) ?? 99
            return num1 < num2
        }
    }

    private var accessibilityDescription: String {
        if data.allClear {
            return "Metrobus CDMX. Todas las lineas operando normal."
        } else {
            let affected = data.linesWithIssues.map { "Linea \($0.lineNumber)" }.joined(separator: ", ")
            return "Metrobus CDMX. \(data.affectedLinesCount) lineas con incidentes: \(affected)"
        }
    }
}

// MARK: - Line Status Badge

struct LineStatusBadge: View {
    let line: WidgetLineStatus

    var body: some View {
        VStack(spacing: 4) {
            // Line number circle - simplified without gradient for memory efficiency
            ZStack {
                Circle()
                    .fill(lineColor)
                    .frame(width: 32, height: 32)

                Text(line.lineNumber)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            // Status indicator
            Image(systemName: line.status.icon)
                .font(.caption2)
                .foregroundStyle(line.status.color)
        }
    }

    private var lineColor: Color {
        switch line.lineNumber {
        case "1": return Color(red: 0.83, green: 0.18, blue: 0.18)
        case "2": return Color(red: 0.48, green: 0.18, blue: 0.56)
        case "3": return Color(red: 0.13, green: 0.55, blue: 0.13)
        case "4": return Color(red: 0.96, green: 0.65, blue: 0.14)
        case "5": return Color(red: 0.00, green: 0.48, blue: 0.65)
        case "6": return Color(red: 0.80, green: 0.00, blue: 0.47)
        case "7": return Color(red: 0.00, green: 0.60, blue: 0.40)
        default: return .gray
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: false)
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: [
            WidgetLineStatus(id: "1", lineNumber: "1", status: .regular, affectedStationsCount: 0, incidentCount: 0),
            WidgetLineStatus(id: "2", lineNumber: "2", status: .intervention, affectedStationsCount: 2, incidentCount: 1),
            WidgetLineStatus(id: "3", lineNumber: "3", status: .regular, affectedStationsCount: 0, incidentCount: 0),
            WidgetLineStatus(id: "4", lineNumber: "4", status: .suspended, affectedStationsCount: 1, incidentCount: 1),
        ],
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Medium", as: .systemMedium) {
    MetrobusStatusWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: (1...7).map { num in
            WidgetLineStatus(
                id: "\(num)",
                lineNumber: "\(num)",
                status: num == 2 ? .intervention : (num == 4 ? .suspended : .regular),
                affectedStationsCount: num == 2 ? 2 : (num == 4 ? 1 : 0),
                incidentCount: (num == 2 || num == 4) ? 1 : 0
            )
        },
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}
