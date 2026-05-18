import Foundation
import Testing
@testable import ParabusCore

@Suite("MapBootstrap state machine")
struct MapBootstrapTests {

    @Test("notDetermined + never-shown → showPrePrompt")
    func notDeterminedNeverShown() {
        let outcome = MapBootstrap.decide(
            authStatus: .notDetermined,
            hasShownPrePrompt: false,
            persistedStationId: nil
        )
        #expect(outcome == .showPrePrompt)
    }

    @Test("notDetermined + already shown → fallback to persisted")
    func notDeterminedAlreadyShownWithPersisted() {
        let outcome = MapBootstrap.decide(
            authStatus: .notDetermined,
            hasShownPrePrompt: true,
            persistedStationId: "STATION-42"
        )
        #expect(outcome == .useStation(stationId: "STATION-42"))
    }

    @Test("authorized → waitingForLocation")
    func authorized() {
        let outcome = MapBootstrap.decide(
            authStatus: .authorized,
            hasShownPrePrompt: true,
            persistedStationId: "ANY"
        )
        #expect(outcome == .waitingForLocation)
    }

    @Test("denied + persisted → useStation(persisted)")
    func deniedWithPersisted() {
        let outcome = MapBootstrap.decide(
            authStatus: .denied,
            hasShownPrePrompt: true,
            persistedStationId: "STATION-7"
        )
        #expect(outcome == .useStation(stationId: "STATION-7"))
    }

    @Test("denied + no persisted → useStation(default seed)")
    func deniedNoPersisted() {
        let outcome = MapBootstrap.decide(
            authStatus: .denied,
            hasShownPrePrompt: true,
            persistedStationId: nil
        )
        let seedId = MapBootstrap.defaultSeedStationId()
        #expect(outcome == .useStation(stationId: seedId))
        #expect(!seedId.isEmpty) // Sanity: seed resolves to a real station.
    }

    @Test("denied + empty persisted → default seed")
    func deniedEmptyPersisted() {
        let outcome = MapBootstrap.decide(
            authStatus: .denied,
            hasShownPrePrompt: true,
            persistedStationId: ""
        )
        let seedId = MapBootstrap.defaultSeedStationId()
        #expect(outcome == .useStation(stationId: seedId))
    }
}
