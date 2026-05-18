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
    /// Upstream-reported warning when the API served cached or partial data
    /// (e.g. "Failed to fetch fresh data, serving cached response"). Surface
    /// in UI alongside `isStale` for an honest "data may not reflect current
    /// service state" indicator. REVIEW MED-02.
    private(set) var sourceWarning: String?

    // MARK: - Scheduled Maintenance State

    private(set) var maintenanceClosures: [ScheduledClosure] = []
    private(set) var isLoadingMaintenance = false
    private(set) var maintenanceLastUpdated: Date?

    // MARK: - Derived State (cached)
    //
    // These used to be computed properties — `allLines` rebuilt a Dictionary
    // on every access, `deduplicatedTodaysClosures` did O(lines × incidents
    // × stations) work plus a filter pass over `maintenanceClosures`, both
    // accessed multiple times per SwiftUI render. Now stored properties
    // recomputed once per data refresh in `recomputeDerivedState()`.

    /// All 7 lines, filling in missing ones with regular status.
    private(set) var allLines: [LineStatus] = []

    /// Lines that currently have any reported issue.
    private(set) var linesWithIssues: [LineStatus] = []

    /// Today's closures, filtered to avoid showing scheduled maintenance at
    /// stations that already have a more severe real-time incident
    /// (suspended/delayed). Intervention closures are always included.
    private(set) var deduplicatedTodaysClosures: [ScheduledClosure] = []

    // MARK: - Constants

    /// All Metrobús line numbers (1-7)
    private static let allLineNumbers = ["1", "2", "3", "4", "5", "6", "7"]


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

    /// Carga todos los datos: incidentes en tiempo real y mantenimientos programados.
    /// Single network round-trip via dataProvider.fetchAll — /status returns
    /// both payloads in one response.
    func loadStatus() async {
        guard !isLoading else { return }

        // Cargar cache primero para UI inmediata
        await loadFromCache()
        await refreshAll(forceRefresh: false)
    }

    /// Fuerza refresh (bypasses cache). Sets isRefreshing for UI feedback during
    /// pull-to-refresh.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await refreshAll(forceRefresh: true)
    }

    func clearError() {
        error = nil
    }

    // MARK: - Derived State Recomputation

    /// Recompute `allLines`, `linesWithIssues`, `deduplicatedTodaysClosures`
    /// from the just-updated source data. Call after any assignment to
    /// `lines` or `maintenanceClosures`. One pass through each input,
    /// instead of multiple passes per SwiftUI render.
    private func recomputeDerivedState() {
        // allLines: 7-element array with placeholders for missing lines.
        let existing = Dictionary(uniqueKeysWithValues: lines.map { ($0.lineNumber, $0) })
        allLines = Self.allLineNumbers.map { num in
            existing[num] ?? LineStatus(
                lineNumber: num,
                transportType: .metrobus,
                status: .regular
            )
        }

        // linesWithIssues: simple filter; cached so SwiftUI doesn't re-run
        // the filter on every property read.
        linesWithIssues = lines.filter { $0.hasIssues }

        // Build the suspended/delayed station map once for the dedup pass.
        var severeStations: [String: Set<String>] = [:]
        for line in linesWithIssues {
            for incident in line.incidents
                where incident.status == .suspended || incident.status == .delayed {
                for station in incident.affectedStations {
                    severeStations[line.lineNumber, default: []]
                        .insert(normalizeStationName(station))
                }
            }
        }

        // Filter scheduled closures whose station already shows a severe incident,
        // then append intervention-as-closure rows so they always appear.
        let scheduledToday = maintenanceClosures.filter { $0.isActive() }
        let filteredScheduled = scheduledToday.filter { closure in
            let stations = severeStations[closure.lineNumber] ?? []
            guard !stations.isEmpty else { return true }
            let normalized = normalizeStationName(closure.stationName)
            return !stations.contains { existing in
                normalized == existing
                    || normalized.contains(existing)
                    || existing.contains(normalized)
            }
        }
        deduplicatedTodaysClosures = filteredScheduled + interventionClosures
    }

    // MARK: - Private (Incidents)

    private func loadFromCache() async {
        do {
            if let cached = try await cache.load() {
                lines = sortLines(cached.lines)
                lastUpdated = cached.cachedAt
                isStale = cached.isStale
                recomputeDerivedState()
            }
        } catch {
            // Cache corrupto, ignorar silenciosamente
        }
    }

    /// Single unified fetch path. Replaced the old refreshIncidents +
    /// refreshMaintenance pair which each hit /status independently (one
    /// payload, two decodes). Now both `lines` and `maintenanceClosures`
    /// come from one decoded response with a consistent `scrapedAt`.
    private func refreshAll(forceRefresh: Bool) async {
        isLoading = true
        isLoadingMaintenance = true
        error = nil

        do {
            let (status, maintenance) = try await dataProvider.fetchAll(forceRefresh: forceRefresh)

            lines = sortLines(status.lines)
            lastUpdated = status.scrapedAt
            // Honor upstream's "I'm serving stale cache" signal (worker sets
            // this when it falls back after a failed source fetch). Previous
            // behavior set isStale = false unconditionally on any 2xx
            // response and dropped sourceError on the floor.
            isStale = status.isStale
            sourceWarning = status.sourceError

            maintenanceClosures = maintenance.closures
            maintenanceLastUpdated = maintenance.scrapedAt

            recomputeDerivedState()

            try? await cache.save(status)
            WidgetService.reloadAfterDataUpdate()

            #if os(iOS)
            if #available(iOS 16.2, *) {
                await LiveActivityService.shared.processStatusUpdate(lines)
            }
            #endif
        } catch {
            // Solo mostrar error si no hay datos en cache.
            if lines.isEmpty {
                self.error = error
            }
            isStale = true
        }

        isLoading = false
        isLoadingMaintenance = false
    }

    // MARK: - Helpers

    private func sortLines(_ lines: [LineStatus]) -> [LineStatus] {
        lines.sorted { $0.lineNumber.localizedStandardCompare($1.lineNumber) == .orderedAscending }
    }
}
