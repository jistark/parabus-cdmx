import Foundation

// MARK: - Timeline Incident

/// Represents a timestamped incident for timeline display
struct TimelineIncident: Identifiable, Codable, Hashable {
    let id: UUID
    let lineNumber: String
    let lineName: String
    let status: ServiceStatus
    let affectedStations: [String]
    let info: String?
    let occurredAt: Date
    var resolvedAt: Date?

    init(
        id: UUID = UUID(),
        lineNumber: String,
        lineName: String = "",
        status: ServiceStatus,
        affectedStations: [String] = [],
        info: String? = nil,
        occurredAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.lineNumber = lineNumber
        self.lineName = lineName.isEmpty ? "Linea \(lineNumber)" : lineName
        self.status = status
        self.affectedStations = affectedStations
        self.info = info
        self.occurredAt = occurredAt
        self.resolvedAt = resolvedAt
    }

    /// True if incident is currently active
    var isActive: Bool {
        resolvedAt == nil
    }

    /// Duration of incident (or time since start if still active)
    var duration: TimeInterval {
        let end = resolvedAt ?? Date()
        return end.timeIntervalSince(occurredAt)
    }

    /// Formatted time string (e.g., "08:45")
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: occurredAt)
    }

    /// Formatted duration string
    var durationString: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours) h"
        }
        return "\(hours) h \(remainingMinutes) min"
    }

    /// Unique signature for deduplication (same line + status + stations = same incident)
    var signature: String {
        let stationsKey = affectedStations.sorted().joined(separator: ",")
        return "\(lineNumber)_\(status.rawValue)_\(stationsKey)"
    }
}

// MARK: - Incident History

/// Manages persistent storage of incident history
struct IncidentHistory: Codable {
    var incidents: [TimelineIncident]
    var lastCleanup: Date

    init(incidents: [TimelineIncident] = [], lastCleanup: Date = Date()) {
        self.incidents = incidents
        self.lastCleanup = lastCleanup
    }

    /// Incidents from today only, sorted newest first
    var todaysIncidents: [TimelineIncident] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return incidents
            .filter { $0.occurredAt >= startOfDay }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    /// Active incidents (not yet resolved)
    var activeIncidents: [TimelineIncident] {
        incidents.filter { $0.isActive }
    }

    /// Clean up incidents older than 7 days
    mutating func pruneOldIncidents() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        incidents.removeAll { $0.occurredAt < cutoff }
        lastCleanup = Date()
    }

    /// Group today's incidents by hour
    func groupedByHour() -> [HourGroup] {
        let today = todaysIncidents
        let active = today.filter { $0.isActive }
        let resolved = today.filter { !$0.isActive }

        var groups: [HourGroup] = []

        // Active incidents first
        if !active.isEmpty {
            groups.append(HourGroup(
                title: "Ahora",
                incidents: active.sorted { $0.occurredAt > $1.occurredAt },
                isActive: true
            ))
        }

        // Group resolved by hour
        let calendar = Calendar.current
        let byHour = Dictionary(grouping: resolved) { incident -> Int in
            calendar.component(.hour, from: incident.occurredAt)
        }

        for hour in byHour.keys.sorted(by: >) {
            guard let hourIncidents = byHour[hour] else { continue }
            let nextHour = (hour + 1) % 24
            let title = String(format: "%02d:00 - %02d:00", hour, nextHour)
            groups.append(HourGroup(
                title: title,
                incidents: hourIncidents.sorted { $0.occurredAt > $1.occurredAt },
                isActive: false
            ))
        }

        return groups
    }
}

// MARK: - Hour Group

/// Groups incidents by hour for timeline display
struct HourGroup: Identifiable {
    let id = UUID()
    let title: String
    let incidents: [TimelineIncident]
    let isActive: Bool
}
