import WidgetKit
import SwiftUI

// MARK: - Accessory Widget (Lock Screen / StandBy / Wallpaper)
//
// Three sizes: circular (round badge), rectangular (one-line summary card),
// inline (single line of text). All three render in `.accented` mode under
// the lock-screen rendering pipeline, so we lean on SF Symbols + Tipo Movin
// text and let SwiftUI handle the wallpaper-aware tinting.

struct MetrobusAccessoryWidget: Widget {
    let kind: String = ParabusConstants.accessoryWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetrobusStatusProvider()) { entry in
            MetrobusAccessoryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Metrobús")
        .description("Estado rápido del Metrobús")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Router

struct MetrobusAccessoryView: View {
    let entry: MetrobusStatusEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:    CircularAccessoryView(data: entry.data)
        case .accessoryRectangular: RectangularAccessoryView(data: entry.data)
        case .accessoryInline:      InlineAccessoryView(data: entry.data)
        default:                    CircularAccessoryView(data: entry.data)
        }
    }
}

// MARK: - Circular Accessory
//
// Two states: all-clear (checkmark) or N-affected (icon + count). The
// circular accessory is too small (~46pt) for the B silhouette to read
// cleanly — SF Symbols give us crisper monochrome rendering in the lock-
// screen accent pipeline.

struct CircularAccessoryView: View {
    let data: WidgetData

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            if data.allClear {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2.weight(.semibold))
                    Text("OK")
                        .font(.caption2.weight(.semibold))
                }
            } else {
                VStack(spacing: 0) {
                    Image(systemName: data.worstStatus.icon)
                        .font(.title3.weight(.semibold))
                    Text("\(data.affectedLinesCount)")
                        .font(.custom("TipoMovinCDMX-Bold", size: 16, relativeTo: .headline))
                        .monospacedDigit()
                }
            }
        }
        .widgetAccentable()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        data.allClear
            ? "Metrobús: todo normal"
            : "Metrobús: \(data.affectedLinesCount) línea\(data.affectedLinesCount == 1 ? "" : "s") con incidentes"
    }
}

// MARK: - Rectangular Accessory
//
// Wider rectangular card on the lock screen — about 158×72pt. Fits the
// worst-affected line as a hero plus a list of remaining affected lines.

struct RectangularAccessoryView: View {
    let data: WidgetData

    private var worst: WidgetLineStatus? {
        data.linesWithIssues.max(by: { $0.status.severity < $1.status.severity })
    }

    var body: some View {
        if data.allClear {
            allClearLayout
        } else {
            issueLayout
        }
    }

    private var allClearLayout: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .widgetAccentable()

            VStack(alignment: .leading, spacing: 1) {
                Text("Metrobús")
                    .font(.custom("TipoMovinCDMX-Bold", size: 13, relativeTo: .footnote))
                    .textCase(.uppercase)
                Text("Todas las líneas OK")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Metrobús: todas las líneas operando normal")
    }

    private var issueLayout: some View {
        HStack(spacing: 6) {
            // Worst-affected line hero
            if let worst {
                WidgetLineBadge(lineNumber: worst.lineNumber, size: .regular)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Metrobús")
                    .font(.custom("TipoMovinCDMX-Bold", size: 11, relativeTo: .caption2))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                if let worst {
                    Text(worst.status.shortText)
                        .font(.custom("TipoMovinCDMX-Bold", size: 13, relativeTo: .footnote))
                        .textCase(.uppercase)
                        .widgetAccentable()
                        .lineLimit(1)
                }

                if data.affectedLinesCount > 1 {
                    Text("+ \(data.affectedLinesCount - 1) línea\(data.affectedLinesCount - 1 == 1 ? "" : "s") más")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(issueAccessibilityText)
    }

    private var issueAccessibilityText: String {
        guard let worst else { return "Metrobús sin datos" }
        let extra = data.affectedLinesCount - 1
        let extraText = extra > 0 ? ". Y \(extra) línea\(extra == 1 ? "" : "s") más" : ""
        return "Metrobús: línea \(worst.lineNumber) \(worst.status.displayText)\(extraText)"
    }
}

// MARK: - Inline Accessory
//
// Single line of text + leading symbol. iOS strictly limits content here.

struct InlineAccessoryView: View {
    let data: WidgetData

    var body: some View {
        if data.allClear {
            Label("Metrobús OK", systemImage: "checkmark.circle.fill")
                .accessibilityLabel("Metrobús: todas las líneas normal")
        } else {
            Label(
                "MB · \(data.affectedLinesCount) incidente\(data.affectedLinesCount == 1 ? "" : "s")",
                systemImage: data.worstStatus.icon
            )
            .accessibilityLabel("Metrobús: \(data.affectedLinesCount) incidente\(data.affectedLinesCount == 1 ? "" : "s")")
        }
    }
}

// MARK: - Previews

#Preview("Circular — All Clear", as: .accessoryCircular) {
    MetrobusAccessoryWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: false)
}

#Preview("Circular — Issues", as: .accessoryCircular) {
    MetrobusAccessoryWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: [
            WidgetLineStatus(id: "1", lineNumber: "1", status: .suspended, affectedStationsCount: 3, incidentCount: 1),
            WidgetLineStatus(id: "4", lineNumber: "4", status: .protest, affectedStationsCount: 2, incidentCount: 1),
        ],
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Rectangular — All Clear", as: .accessoryRectangular) {
    MetrobusAccessoryWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: .placeholder, isPlaceholder: false)
}

#Preview("Rectangular — Issues", as: .accessoryRectangular) {
    MetrobusAccessoryWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: [
            WidgetLineStatus(id: "1", lineNumber: "1", status: .protest, affectedStationsCount: 4, incidentCount: 1),
            WidgetLineStatus(id: "4", lineNumber: "4", status: .suspended, affectedStationsCount: 1, incidentCount: 1),
            WidgetLineStatus(id: "7", lineNumber: "7", status: .limited, affectedStationsCount: 3, incidentCount: 1),
        ],
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}

#Preview("Inline", as: .accessoryInline) {
    MetrobusAccessoryWidget()
} timeline: {
    MetrobusStatusEntry(date: .now, data: WidgetData(
        lines: [
            WidgetLineStatus(id: "1", lineNumber: "1", status: .suspended, affectedStationsCount: 2, incidentCount: 1),
        ],
        updatedAt: Date(),
        isStale: false
    ), isPlaceholder: false)
}
