import WidgetKit
import SwiftUI

// MARK: - Accessory Widget (Lock Screen)

struct MetrobusAccessoryWidget: Widget {
    let kind: String = ParabusConstants.accessoryWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetrobusStatusProvider()) { entry in
            MetrobusAccessoryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Metrobus")
        .description("Estado rapido del Metrobus")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Accessory View Router

struct MetrobusAccessoryView: View {
    let entry: MetrobusStatusEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularAccessoryView(data: entry.data)
        case .accessoryRectangular:
            RectangularAccessoryView(data: entry.data)
        case .accessoryInline:
            InlineAccessoryView(data: entry.data)
        default:
            CircularAccessoryView(data: entry.data)
        }
    }
}

// MARK: - Circular Accessory (Lock Screen circle)

struct CircularAccessoryView: View {
    let data: WidgetData

    var body: some View {
        ZStack {
            // Background ring showing status
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: data.worstStatus.icon)
                    .font(.title3.weight(.semibold))

                if !data.allClear {
                    Text("\(data.affectedLinesCount)")
                        .font(.caption2.weight(.bold))
                }
            }
        }
        .widgetAccentable()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if data.allClear {
            return "Metrobus: todo normal"
        } else {
            return "Metrobus: \(data.affectedLinesCount) lineas con incidentes"
        }
    }
}

// MARK: - Rectangular Accessory (Lock Screen rectangle)

struct RectangularAccessoryView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row
            HStack {
                Image(systemName: "bus.fill")
                    .font(.caption2)
                Text("Metrobus")
                    .font(.headline)

                Spacer()

                Image(systemName: data.worstStatus.icon)
                    .font(.caption)
            }

            // Status text
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Affected lines (if any)
            if !data.allClear {
                HStack(spacing: 4) {
                    ForEach(data.linesWithIssues.prefix(4)) { line in
                        Text("L\(line.lineNumber)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    }

                    if data.affectedLinesCount > 4 {
                        Text("+\(data.affectedLinesCount - 4)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var statusText: String {
        if data.allClear {
            return "Todas las lineas OK"
        } else {
            return "\(data.affectedLinesCount) linea\(data.affectedLinesCount == 1 ? "" : "s") afectada\(data.affectedLinesCount == 1 ? "" : "s")"
        }
    }

    private var accessibilityText: String {
        if data.allClear {
            return "Metrobus: todas las lineas operando normal"
        } else {
            let lines = data.linesWithIssues.map { "Linea \($0.lineNumber)" }.joined(separator: ", ")
            return "Metrobus: \(data.affectedLinesCount) lineas con incidentes. \(lines)"
        }
    }
}

// MARK: - Inline Accessory (Lock Screen single line)

struct InlineAccessoryView: View {
    let data: WidgetData

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bus.fill")

            if data.allClear {
                Text("Metrobus OK")
            } else {
                Text("MB: \(data.affectedLinesCount) incidente\(data.affectedLinesCount == 1 ? "" : "s")")
            }
        }
        .accessibilityLabel(data.allClear ? "Metrobus normal" : "Metrobus: \(data.affectedLinesCount) incidentes")
    }
}

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    MetrobusAccessoryWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: false)
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: [
            WidgetLineStatus(id: "2", lineNumber: "2", status: .intervention, affectedStationsCount: 2, incidentCount: 1),
            WidgetLineStatus(id: "4", lineNumber: "4", status: .suspended, affectedStationsCount: 1, incidentCount: 1),
        ],
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    MetrobusAccessoryWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: [
            WidgetLineStatus(id: "1", lineNumber: "1", status: .regular, affectedStationsCount: 0, incidentCount: 0),
            WidgetLineStatus(id: "2", lineNumber: "2", status: .intervention, affectedStationsCount: 2, incidentCount: 1),
            WidgetLineStatus(id: "3", lineNumber: "3", status: .limited, affectedStationsCount: 3, incidentCount: 1),
            WidgetLineStatus(id: "4", lineNumber: "4", status: .suspended, affectedStationsCount: 1, incidentCount: 1),
            WidgetLineStatus(id: "5", lineNumber: "5", status: .protest, affectedStationsCount: 4, incidentCount: 1),
        ],
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Inline", as: .accessoryInline) {
    MetrobusAccessoryWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: false)
}
