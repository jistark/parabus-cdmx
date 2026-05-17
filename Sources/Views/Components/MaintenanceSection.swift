import SwiftUI

// MARK: - Maintenance Section

/// Displays scheduled maintenance closures grouped by line
struct MaintenanceSection: View {
    let closures: [ScheduledClosure]
    let title: String
    let icon: String
    let isToday: Bool

    init(
        closures: [ScheduledClosure],
        title: String = "Cierres por mantenimiento",
        icon: String = "calendar.badge.clock",
        isToday: Bool = true
    ) {
        self.closures = closures
        self.title = title
        self.icon = icon
        self.isToday = isToday
    }

    private var closuresByLine: [String: [ScheduledClosure]] {
        Dictionary(grouping: closures, by: \.lineNumber)
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
    }

    private var sortedLineNumbers: [String] {
        closuresByLine.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (only show if title is not empty)
            if !title.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)

                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(closures.count) estacion\(closures.count == 1 ? "" : "es")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
            }

            // Closures by line
            VStack(spacing: 8) {
                ForEach(sortedLineNumbers, id: \.self) { lineNumber in
                    if let lineClosures = closuresByLine[lineNumber] {
                        MaintenanceLineGroup(
                            lineNumber: lineNumber,
                            closures: lineClosures,
                            isToday: isToday
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Maintenance Line Group

/// Groups closures for a single line
struct MaintenanceLineGroup: View {
    let lineNumber: String
    let closures: [ScheduledClosure]
    let isToday: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line header
            Button {
                withAnimation(.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Line badge
                    LineBadgeMini(lineNumber: lineNumber)

                    // Station count
                    Text("\(closures.count) estacion\(closures.count == 1 ? "" : "es")")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(closures) { closure in
                        MaintenanceClosureRow(closure: closure, isToday: isToday)
                    }
                }
                .padding(.leading, 48)
                .padding(.trailing, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Maintenance Closure Row

/// Single maintenance closure display
struct MaintenanceClosureRow: View {
    let closure: ScheduledClosure
    let isToday: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            Circle()
                .fill(isToday ? Color.orange : Color.yellow.opacity(0.6))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                // Station name
                Text(closure.stationName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                // Direction and reason
                HStack(spacing: 8) {
                    Label(closure.direction.shortName, systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(closure.reason.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Period/hours
                if let hours = closure.hours, hours.startHour != nil {
                    Label(formatHours(hours), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !isToday {
                    Text(closure.closurePeriod)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func formatHours(_ hours: ClosureHours) -> String {
        if let start = hours.startHour {
            if hours.untilClose {
                return "Desde las \(start):00 hasta el cierre"
            } else if let end = hours.endHour {
                return "\(start):00 - \(end):00"
            } else {
                return "Desde las \(start):00"
            }
        }
        return hours.description
    }
}

// MARK: - Line Badge Mini

/// Smaller line badge for maintenance section - uses official icons when available
struct LineBadgeMini: View {
    let lineNumber: String

    var body: some View {
        Group {
            if let image = TransitImageLoader.loadOfficialImage(
                for: lineNumber,
                transportType: .metrobus
            ) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            } else {
                // Fallback to colored circle
                ZStack {
                    Circle()
                        .fill(lineColor.gradient)
                        .frame(width: 28, height: 28)

                    Text(lineNumber)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .accessibilityLabel("Línea \(lineNumber)")
    }

    private var lineColor: Color {
        LineColors.color(for: lineNumber)
    }
}


// MARK: - Preview

#Preview("Maintenance Section") {
    ScrollView {
        VStack(spacing: 24) {
            MaintenanceSection(
                closures: [
                    ScheduledClosure(
                        lineNumber: "1",
                        stationName: "Manuel Gonzalez",
                        direction: .both,
                        reason: .majorMaintenance,
                        closurePeriod: "5 y 6 de Diciembre"
                    ),
                    ScheduledClosure(
                        lineNumber: "1",
                        stationName: "Reforma",
                        direction: .both,
                        reason: .majorMaintenance,
                        closurePeriod: "5 y 6 de Diciembre"
                    ),
                    ScheduledClosure(
                        lineNumber: "5",
                        stationName: "Rio Guadalupe",
                        direction: .northbound,
                        reason: .maintenance,
                        closurePeriod: "5 de Diciembre",
                        hours: ClosureHours(startHour: 20, description: "hasta el cierre")
                    ),
                ],
                title: "Cierres hoy",
                isToday: true
            )

            MaintenanceSection(
                closures: [
                    ScheduledClosure(
                        lineNumber: "5",
                        stationName: "Canal del Norte",
                        direction: .both,
                        reason: .maintenance,
                        closurePeriod: "8 de diciembre, de las 20 horas al cierre"
                    ),
                ],
                title: "Proximos cierres",
                icon: "calendar",
                isToday: false
            )
        }
        .padding(.vertical)
    }
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}
