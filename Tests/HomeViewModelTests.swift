import CoreLocation
import Foundation
import Testing
@testable import ParabusCore

@Suite("Home deck resolution")
struct HomeDeckTests {

    private var l1: [GTFSStation] { GTFSStations.stations(for: "1") }

    /// Builds a CommuteLeg for the given hour/minute (today's date is used only
    /// as a carrier; NowStationResolver extracts .hour / .minute from it).
    private func legTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    /// Ida 8:00 from `ida`, regreso 18:00 from `regreso`.
    /// `offWindow` (Tue 3 AM) keeps both legs out of any commute window.
    private func schedule(idaFrom ida: GTFSStation, regresoFrom regreso: GTFSStation) -> CommuteSchedule {
        let idaLeg = CommuteLeg(
            startStation: CommuteStation(id: ida.id, name: ida.name, lineNumber: ida.lineNumber),
            endStation:   CommuteStation(id: regreso.id, name: regreso.name, lineNumber: regreso.lineNumber),
            time: legTime(hour: 8, minute: 0),
            isEnabled: true
        )
        let regresoLeg = CommuteLeg(
            startStation: CommuteStation(id: regreso.id, name: regreso.name, lineNumber: regreso.lineNumber),
            endStation:   CommuteStation(id: ida.id, name: ida.name, lineNumber: ida.lineNumber),
            time: legTime(hour: 18, minute: 0),
            isEnabled: true
        )
        return CommuteSchedule(
            ida: idaLeg,
            regreso: regresoLeg,
            activeDays: Set(Weekday.weekdays),
            notifyBeforeMinutes: 60
        )
    }

    /// Tuesday 2026-06-09 03:00 — safely outside every commute window in
    /// the fixture schedules (ida 8:00, regreso 18:00, notify lead 60 min).
    private let offWindow = DateComponents(
        calendar: .current, year: 2026, month: 6, day: 9, hour: 3
    ).date!

    // MARK: - Tests

    @Test func deckIsPrimaryPlusCommuteLegsDeduped() {
        // l1[5]  = Buenavista L1   (id: "fa0784") — ida boarding
        // l1[20] = Colonia del Valle (id: "fa0798") — regreso boarding
        // l1[10] = CCU              (id: "fa07a7") — GPS fix (far south, isolated)
        let ida = l1[5]
        let regreso = l1[20]
        let gpsAnchor = l1[10]

        let s = schedule(idaFrom: ida, regresoFrom: regreso)
        let deck = HomeViewModel.resolveDeck(
            schedule: s,
            userCoordinate: gpsAnchor.coordinate,
            persistedStationId: nil,
            favoriteLines: ["1"],
            now: offWindow
        )

        // Nearest to CCU is CCU itself (or the co-located C.C Universitario —
        // both are distinct from the commute legs). We assert .nearest and
        // verify it is neither the ida nor the regreso station.
        #expect(deck.count == 3)
        #expect(deck[0].source == .nearest)
        #expect(deck[0].station.id != ida.id)
        #expect(deck[0].station.id != regreso.id)
        #expect(deck[1] == HomeViewModel.DeckEntry(station: ida, source: .commute(leg: "ida")))
        #expect(deck[2] == HomeViewModel.DeckEntry(station: regreso, source: .commute(leg: "regreso")))
    }

    @Test func dedupesWhenNearestIsTheIdaStation() {
        // GPS fix exactly on l1[5] (Buenavista L1) — should match the ida leg.
        // Nearest search across all lines returns Buenavista L1 (it's closest
        // to its own coordinate at 0 m; next nearest is ~139 m away).
        let ida = l1[5]
        let regreso = l1[20]

        let s = schedule(idaFrom: ida, regresoFrom: regreso)
        let deck = HomeViewModel.resolveDeck(
            schedule: s,
            userCoordinate: ida.coordinate,
            persistedStationId: nil,
            favoriteLines: ["1"],
            now: offWindow
        )

        // Deck should collapse ida from 3→2 (nearest wins the slot).
        #expect(deck.count == 2)
        #expect(deck[0].station.id == ida.id)  // first appearance keeps .nearest
        #expect(deck[0].source == .nearest)
        #expect(deck[1].station.id == regreso.id)
    }

    @Test func noCommuteMeansSingleCard() {
        let deck = HomeViewModel.resolveDeck(
            schedule: CommuteSchedule(),
            userCoordinate: l1[10].coordinate,
            persistedStationId: nil,
            favoriteLines: ["1"],
            now: offWindow
        )
        #expect(deck.count == 1)
    }

    @Test func noSignalsFallsBackToFavoriteLine() {
        let deck = HomeViewModel.resolveDeck(
            schedule: CommuteSchedule(),
            userCoordinate: nil,
            persistedStationId: nil,
            favoriteLines: ["3"],
            now: offWindow
        )
        #expect(deck.count == 1)
        #expect(deck[0].source == .fallback)
        #expect(deck[0].station.lineNumber == "3")
    }
}

@Suite("Home arrivals + legacy fallback")
@MainActor
struct HomeArrivalsTests {

    /// ArrivalsResponse is Decodable-only — build via JSON.
    nonisolated private static func response(rows: [(state: String, source: String)], warning: String? = nil) -> ArrivalsResponse {
        let rowsJSON = rows.map {
            """
            {"serviceId":"s","line":"1","destination":"d","state":"\($0.state)","etaMinutes":null,"vehicleId":null,"source":"\($0.source)"}
            """
        }.joined(separator: ",")
        let json = """
        {"serviceActive":true,"feedTimestamp":1,"feedAgeSeconds":1,"realtimeStale":false,"stop":"X",\(warning.map { "\"warning\":\"\($0)\"," } ?? "")"rows":[\(rowsJSON)]}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(ArrivalsResponse.self, from: json)
    }

    @Test func publishesArrivalsOnRefresh() async {
        let vm = HomeViewModel(fetchArrivals: { _ in Self.response(rows: [("arriving", "realtime")]) })
        await vm.refreshArrivals(for: "ST1")
        #expect(vm.arrivals["ST1"]?.rows.count == 1)
        #expect(!vm.legacyStations.contains("ST1"))
    }

    @Test func emptyRowsWithWarningEntersLegacy() async {
        let vm = HomeViewModel(fetchArrivals: { _ in Self.response(rows: [], warning: "stop not covered") })
        await vm.refreshArrivals(for: "ST1")
        #expect(vm.legacyStations.contains("ST1"))
    }

    @Test func nilResponseEntersLegacyAndRecovers() async {
        let gate = FailGate()
        let vm = HomeViewModel(fetchArrivals: { _ in
            await gate.shouldFail ? nil : Self.response(rows: [("arriving", "realtime")])
        })
        await vm.refreshArrivals(for: "ST1")
        #expect(vm.legacyStations.contains("ST1"))
        await gate.setShouldFail(false)
        await vm.refreshArrivals(for: "ST1")
        #expect(!vm.legacyStations.contains("ST1"))
        #expect(vm.arrivals["ST1"] != nil)
    }

    @Test func visibleEntryClampsToDeckBounds() {
        let vm = HomeViewModel(fetchArrivals: { _ in nil })
        #expect(vm.visibleEntry == nil) // empty deck
    }
}

/// Sendable mutable flag for the recovery test (closures must be @Sendable).
private actor FailGate {
    var shouldFail = true
    func setShouldFail(_ value: Bool) { shouldFail = value }
}
