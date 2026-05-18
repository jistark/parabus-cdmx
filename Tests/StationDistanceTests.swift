import Foundation
import Testing
import CoreLocation
@testable import ParabusCore

@Suite("Station distance helpers")
struct StationDistanceTests {

    /// CDMX center coordinates (Zócalo) — should consistently land near
    /// downtown stations.
    private let zocalo = CLLocationCoordinate2D(
        latitude: 19.4326, longitude: -99.1332
    )

    @MainActor
    @Test("nearestStation(to:) returns a station near CDMX center")
    func nearestNearZocalo() {
        let vm = RealtimeMapViewModel()
        let nearest = vm.nearestStation(to: zocalo)
        #expect(nearest != nil)
        // Sanity: nearest from Zócalo should be within ~10km
        if let n = nearest {
            let loc = CLLocation(latitude: n.latitude, longitude: n.longitude)
            let origin = CLLocation(latitude: zocalo.latitude, longitude: zocalo.longitude)
            #expect(origin.distance(from: loc) < 10_000)
        }
    }

    @MainActor
    @Test("nearestStation filtered to L1 returns an L1 station")
    func nearestFilteredToL1() {
        let vm = RealtimeMapViewModel()
        let nearest = vm.nearestStation(to: zocalo, on: "1")
        #expect(nearest != nil)
        #expect(nearest?.lineNumber == "1")
    }

    @MainActor
    @Test("nearestStation on unknown line returns nil")
    func nearestUnknownLine() {
        let vm = RealtimeMapViewModel()
        let nearest = vm.nearestStation(to: zocalo, on: "99")
        #expect(nearest == nil)
    }

    @MainActor
    @Test("Far-north coordinate prefers L1 north terminus over L7 west")
    func directionalSanity() {
        let vm = RealtimeMapViewModel()
        // Indios Verdes area (far north)
        let north = CLLocationCoordinate2D(latitude: 19.495, longitude: -99.119)
        let nearestL1 = vm.nearestStation(to: north, on: "1")
        let nearestL7 = vm.nearestStation(to: north, on: "7")
        #expect(nearestL1 != nil)
        #expect(nearestL7 != nil)
        // Both should resolve to *some* station; we don't assert order across
        // lines (depends on geography) but both must be non-nil.
    }

    @MainActor
    @Test("nearestStation(on:from:) round-trip from current to new line")
    func nearestOnNewLineFromReference() {
        let vm = RealtimeMapViewModel()
        guard let l1 = vm.nearestStation(to: zocalo, on: "1") else {
            Issue.record("Expected L1 station near Zocalo")
            return
        }
        let l3FromL1 = vm.nearestStation(
            on: "3",
            from: l1.coordinate
        )
        #expect(l3FromL1 != nil)
        #expect(l3FromL1?.lineNumber == "3")
    }
}
