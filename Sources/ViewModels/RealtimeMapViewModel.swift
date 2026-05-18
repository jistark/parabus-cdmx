import CoreLocation
import Foundation
import Observation
import SwiftUI

/// Backing state for the realtime map. Polls /vehicles every 20s while the
/// view is visible. The poll interval matches the worker's Cache-API TTL so
/// requests outside service hours stay cheap (cache hit), and the cron-based
/// pre-warm keeps the cache hot — first user request is typically < 200ms.
@MainActor
@Observable
final class RealtimeMapViewModel {

    // MARK: - Observable state

    private(set) var vehicles: [VehiclePosition] = []
    private(set) var lastUpdated: Date?
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    /// True when the worker reports the operator's tracking system is offline.
    private(set) var serviceInactive: Bool = false
    /// routeId → line ("1".."7"). Loaded once from /static/routes; used to
    /// color vehicle markers correctly when no specific line is selected.
    private(set) var routeIdToLine: [String: String] = [:]

    /// Currently-focused station in the map carousel. Driven by user
    /// swipe + bootstrap + line-change. Persisted to UserDefaults so
    /// next session can resume.
    var selectedStation: GTFSStation? {
        didSet {
            guard oldValue?.id != selectedStation?.id else { return }
            if let id = selectedStation?.id {
                UserDefaults.standard.set(id, forKey: MapBootstrap.userDefaultsKeyLastStation)
            }
        }
    }

    /// Carousel data source: the stations on the currently-focused line.
    var stationsOnSelectedLine: [GTFSStation] {
        guard let line = selectedStation?.lineNumber else {
            return GTFSStations.stations(for: MapBootstrap.defaultSeedLine)
        }
        return GTFSStations.stations(for: line)
    }

    /// Returns the line number for a vehicle's routeId, or nil if unknown.
    /// View layer uses this to pick the right `LineColor`.
    func line(forRouteId routeId: String?) -> String? {
        guard let routeId else { return nil }
        return routeIdToLine[routeId]
    }

    var selectedLine: String? = nil {
        didSet {
            guard oldValue != selectedLine else { return }
            // User changed filter — cancel any in-flight refresh and start a
            // fresh one. Without the cancel, rapid filter toggles produce
            // concurrent fetches racing to set `vehicles` (last-write-wins,
            // and `isLoading` flickers).
            refreshTask?.cancel()
            refreshTask = Task { [weak self] in
                await self?.fetchOnce()
            }
        }
    }

    // MARK: - Polling

    private let service: RealtimeService
    private let pollInterval: Duration
    private var pollingTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(service: RealtimeService = .shared, pollInterval: Duration = .seconds(20)) {
        self.service = service
        self.pollInterval = pollInterval
    }

    /// Start the poll loop. Idempotent — calling twice doesn't spawn two loops.
    /// Also kicks off a one-shot fetch of /static/routes to populate the
    /// routeId→line index used for marker coloring.
    func startPolling() {
        guard pollingTask == nil else { return }
        Task { await self.loadRouteIndex() }
        // Capture the interval up front; the closure's `self?.pollInterval`
        // pattern would otherwise keep the loop running after self deallocates
        // (`Task.isCancelled` stays false until stopPolling explicitly runs,
        // which won't happen if the view dies without onDisappear firing).
        let interval = pollInterval
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.fetchOnce()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func loadRouteIndex() async {
        // Memoized 6h by RealtimeService; cheap to call on every startPolling.
        guard routeIdToLine.isEmpty else { return }
        do {
            let response = try await service.fetchStaticRoutes()
            routeIdToLine = response.routes.mapValues { $0.line }
        } catch {
            // Non-fatal — markers fall back to gray when index isn't loaded.
            // Don't surface this to errorMessage; the user can still see buses.
        }
    }

    /// Cancel the poll loop. Safe to call multiple times.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Pull-to-refresh entry point. Forces an immediate fetch independent of
    /// the polling cadence.
    func refresh() async {
        // Coalesce against in-flight work so pull-to-refresh during a poll
        // tick doesn't double-decode.
        refreshTask?.cancel()
        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.fetchOnce()
        }
        refreshTask = task
        await task.value
    }

    // MARK: - Private

    private func fetchOnce() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let feed = try await service.fetchVehicles(line: selectedLine)
            serviceInactive = !feed.serviceActive
            // Keep only vehicles with coordinates — annotations need them.
            vehicles = feed.vehicles.filter { $0.coordinate != nil }
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    // MARK: - Station selection (pure logic)

    /// Returns the nearest GTFSStation to `coordinate`, optionally
    /// filtered to a single line. Delegates to `GTFSStations.nearestStation(to:inLine:)`
    /// — kept as an instance method for call-site discoverability via the viewmodel
    /// and so tests don't need to know about the underlying static API.
    nonisolated func nearestStation(
        to coordinate: CLLocationCoordinate2D,
        on line: String? = nil
    ) -> GTFSStation? {
        GTFSStations.nearestStation(to: coordinate, inLine: line)
    }

    /// Returns the station on `newLine` closest to `referenceCoordinate`.
    /// Returns nil only if the line has zero stations (shouldn't happen
    /// for "1".."7"; sentinel for unknown lines).
    nonisolated func nearestStation(
        on newLine: String,
        from referenceCoordinate: CLLocationCoordinate2D
    ) -> GTFSStation? {
        nearestStation(to: referenceCoordinate, on: newLine)
    }

    // MARK: - Bootstrap

    /// Reads persisted state + supplied auth status, returns the outcome
    /// the view should render. View layer calls this once on appear and
    /// re-evaluates after authorization changes.
    func bootstrapOutcome(authStatus: LocationAuthStatus) -> BootstrapOutcome {
        let defaults = UserDefaults.standard
        let persisted = defaults.string(forKey: MapBootstrap.userDefaultsKeyLastStation)
        let shown = defaults.bool(forKey: MapBootstrap.userDefaultsKeyPrePromptShown)
        return MapBootstrap.decide(
            authStatus: authStatus,
            hasShownPrePrompt: shown,
            persistedStationId: persisted
        )
    }

    /// Resolves a station id (from persisted or seed) to an actual GTFSStation.
    /// Returns nil only if the id doesn't exist in any line.
    func resolveStation(byId id: String) -> GTFSStation? {
        for line in ["1","2","3","4","5","6","7"] {
            if let match = GTFSStations.stations(for: line).first(where: { $0.id == id }) {
                return match
            }
        }
        return nil
    }

    /// User accepted/dismissed the pre-prompt — mark as shown so we don't
    /// re-prompt next session.
    func markPrePromptShown() {
        UserDefaults.standard.set(true, forKey: MapBootstrap.userDefaultsKeyPrePromptShown)
    }
}
