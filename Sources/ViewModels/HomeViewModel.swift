import CoreLocation
import Foundation
import Observation

/// Owns the home's "Ahora" experience: the swipeable station deck, the
/// per-station arrival rows, and the home surface of the app-wide
/// RealtimePolling router (spec 2 §1; surface unification in spec 3 B3).
/// MetrobusViewModel keeps owning line status/alerts.
@MainActor
@Observable
final class HomeViewModel {

    struct DeckEntry: Identifiable {
        let station: GTFSStation
        let source: NowStationResolver.Source
        var id: String { station.id }
    }

    private(set) var deck: [DeckEntry] = []

    // MARK: - Arrivals + polling

    private(set) var arrivals: [String: ArrivalsResponse] = [:]
    /// Stations whose /arrivals call failed or came back uncovered — the UI
    /// falls back to the legacy GTFS schedule card for these.
    private(set) var legacyStations: Set<String> = []
    /// serviceId → hex colors from the cenefa dataset (row tinting).
    private(set) var serviceColors: [String: [String]] = [:]
    private(set) var commuteContext: CommuteLegContext?
    var visibleIndex: Int = 0

    private let fetchArrivals: @Sendable (String) async -> ArrivalsResponse?
    /// The app-wide polling router (single coordinator, global budget).
    /// Injectable so tests can use an isolated instance instead of `.shared`.
    private let polling: RealtimePolling
    /// Double-activation guard (mirrors RealtimeMapViewModel.isPolling):
    /// `.task` and scenePhase both fire on first appear; the second call must
    /// be a no-op so we don't burn two budget slots on identical polls.
    private var isActive = false

    init(
        fetchArrivals: @escaping @Sendable (String) async -> ArrivalsResponse? = { stopId in
            await ArrivalsService.shared.arrivals(at: stopId)
        },
        polling: RealtimePolling = .shared
    ) {
        self.fetchArrivals = fetchArrivals
        self.polling = polling
    }

    var visibleEntry: DeckEntry? {
        deck.indices.contains(visibleIndex) ? deck[visibleIndex] : nil
    }

    /// Home became visible (tab/scene active). Re-arms the loop per the
    /// coordinator contract (setSurface(nil) cancels it; reactivation must
    /// call startLoop() again). Idempotent — the second call from scenePhase
    /// while `.task` already completed is a no-op, saving a budget slot.
    func activate() async {
        guard !isActive else { return }
        guard let entry = visibleEntry else { return }
        isActive = true
        polling.homeHandler = { [weak self] stationId in
            await self?.refreshArrivals(for: stationId)
        }
        await polling.coordinator.setSurface(.home(stationId: entry.id))
        await polling.coordinator.startLoop()
        await polling.coordinator.requestImmediatePoll()
    }

    /// Home left the screen / app backgrounded (spec 4 replaces this with
    /// the background trip mode). Conditional clear: if the map tab already
    /// claimed the surface (tab-switch ordering is not guaranteed), leave it.
    func deactivate() async {
        isActive = false
        await polling.coordinator.clearSurface(where: { surface in
            if case .home = surface { return true }
            return false
        })
    }

    /// Swipe landed on a new card: re-point the surface and ask for an
    /// immediate poll — the 4/min budget absorbs frantic swiping (a denied
    /// poll just leaves the 25s-cached or skeleton state until next tick).
    func visibleCardChanged() async {
        guard let entry = visibleEntry else { return }
        await polling.coordinator.setSurface(.home(stationId: entry.id))
        await polling.coordinator.requestImmediatePoll()
    }

    func refreshArrivals(for stationId: String) async {
        guard let response = await fetchArrivals(stationId) else {
            legacyStations.insert(stationId)
            return
        }
        if response.rows.isEmpty && response.warning != nil {
            legacyStations.insert(stationId)
        } else {
            legacyStations.remove(stationId)
        }
        arrivals[stationId] = response
    }

    /// Loads the cenefa dataset (24h-cached) and indexes service colors.
    func loadServiceColors() async {
        guard let dataset = await CenefaCatalog.shared.current() else { return }
        var map: [String: [String]] = [:]
        for line in dataset.lines {
            for service in line.services {
                map[service.id] = service.style.colors
            }
        }
        serviceColors = map
    }

    /// Deck + commute-context resolution (moved from ContentView's
    /// resolveNowStation — spec 2 §1). ContentView switches to this in Task 9.
    func resolveDeck(userCoordinate: CLLocationCoordinate2D?, favoriteLines: [String]) {
        let schedule = CommuteStorage.load()
        deck = Self.resolveDeck(
            schedule: schedule,
            userCoordinate: userCoordinate,
            persistedStationId: UserDefaults.standard.string(forKey: MapBootstrap.userDefaultsKeyLastStation),
            favoriteLines: favoriteLines
        )
        if visibleIndex >= deck.count { visibleIndex = 0 }

        if case .commute(let legName) = deck.first?.source,
           let leg = legName == "ida" ? schedule.ida : schedule.regreso {
            commuteContext = CommuteLegContext(
                legName: legName,
                originId: leg.startStation.id,
                destinationId: leg.endStation.id,
                destinationName: leg.endStation.name
            )
        } else {
            commuteContext = nil
        }
    }

    /// Deck = the resolver's pick first (commute-window > nearest >
    /// last-viewed > fallback), then ida/regreso boarding stations,
    /// deduped by station id — first appearance (strongest source) wins.
    nonisolated static func resolveDeck(
        schedule: CommuteSchedule,
        userCoordinate: CLLocationCoordinate2D?,
        persistedStationId: String?,
        favoriteLines: [String],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DeckEntry] {
        var entries: [DeckEntry] = []
        if let primary = NowStationResolver.resolve(
            schedule: schedule,
            userCoordinate: userCoordinate,
            persistedStationId: persistedStationId,
            favoriteLines: favoriteLines,
            now: now,
            calendar: calendar
        ) {
            entries.append(DeckEntry(station: primary.station, source: primary.source))
        }
        let legs: [(CommuteLeg?, String)] = [(schedule.ida, "ida"), (schedule.regreso, "regreso")]
        for (candidate, name) in legs {
            guard let leg = candidate,
                  let station = GTFSStations.station(byId: leg.startStation.id),
                  !entries.contains(where: { $0.id == station.id }) else { continue }
            entries.append(DeckEntry(station: station, source: .commute(leg: name)))
        }
        return entries
    }
}

extension HomeViewModel.DeckEntry: Equatable {
    static func == (lhs: HomeViewModel.DeckEntry, rhs: HomeViewModel.DeckEntry) -> Bool {
        lhs.station.id == rhs.station.id && lhs.source == rhs.source
    }
}
