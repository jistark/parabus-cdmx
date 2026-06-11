// Tests/RealtimePollingCoordinatorTests.swift
import Foundation
import Testing
@testable import ParabusCore

@Suite("Realtime polling coordinator")
struct RealtimePollingCoordinatorTests {

    /// Test double: records polls, lets the test advance a manual clock.
    final class Recorder: @unchecked Sendable {
        var polls: [RealtimeSurface] = []
        var now = Date(timeIntervalSince1970: 3_000_000)
    }

    private func makeCoordinator(_ recorder: Recorder) -> RealtimePollingCoordinator {
        RealtimePollingCoordinator(
            now: { recorder.now },
            onPoll: { surface in recorder.polls.append(surface) }
        )
    }

    @Test func tickPollsTheActiveSurfaceOnly() async {
        let recorder = Recorder()
        let coordinator = makeCoordinator(recorder)
        await coordinator.setSurface(.home(stationId: "A1"))
        await coordinator.tick()
        #expect(recorder.polls == [.home(stationId: "A1")])
    }

    @Test func noSurfaceMeansNoPolling() async {
        let recorder = Recorder()
        let coordinator = makeCoordinator(recorder)
        await coordinator.tick()
        #expect(recorder.polls.isEmpty)
    }

    @Test func switchingSurfaceReplacesNotAdds() async {
        let recorder = Recorder()
        let coordinator = makeCoordinator(recorder)
        await coordinator.setSurface(.home(stationId: "A1"))
        await coordinator.tick()
        recorder.now += 25
        await coordinator.setSurface(.map(line: "2"))
        await coordinator.tick()
        #expect(recorder.polls == [.home(stationId: "A1"), .map(line: "2")])
    }

    @Test func backgroundStopsPolling() async {
        let recorder = Recorder()
        let coordinator = makeCoordinator(recorder)
        await coordinator.setSurface(.home(stationId: "A1"))
        await coordinator.setSurface(nil) // scenePhase != active
        await coordinator.tick()
        #expect(recorder.polls.isEmpty)
    }

    @Test func budgetCapsAtFourPerMinute() async {
        let recorder = Recorder()
        let coordinator = makeCoordinator(recorder)
        await coordinator.setSurface(.home(stationId: "A1"))
        for _ in 0..<6 { // 6 rapid requests (e.g. frantic swiping)
            await coordinator.requestImmediatePoll()
            recorder.now += 1
        }
        #expect(recorder.polls.count == 4)
    }

    @Test func budgetWindowSlides() async {
        let recorder = Recorder()
        let coordinator = makeCoordinator(recorder)
        await coordinator.setSurface(.home(stationId: "A1"))
        for _ in 0..<4 {
            await coordinator.requestImmediatePoll()
            recorder.now += 1
        }
        recorder.now += 61 // window slides past the burst
        await coordinator.requestImmediatePoll()
        #expect(recorder.polls.count == 5)
    }

    @Test func swipeRetargetsTheHomeSurface() async {
        let recorder = Recorder()
        let coordinator = makeCoordinator(recorder)
        await coordinator.setSurface(.home(stationId: "A1"))
        await coordinator.setSurface(.home(stationId: "B7")) // swipe to favorite
        await coordinator.tick()
        #expect(recorder.polls == [.home(stationId: "B7")])
    }
}
