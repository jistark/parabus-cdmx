import CoreLocation
import Foundation

/// Picks which station the home "Ahora" card shows. Pure logic — testable
/// without GPS, UserDefaults, or UI. The priority chain is the product
/// maxim ("deliver the info the user needs when they need it") made code:
///
///   1. Commute window → the leg's boarding station. You're about to ride;
///      nothing beats "when does my bus leave".
///   2. GPS fix → nearest station. You're somewhere in the city; this is
///      your stop.
///   3. Last station focused on the map — explicit past intent.
///   4. First favorite line's first station — better than an empty card.
///
/// Window math mirrors `CommuteRefreshPlanner` (lead = notifyBeforeMinutes,
/// hot until 60 min after departure) so the card and the background refresh
/// agree on what "commute time" means.
enum NowStationResolver {

    enum Source: Equatable {
        /// Inside a commute window; payload is the leg ("ida"/"regreso").
        case commute(leg: String)
        /// Nearest to the user's GPS fix.
        case nearest
        /// The station last focused on the live map.
        case lastViewed
        /// No signal at all — first station of the first favorite line.
        case fallback
    }

    /// How long after departure the commute window stays hot.
    static let postDepartureWindow = 60

    static func resolve(
        schedule: CommuteSchedule,
        userCoordinate: CLLocationCoordinate2D?,
        persistedStationId: String?,
        favoriteLines: [String],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (station: GTFSStation, source: Source)? {
        // 1. Commute window (re-implemented with injected now/calendar —
        //    CommuteSchedule.isWithinCommuteWindow reads the wall clock).
        if let weekday = Weekday(rawValue: calendar.component(.weekday, from: now)),
           schedule.activeDays.contains(weekday) {
            let nowMinutes = calendar.component(.hour, from: now) * 60
                + calendar.component(.minute, from: now)
            let legs: [(CommuteLeg?, String)] = [(schedule.ida, "ida"), (schedule.regreso, "regreso")]
            for (candidate, name) in legs {
                guard let leg = candidate, leg.isEnabled else { continue }
                let departure = leg.hour * 60 + leg.minute
                let windowStart = departure - schedule.notifyBeforeMinutes
                let windowEnd = departure + Self.postDepartureWindow
                if nowMinutes >= windowStart, nowMinutes <= windowEnd,
                   let station = GTFSStations.station(byId: leg.startStation.id) {
                    return (station, .commute(leg: name))
                }
            }
        }

        // 2. GPS nearest
        if let coordinate = userCoordinate,
           let nearest = GTFSStations.nearestStation(to: coordinate, inLine: nil) {
            return (nearest, .nearest)
        }

        // 3. Last station the user focused on the map
        if let id = persistedStationId, let station = GTFSStations.station(byId: id) {
            return (station, .lastViewed)
        }

        // 4. First favorite line (or L1) as a last resort
        let line = favoriteLines.first ?? "1"
        if let station = GTFSStations.stations(for: line).first {
            return (station, .fallback)
        }
        return GTFSStations.stations(for: "1").first.map { ($0, .fallback) }
    }
}
