import CoreLocation
import Foundation
import Observation

/// Owns the home's "Ahora" experience: the swipeable station deck, the
/// per-station arrival rows, and ALL contact with RealtimePollingCoordinator
/// (spec 2 §1). MetrobusViewModel keeps owning line status/alerts.
@MainActor
@Observable
final class HomeViewModel {

    struct DeckEntry: Identifiable {
        let station: GTFSStation
        let source: NowStationResolver.Source
        var id: String { station.id }
    }

    private(set) var deck: [DeckEntry] = []

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
