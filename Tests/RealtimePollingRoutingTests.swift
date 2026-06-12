// Tests/RealtimePollingRoutingTests.swift
import Foundation
import Testing
@testable import ParabusCore

/// Spec 3 B3: ONE coordinator app-wide, surfaces routed to whoever owns
/// them, and a budget that is global — not per-screen.
@Suite("Realtime polling routing")
@MainActor
struct RealtimePollingRoutingTests {

    /// MainActor recorder for handler invocations.
    @MainActor
    final class Routes {
        var home: [String] = []
        var map: [String?] = []
        var total: Int { home.count + map.count }
    }

    /// Manual clock shared with the router's coordinator.
    final class Clock: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 4_000_000)
    }

    private func makeRouter(clock: Clock = Clock()) -> (RealtimePolling, Routes) {
        let polling = RealtimePolling(now: { clock.now })
        let routes = Routes()
        polling.homeHandler = { routes.home.append($0) }
        polling.mapHandler = { routes.map.append($0) }
        return (polling, routes)
    }

    @Test func homeSurfaceHitsHomeHandlerOnly() async {
        let (polling, routes) = makeRouter()
        await polling.coordinator.setSurface(.home(stationId: "A1"))
        await polling.coordinator.tick()
        #expect(routes.home == ["A1"])
        #expect(routes.map.isEmpty)
    }

    @Test func mapSurfaceHitsMapHandlerOnly() async {
        let (polling, routes) = makeRouter()
        await polling.coordinator.setSurface(.map(line: "3"))
        await polling.coordinator.tick()
        #expect(routes.map == ["3"])
        #expect(routes.home.isEmpty)
    }

    @Test func budgetIsSharedAcrossSurfaces() async {
        // 4 mixed home+map polls consume the ONE sliding window: the 5th
        // and 6th are dropped regardless of which surface asks.
        let clock = Clock()
        let (polling, routes) = makeRouter(clock: clock)
        await polling.coordinator.setSurface(.home(stationId: "A1"))
        await polling.coordinator.requestImmediatePoll()
        clock.now += 1
        await polling.coordinator.requestImmediatePoll()
        clock.now += 1
        await polling.coordinator.setSurface(.map(line: "2"))
        await polling.coordinator.requestImmediatePoll()
        clock.now += 1
        await polling.coordinator.requestImmediatePoll()
        clock.now += 1
        await polling.coordinator.requestImmediatePoll() // 5th — over budget
        await polling.coordinator.tick()                 // 6th — still over
        #expect(routes.home == ["A1", "A1"])
        #expect(routes.map == ["2", "2"])
        #expect(routes.total == 4)

        clock.now += 61 // window slides past the burst
        await polling.coordinator.tick()
        #expect(routes.total == 5)
    }

    @Test func conditionalClearOnlyReleasesTheMatchingSurface() async {
        // Tab-switch handoff: the outgoing tab's teardown (clear .home) must
        // not clobber a surface the incoming tab already claimed (.map).
        let (polling, routes) = makeRouter()
        await polling.coordinator.setSurface(.map(line: nil))
        await polling.coordinator.clearSurface(where: { surface in
            if case .home = surface { return true }
            return false
        })
        await polling.coordinator.tick()
        #expect(routes.map.count == 1, "home's clear must not release the map surface")

        await polling.coordinator.clearSurface(where: { surface in
            if case .map = surface { return true }
            return false
        })
        await polling.coordinator.tick()
        #expect(routes.total == 1, "matching clear releases the surface — no further polls")
    }

    @Test func backgroundSurfaceHasNoHandlerYet() async {
        // Spec 4 hook: routing a .background surface is a defined no-op.
        let (polling, routes) = makeRouter()
        await polling.coordinator.setSurface(.background(tripContext: "trip-1"))
        await polling.coordinator.tick()
        #expect(routes.total == 0)
    }
}
