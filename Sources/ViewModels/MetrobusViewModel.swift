import Foundation
import Observation
import WidgetKit

@Observable
@MainActor
final class MetrobusViewModel {

    // MARK: - Real-time Incidents State

    private(set) var lines: [LineStatus] = []
    private(set) var isLoading = false
    private(set) var isRefreshing = false
    private(set) var error: Error?
    private(set) var lastUpdated: Date?
    private(set) var isStale = false

    // MARK: - Scheduled Maintenance State

    private(set) var maintenanceClosures: [ScheduledClosure] = []
    private(set) var isLoadingMaintenance = false
    private(set) var maintenanceLastUpdated: Date?

    // MARK: - Constants

    /// All Metrobús line numbers (1-7)
    private static let allLineNumbers = ["1", "2", "3", "4", "5", "6", "7"]

    // MARK: - Computed Properties (Incidents)

    /// All 7 lines, filling in missing ones with regular status
    var allLines: [LineStatus] {
        let existingByNumber = Dictionary(uniqueKeysWithValues: lines.map { ($0.lineNumber, $0) })

        return Self.allLineNumbers.map { lineNumber in
            if let existing = existingByNumber[lineNumber] {
                return existing
            }
            // Create placeholder for missing line with regular status
            return LineStatus(
                lineNumber: lineNumber,
                transportType: .metrobus,
                status: .regular
            )
        }
    }

    var linesWithIssues: [LineStatus] {
        lines.filter { $0.hasIssues }
    }

    /// Stations with non-intervention incidents (suspended, delayed)
    /// These take priority over scheduled maintenance closures
    private var nonInterventionIncidentStations: [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for line in linesWithIssues {
            for incident in line.incidents {
                // Only track suspended/delayed incidents, not intervention
                // (intervention closures are shown separately in the closures section)
                guard incident.status == .suspended || incident.status == .delayed else {
                    continue
                }
                for station in incident.affectedStations {
                    let normalized = normalizeStationName(station)
                    result[line.lineNumber, default: []].insert(normalized)
                }
            }
        }
        return result
    }

    /// Today's closures, filtered to avoid showing scheduled maintenance at stations
    /// that have more severe real-time incidents (suspended/delayed)
    /// Intervention incidents are always shown since they represent station closures
    var deduplicatedTodaysClosures: [ScheduledClosure] {
        let severeIncidentStations = nonInterventionIncidentStations

        // Filter scheduled closures to remove overlap with severe incidents
        let filteredScheduled = scheduledTodaysClosures.filter { closure in
            let lineIncidents = severeIncidentStations[closure.lineNumber] ?? []

            // If no severe incidents on this line, keep the closure
            guard !lineIncidents.isEmpty else {
                return true
            }

            // Check if this closure's station has a severe incident
            let normalizedStation = normalizeStationName(closure.stationName)
            let hasSevereIssue = lineIncidents.contains { incidentStation in
                normalizedStation == incidentStation ||
                normalizedStation.contains(incidentStation) ||
                incidentStation.contains(normalizedStation)
            }

            return !hasSevereIssue
        }

        // Combine filtered scheduled closures with intervention closures
        return filteredScheduled + interventionClosures
    }


    /// Normalize station name for comparison
    private func normalizeStationName(_ name: String) -> String {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "est.", with: "")
            .replacingOccurrences(of: "estacion", with: "")
            .replacingOccurrences(of: "estación", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalLines: [LineStatus] {
        lines.filter { !$0.hasIssues }
    }

    var hasError: Bool {
        error != nil
    }

    var isEmpty: Bool {
        lines.isEmpty && !isLoading
    }

    var hasActiveIncidents: Bool {
        !linesWithIssues.isEmpty
    }

    var statusSummary: String {
        if isLoading && lines.isEmpty { return "Cargando..." }
        if isLoading { return "Actualizando..." }
        if lines.isEmpty { return "Sin datos" }

        let issueCount = linesWithIssues.count
        let closureCount = deduplicatedTodaysClosures.count

        if issueCount == 0 && closureCount == 0 {
            return "Todas las lineas operando normal"
        } else if issueCount == 0 && closureCount > 0 {
            return "\(closureCount) estacion\(closureCount == 1 ? "" : "es") cerrada\(closureCount == 1 ? "" : "s") hoy"
        } else if issueCount > 0 && closureCount == 0 {
            return "\(issueCount) linea\(issueCount == 1 ? "" : "s") con incidentes"
        } else {
            return "\(issueCount) incidente\(issueCount == 1 ? "" : "s") + \(closureCount) cierre\(closureCount == 1 ? "" : "s")"
        }
    }

    var lastUpdatedDescription: String? {
        guard let lastUpdated else { return nil }

        let minutes = Int(Date().timeIntervalSince(lastUpdated) / 60)
        if minutes < 1 {
            return "Actualizado ahora"
        } else if minutes == 1 {
            return "Actualizado hace 1 min"
        } else if minutes < 60 {
            return "Actualizado hace \(minutes) min"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Actualizado \(formatter.string(from: lastUpdated))"
        }
    }

    // MARK: - Computed Properties (Maintenance)

    /// Closures from incidents with "Intervencion en la estacion" status
    /// These are real-time closures that should appear alongside scheduled maintenance
    private var interventionClosures: [ScheduledClosure] {
        linesWithIssues.flatMap { line -> [ScheduledClosure] in
            line.incidents
                .filter { $0.status == .intervention }
                .flatMap { incident -> [ScheduledClosure] in
                    // Create a closure for each affected station
                    if incident.affectedStations.isEmpty {
                        // No specific stations - create one generic closure for the line
                        return [ScheduledClosure(
                            lineNumber: line.lineNumber,
                            stationName: "Linea \(line.lineNumber)",
                            direction: .both,
                            reason: .maintenance,
                            closurePeriod: "Hoy",
                            parsedDates: [Date()],
                            hours: nil
                        )]
                    } else {
                        return incident.affectedStations.map { station in
                            ScheduledClosure(
                                lineNumber: line.lineNumber,
                                stationName: station,
                                direction: .both,
                                reason: .maintenance,
                                closurePeriod: incident.info ?? "Hoy",
                                parsedDates: [Date()],
                                hours: nil
                            )
                        }
                    }
                }
        }
    }

    /// Closures active today (scheduled maintenance only)
    private var scheduledTodaysClosures: [ScheduledClosure] {
        maintenanceClosures.filter { $0.isActive() }
    }

    /// All closures active today: scheduled + intervention incidents
    var todaysClosures: [ScheduledClosure] {
        scheduledTodaysClosures + interventionClosures
    }

    /// Closures grouped by line for today
    var todaysClosuresByLine: [String: [ScheduledClosure]] {
        Dictionary(grouping: todaysClosures, by: \.lineNumber)
    }

    /// Upcoming closures (not today)
    var upcomingClosures: [ScheduledClosure] {
        let today = Calendar.current.startOfDay(for: Date())
        return maintenanceClosures.filter { closure in
            guard let dates = closure.parsedDates, !dates.isEmpty else { return true }
            return dates.allSatisfy { $0 > today }
        }
    }

    var hasMaintenanceToday: Bool {
        !deduplicatedTodaysClosures.isEmpty
    }

    var hasUpcomingMaintenance: Bool {
        !upcomingClosures.isEmpty
    }

    // MARK: - Dependencies (injected)

    private let dataProvider: any TransitDataProviding
    private let cache: any CacheStorageProviding

    // MARK: - Initialization

    /// Production initializer — always uses the worker API.
    /// The previous TransitDataSource switch had a `.scraper` case backed by
    /// `MetrobusScraper` (HTML scrape via SwiftSoup) that was statically
    /// unreachable (`TransitDataSource.current = .api` was hardcoded) and
    /// has since been deleted along with its dependency.
    init() {
        self.dataProvider = APITransitDataProvider()
        self.cache = CacheManager()
    }

    /// Testable initializer - accepts any conforming implementations
    init(
        dataProvider: any TransitDataProviding,
        cache: any CacheStorageProviding
    ) {
        self.dataProvider = dataProvider
        self.cache = cache
    }

    // MARK: - Actions

    /// Carga todos los datos: incidentes en tiempo real y mantenimientos programados
    func loadStatus() async {
        guard !isLoading else { return }

        // Cargar cache primero para UI inmediata
        await loadFromCache()

        // Refrescar ambos en paralelo
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshIncidents() }
            group.addTask { await self.refreshMaintenance() }
        }
    }

    /// Fuerza refresh de incidentes y mantenimientos (bypasses cache)
    /// Sets isRefreshing for UI feedback during pull-to-refresh
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshIncidents(forceRefresh: true) }
            group.addTask { await self.refreshMaintenance() }
        }
    }

    func clearError() {
        error = nil
    }

    // MARK: - Private (Incidents)

    private func loadFromCache() async {
        do {
            if let cached = try await cache.load() {
                lines = sortLines(cached.lines)
                lastUpdated = cached.cachedAt
                isStale = cached.isStale
            }
        } catch {
            // Cache corrupto, ignorar silenciosamente
        }
    }

    private func refreshIncidents(forceRefresh: Bool = false) async {
        isLoading = true
        error = nil

        do {
            let result = try await dataProvider.fetchStatus(forceRefresh: forceRefresh)
            lines = sortLines(result.lines)
            lastUpdated = result.scrapedAt
            isStale = false

            // Guardar en cache y actualizar widget
            try? await cache.save(result)

            // Update widgets
            WidgetService.reloadAfterDataUpdate()

            // Update Live Activities (iOS 16.2+)
            #if os(iOS)
            if #available(iOS 16.2, *) {
                await LiveActivityService.shared.processStatusUpdate(lines)
            }
            #endif

        } catch {
            // Solo mostrar error si no hay datos en cache
            if lines.isEmpty {
                self.error = error
            }
            // Si hay datos del cache, mantenerlos y marcar como stale
            isStale = true
        }

        isLoading = false
    }

    // MARK: - Private (Maintenance)

    private func refreshMaintenance() async {
        isLoadingMaintenance = true

        do {
            let result = try await dataProvider.fetchMaintenanceClosures()
            maintenanceClosures = result.closures
            maintenanceLastUpdated = result.scrapedAt
        } catch {
            // Silently fail - maintenance is secondary info
            print("Failed to fetch maintenance: \(error)")
        }

        isLoadingMaintenance = false
    }

    // MARK: - Helpers

    private func sortLines(_ lines: [LineStatus]) -> [LineStatus] {
        lines.sorted { $0.lineNumber.localizedStandardCompare($1.lineNumber) == .orderedAscending }
    }
}
