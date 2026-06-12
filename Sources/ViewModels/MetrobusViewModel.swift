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
    /// True when the last `refresh()` attempt threw an error. Cleared at the
    /// start of every attempt and on success. Consumers (e.g. ContentView) use
    /// this to show failure haptics / inline copy without conflating a transient
    /// network hiccup with a persistent "data is old" state.
    private(set) var refreshFailed = false
    /// Upstream-reported warning when the API served cached or partial data
    /// (e.g. "Failed to fetch fresh data, serving cached response"). Surface
    /// in UI alongside `isStale` for an honest "data may not reflect current
    /// service state" indicator. REVIEW MED-02.
    private(set) var sourceWarning: String?

    // MARK: - Scheduled Maintenance State

    private(set) var maintenanceClosures: [ScheduledClosure] = []

    /// When we last completed a fetch against the worker (success or not).
    /// Distinct from `lastUpdated` (= upstream `scrapedAt`, which can be up
    /// to 5 min old when the worker serves its KV cache) — this drives the
    /// client-side throttle so tab switches and rapid pulls don't spam the
    /// endpoint.
    private var lastFetchedAt: Date?

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

    /// Minimum age before another network fetch is worth it. The worker
    /// caches /status in KV for 5 min and serves max-age=60, so requests
    /// inside this window can't return anything fresher anyway.
    private static let minFetchInterval: TimeInterval = 60

    /// Repeated pull-to-refresh inside this window downgrades from
    /// `refresh=true` (upstream re-scrape) to a normal worker-cached fetch.
    private static let forceRefreshSpamGuard: TimeInterval = 30


    /// Normalize station name for comparison
    private func normalizeStationName(_ name: String) -> String {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "est.", with: "")
            .replacingOccurrences(of: "estacion", with: "")
            .replacingOccurrences(of: "estación", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasError: Bool {
        error != nil
    }

    var isEmpty: Bool {
        lines.isEmpty && !isLoading
    }

    var statusSummary: String {
        if isLoading && lines.isEmpty { return String(localized: "Cargando...") }
        if isLoading { return String(localized: "Actualizando...") }
        if lines.isEmpty { return String(localized: "Sin datos") }

        let issueCount = linesWithIssues.count
        let closureCount = deduplicatedTodaysClosures.count

        if issueCount == 0 && closureCount == 0 {
            return String(localized: "Todas las líneas operando normal")
        } else if issueCount == 0 && closureCount > 0 {
            return closureCount == 1
                ? String(localized: "1 estación cerrada hoy")
                : String(localized: "\(closureCount) estaciones cerradas hoy")
        } else if issueCount > 0 && closureCount == 0 {
            return issueCount == 1
                ? String(localized: "1 línea con incidentes")
                : String(localized: "\(issueCount) líneas con incidentes")
        } else {
            let incidents = issueCount == 1
                ? String(localized: "1 incidente")
                : String(localized: "\(issueCount) incidentes")
            let closures = closureCount == 1
                ? String(localized: "1 cierre")
                : String(localized: "\(closureCount) cierres")
            return "\(incidents) + \(closures)"
        }
    }

    var lastUpdatedDescription: String? {
        guard let lastUpdated else { return nil }

        let minutes = Int(Date().timeIntervalSince(lastUpdated) / 60)
        if minutes < 1 {
            return String(localized: "Actualizado ahora")
        } else if minutes == 1 {
            return String(localized: "Actualizado hace 1 min")
        } else if minutes < 60 {
            return String(localized: "Actualizado hace \(minutes) min")
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return String(localized: "Actualizado \(formatter.string(from: lastUpdated))")
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

    var hasMaintenanceToday: Bool {
        !deduplicatedTodaysClosures.isEmpty
    }

    // MARK: - Dependencies (injected)

    private let dataProvider: any TransitDataProviding
    private let cache: any CacheStorageProviding

    // MARK: - Initialization

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
    ///
    /// Passive trigger (`.task` re-fires on every tab switch): the user
    /// didn't ask for anything new, so skip the network entirely while the
    /// last fetch is fresh. Explicit gestures go through `refresh()`.
    func loadStatus() async {
        guard !isLoading else { return }

        // Cargar cache primero para UI inmediata
        await loadFromCache()

        if let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < Self.minFetchInterval {
            return
        }
        await refreshAll(forceRefresh: false)
    }

    /// Pull-to-refresh: an explicit "I want fresh data now", so it always
    /// hits the network. `refresh=true` (bypasses the worker's KV cache and
    /// re-scrapes upstream) is only sent when our last fetch is old enough
    /// to possibly be beaten — repeated pulls inside the window degrade to
    /// normal fetches instead of hammering the upstream sources.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let force: Bool
        if let lastFetchedAt {
            force = Date().timeIntervalSince(lastFetchedAt) > Self.forceRefreshSpamGuard
        } else {
            force = true
        }
        await refreshAll(forceRefresh: force)
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
        error = nil
        refreshFailed = false

        do {
            let (status, maintenance) = try await dataProvider.fetchAll(forceRefresh: forceRefresh)
            lastFetchedAt = Date()

            lines = sortLines(status.lines)
            lastUpdated = status.scrapedAt
            // Honor upstream's "I'm serving stale cache" signal (worker sets
            // this when it falls back after a failed source fetch). Previous
            // behavior set isStale = false unconditionally on any 2xx
            // response and dropped sourceError on the floor.
            isStale = status.isStale
            sourceWarning = status.sourceError

            maintenanceClosures = maintenance.closures

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
            // Only mark data as stale when it's genuinely old (> 10 min).
            // A transient network failure while serving recent data shouldn't
            // flip the warning tint — that would be a false negative signal.
            isStale = Self.staleAfterFailure(lastUpdated: lastUpdated)
            refreshFailed = true
        }

        isLoading = false
    }

    /// Pure stale-policy decision: after a refresh failure, should the UI show
    /// the "data may be outdated" warning? Only when the on-screen data is
    /// older than 10 minutes (or there is no data at all).
    ///
    /// `nonisolated` so it can be called from non-`@MainActor` contexts
    /// (unit tests, background tasks) without an `await`. The function is
    /// pure — it reads only its arguments and `Date()` — so isolation is
    /// irrelevant.
    nonisolated static func staleAfterFailure(lastUpdated: Date?, now: Date = Date()) -> Bool {
        guard let lastUpdated else { return true }
        return now.timeIntervalSince(lastUpdated) > 10 * 60
    }

    // MARK: - Helpers

    private func sortLines(_ lines: [LineStatus]) -> [LineStatus] {
        lines.sorted { $0.lineNumber.localizedStandardCompare($1.lineNumber) == .orderedAscending }
    }
}
