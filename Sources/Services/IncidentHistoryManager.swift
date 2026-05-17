import Foundation

// MARK: - Incident History Manager

/// Manages incident history persistence and detection
actor IncidentHistoryManager {
    static let shared = IncidentHistoryManager()

    private let fileURL: URL
    private var history: IncidentHistory
    private var previousStatus: [String: LineStatus] = [:]
    private var activeSignatures: Set<String> = []

    private init() {
        // Use App Group for widget access. Bug history: this used the literal
        // "group.app.parabus" which doesn't match the entitlement
        // "group.starkji.parabus-cdmx.app", so containerURL returned nil and
        // every history write silently fell back to the per-process caches
        // directory (which iOS may purge and the widget can't read).
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ParabusConstants.appGroupIdentifier
        ) {
            fileURL = containerURL.appendingPathComponent("incident_history.json")
        } else {
            fileURL = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("incident_history.json")
        }

        // Load existing history
        history = Self.load(from: fileURL)

        // Build active signatures from loaded data
        activeSignatures = Set(history.activeIncidents.map { $0.signature })
    }

    // MARK: - Public API

    /// Get today's incidents
    var todaysIncidents: [TimelineIncident] {
        history.todaysIncidents
    }

    /// Get active incidents count
    var activeCount: Int {
        history.activeIncidents.count
    }

    /// Get incidents grouped by hour
    func groupedByHour() -> [HourGroup] {
        history.groupedByHour()
    }

    /// Get incidents filtered by favorite lines
    func incidents(forLines lineNumbers: [String]) -> [TimelineIncident] {
        let lineSet = Set(lineNumbers)
        return history.todaysIncidents.filter { lineSet.contains($0.lineNumber) }
    }

    /// Process a status update to detect new/resolved incidents
    func processStatusUpdate(_ lines: [LineStatus]) async {
        for line in lines {
            let previousLine = previousStatus[line.lineNumber]

            // Detect NEW incidents
            for incident in line.incidents {
                let signature = makeSignature(
                    lineNumber: line.lineNumber,
                    status: incident.status,
                    stations: incident.affectedStations
                )

                if !activeSignatures.contains(signature) {
                    // New incident detected
                    let timelineIncident = TimelineIncident(
                        lineNumber: line.lineNumber,
                        lineName: line.lineName,
                        status: incident.status,
                        affectedStations: incident.affectedStations,
                        info: incident.info,
                        occurredAt: Date()
                    )
                    history.incidents.append(timelineIncident)
                    activeSignatures.insert(signature)
                }
            }

            // Detect RESOLVED incidents
            if let previous = previousLine {
                for previousIncident in previous.incidents {
                    let signature = makeSignature(
                        lineNumber: line.lineNumber,
                        status: previousIncident.status,
                        stations: previousIncident.affectedStations
                    )

                    // Check if this incident is no longer in current status
                    let stillActive = line.incidents.contains { current in
                        current.status == previousIncident.status &&
                        Set(current.affectedStations) == Set(previousIncident.affectedStations)
                    }

                    if !stillActive && activeSignatures.contains(signature) {
                        markIncidentResolved(signature: signature)
                    }
                }
            }
        }

        // Update previous state
        previousStatus = Dictionary(uniqueKeysWithValues: lines.map { ($0.lineNumber, $0) })

        // Periodic cleanup
        await cleanupIfNeeded()

        // Persist
        await save()
    }

    /// Force sync with current status (useful on app launch)
    func syncWithCurrentStatus(_ lines: [LineStatus]) async {
        // Mark all previously active incidents as potentially resolved
        let currentSignatures = Set(lines.flatMap { line in
            line.incidents.map { incident in
                makeSignature(
                    lineNumber: line.lineNumber,
                    status: incident.status,
                    stations: incident.affectedStations
                )
            }
        })

        // Resolve incidents that are no longer active
        for signature in activeSignatures {
            if !currentSignatures.contains(signature) {
                markIncidentResolved(signature: signature)
            }
        }

        // Add any new incidents
        for line in lines {
            for incident in line.incidents {
                let signature = makeSignature(
                    lineNumber: line.lineNumber,
                    status: incident.status,
                    stations: incident.affectedStations
                )

                if !activeSignatures.contains(signature) {
                    let timelineIncident = TimelineIncident(
                        lineNumber: line.lineNumber,
                        lineName: line.lineName,
                        status: incident.status,
                        affectedStations: incident.affectedStations,
                        info: incident.info,
                        occurredAt: Date()
                    )
                    history.incidents.append(timelineIncident)
                    activeSignatures.insert(signature)
                }
            }
        }

        previousStatus = Dictionary(uniqueKeysWithValues: lines.map { ($0.lineNumber, $0) })
        await save()
    }

    /// Clear all history (for debugging)
    func clearHistory() async {
        history = IncidentHistory()
        activeSignatures.removeAll()
        previousStatus.removeAll()
        await save()
    }

    // MARK: - Private Methods

    private func makeSignature(lineNumber: String, status: ServiceStatus, stations: [String]) -> String {
        let stationsKey = stations.sorted().joined(separator: ",")
        return "\(lineNumber)_\(status.rawValue)_\(stationsKey)"
    }

    private func markIncidentResolved(signature: String) {
        // Find the matching active incident and set resolvedAt
        if let index = history.incidents.lastIndex(where: {
            $0.signature == signature && $0.isActive
        }) {
            history.incidents[index].resolvedAt = Date()
            activeSignatures.remove(signature)
        }
    }

    private func cleanupIfNeeded() async {
        let calendar = Calendar.current
        let daysSinceCleanup = calendar.dateComponents(
            [.day],
            from: history.lastCleanup,
            to: Date()
        ).day ?? 0

        if daysSinceCleanup >= 1 {
            history.pruneOldIncidents()
        }

        // Limit total incidents to prevent unbounded growth
        if history.incidents.count > 500 {
            let sortedByDate = history.incidents.sorted { $0.occurredAt > $1.occurredAt }
            history.incidents = Array(sortedByDate.prefix(500))
        }
    }

    // MARK: - Persistence

    private func save() async {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save incident history: \(error)")
        }
    }

    private static func load(from url: URL) -> IncidentHistory {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return IncidentHistory()
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(IncidentHistory.self, from: data)
        } catch {
            print("Failed to load incident history: \(error)")
            return IncidentHistory()
        }
    }
}
