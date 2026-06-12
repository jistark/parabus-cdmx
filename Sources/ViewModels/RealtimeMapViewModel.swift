import CoreLocation
import Foundation
import Observation
import SwiftUI

/// Backing state for the realtime map. While the view is visible it owns the
/// `.map` surface of the app-wide RealtimePolling router, so /vehicles is
/// fetched on the coordinator's 25s cadence under the global 4 req/min
/// budget (spec 3 B3 — previously a private 20s loop; the slight slowdown
/// keeps the budget contract honest and still rides the worker's Cache-API
/// TTL + cron pre-warm, so requests stay cheap).
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
            // Keep the server-side filter in sync with the focused station:
            // /vehicles?line=N returns ~1/7th of the network instead of all
            // ~800 buses (cheaper for the worker, lighter for MapKit).
            // selectedLine.didSet cancels any in-flight fetch and refetches.
            if let line = selectedStation?.lineNumber, line != selectedLine {
                selectedLine = line
            }
        }
    }

    /// Radius around the selected station within which buses render.
    /// Matches the camera span (0.04° ≈ 4.4 km tall) so everything drawn
    /// is on or near the visible viewport.
    static let nearbyRadiusMeters: CLLocationDistance = 3000

    /// Vehicles to draw on the map: the (already line-filtered) feed,
    /// narrowed to those near the focused station. The user's mental model
    /// is "what's coming to MY station" — not the whole line at once.
    /// Falls back to the full feed before any station is selected.
    var visibleVehicles: [VehiclePosition] {
        guard let center = selectedStation?.coordinate else { return vehicles }
        return Self.vehicles(vehicles, near: center, radius: Self.nearbyRadiusMeters)
    }

    /// Pure helper (testable without the actor): vehicles within `radius`
    /// meters of `center`. Vehicles without coordinates are dropped.
    nonisolated static func vehicles(
        _ vehicles: [VehiclePosition],
        near center: CLLocationCoordinate2D,
        radius: CLLocationDistance
    ) -> [VehiclePosition] {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return vehicles.filter { vehicle in
            guard let coord = vehicle.coordinate else { return false }
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return location.distance(from: centerLocation) <= radius
        }
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
            guard isPolling else { return }
            // User changed filter — re-point the surface at the new line and
            // ask the coordinator for an immediate poll (budget-gated; a
            // denied poll leaves the previous frame until the next 25s tick).
            // Cancel any in-flight refresh so rapid filter toggles don't race
            // to set `vehicles` (last-write-wins, `isLoading` flickers).
            refreshTask?.cancel()
            refreshTask = Task { [weak self] in
                // The cancellation check matters: if stopPolling ran before
                // this task got scheduled, re-setting the surface here would
                // resurrect `.map` and steal polling from the incoming tab.
                guard let self, !Task.isCancelled else { return }
                await self.polling.coordinator.setSurface(.map(line: self.selectedLine))
                await self.polling.coordinator.requestImmediatePoll()
            }
        }
    }

    // MARK: - Polling

    private let service: RealtimeService
    /// The app-wide polling router (single coordinator, global budget).
    /// Injectable so tests can use an isolated instance instead of `.shared`.
    private let polling: RealtimePolling
    /// True between startPolling/stopPolling — keeps double-starts (.task +
    /// scenePhase both fire on first appear) from burning budget.
    private var isPolling = false
    private var refreshTask: Task<Void, Never>?

    init(service: RealtimeService = .shared, polling: RealtimePolling = .shared) {
        self.service = service
        self.polling = polling
    }

    /// Claim the `.map` surface and start the coordinator loop. Idempotent —
    /// calling twice doesn't re-claim or double-poll. Also kicks off a
    /// one-shot fetch of /static/routes to populate the routeId→line index
    /// used for marker coloring.
    func startPolling() async {
        guard !isPolling else { return }
        isPolling = true
        Task { await self.loadRouteIndex() }
        polling.mapHandler = { [weak self] _ in
            // The surface's line is advisory — fetch with the CURRENT
            // selectedLine so a poll racing a filter change can't render
            // the stale line.
            await self?.fetchOnce()
        }
        await polling.coordinator.setSurface(.map(line: selectedLine))
        await polling.coordinator.startLoop()
        await polling.coordinator.requestImmediatePoll()
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

    /// Release the `.map` surface. Safe to call multiple times. The clear is
    /// conditional: on a tab switch the incoming tab may have already claimed
    /// the surface (SwiftUI's onDisappear ordering is not guaranteed), and we
    /// must not clobber it.
    func stopPolling() async {
        isPolling = false
        refreshTask?.cancel()
        refreshTask = nil
        await polling.coordinator.clearSurface(where: { surface in
            if case .map = surface { return true }
            return false
        })
    }

    /// Pull-to-refresh entry point. Forces an immediate fetch independent of
    /// the polling cadence — an explicit user gesture stays out-of-band of
    /// the 4/min polling budget (same behavior as before B3).
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
        GTFSStations.station(byId: id)
    }

    /// User accepted/dismissed the pre-prompt — mark as shown so we don't
    /// re-prompt next session.
    func markPrePromptShown() {
        UserDefaults.standard.set(true, forKey: MapBootstrap.userDefaultsKeyPrePromptShown)
    }
}
