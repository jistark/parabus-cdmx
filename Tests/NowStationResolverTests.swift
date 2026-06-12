import CoreLocation
import Foundation
import Testing
@testable import ParabusCore

@Suite("NowStationResolver Tests")
struct NowStationResolverTests {

    /// Fixed gregorian calendar in CDMX so results don't depend on the host.
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Mexico_City")!
        return c
    }

    /// Monday 2026-06-08 at the given local time.
    private func monday(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 6, day: 8, hour: hour, minute: minute
        ))!
    }

    private var l1First: GTFSStation { GTFSStations.stations(for: "1").first! }
    private var l3First: GTFSStation { GTFSStations.stations(for: "3").first! }

    private func commuteSchedule(idaHour: Int, idaMinute: Int, station: GTFSStation) -> CommuteSchedule {
        let origin = CommuteStation(
            id: station.id, name: station.name, lineNumber: station.lineNumber
        )
        let destination = CommuteStation(id: "dest", name: "Destino", lineNumber: station.lineNumber)
        let time = Calendar.current.date(
            bySettingHour: idaHour, minute: idaMinute, second: 0, of: Date()
        )!
        return CommuteSchedule(
            ida: CommuteLeg(startStation: origin, endStation: destination, time: time),
            activeDays: Set(Weekday.weekdays),
            notifyBeforeMinutes: 60
        )
    }

    @Test("Inside the commute window → the leg's boarding station wins over GPS")
    func commuteWindowBeatsGPS() {
        let schedule = commuteSchedule(idaHour: 7, idaMinute: 30, station: l3First)
        // GPS sits right on top of an L1 station — would win without the window.
        let result = NowStationResolver.resolve(
            schedule: schedule,
            userCoordinate: l1First.coordinate,
            persistedStationId: nil,
            favoriteLines: ["1"],
            now: monday(7, 0),
            calendar: calendar
        )
        #expect(result?.station.id == l3First.id)
        #expect(result?.source == .commute(leg: "ida"))
    }

    @Test("Outside the window, GPS nearest wins")
    func gpsWinsOutsideWindow() {
        let schedule = commuteSchedule(idaHour: 7, idaMinute: 30, station: l3First)
        let result = NowStationResolver.resolve(
            schedule: schedule,
            userCoordinate: l1First.coordinate,
            persistedStationId: l3First.id,
            favoriteLines: ["3"],
            now: monday(12, 0),
            calendar: calendar
        )
        #expect(result?.station.id == l1First.id)
        #expect(result?.source == .nearest)
    }

    @Test("No GPS → last viewed map station")
    func persistedWinsWithoutGPS() {
        let result = NowStationResolver.resolve(
            schedule: CommuteSchedule(),
            userCoordinate: nil,
            persistedStationId: l3First.id,
            favoriteLines: ["1"],
            now: monday(12, 0),
            calendar: calendar
        )
        #expect(result?.station.id == l3First.id)
        #expect(result?.source == .lastViewed)
    }

    @Test("No signal at all → first favorite line's first station")
    func fallbackToFavorites() {
        let result = NowStationResolver.resolve(
            schedule: CommuteSchedule(),
            userCoordinate: nil,
            persistedStationId: nil,
            favoriteLines: ["3", "1"],
            now: monday(12, 0),
            calendar: calendar
        )
        #expect(result?.station.lineNumber == "3")
        #expect(result?.source == .fallback)
    }

    @Test("Commute leg with a stale station id falls through to GPS")
    func staleCommuteStationFallsThrough() {
        var schedule = commuteSchedule(idaHour: 7, idaMinute: 30, station: l3First)
        schedule.ida = CommuteLeg(
            startStation: CommuteStation(id: "no-such-id", name: "Vieja", lineNumber: "9"),
            endStation: CommuteStation(id: "dest", name: "Destino", lineNumber: "9"),
            time: schedule.ida!.time
        )
        let result = NowStationResolver.resolve(
            schedule: schedule,
            userCoordinate: l1First.coordinate,
            persistedStationId: nil,
            favoriteLines: ["1"],
            now: monday(7, 0),
            calendar: calendar
        )
        #expect(result?.source == .nearest)
    }
}
