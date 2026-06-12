import Foundation
import Testing
@testable import ParabusCore

@Suite("RefreshPolicy Tests")
struct RefreshPolicyTests {

    // MARK: - staleAfterFailure

    @Test("nil lastUpdated → stale (no data ever loaded)")
    func nilLastUpdatedIsStale() {
        #expect(MetrobusViewModel.staleAfterFailure(lastUpdated: nil) == true)
    }

    @Test("5 min old data → not stale after failure")
    func fiveMinOldIsNotStale() {
        let now = Date()
        let fiveMinAgo = now.addingTimeInterval(-5 * 60)
        #expect(MetrobusViewModel.staleAfterFailure(lastUpdated: fiveMinAgo, now: now) == false)
    }

    @Test("11 min old data → stale after failure")
    func elevenMinOldIsStale() {
        let now = Date()
        let elevenMinAgo = now.addingTimeInterval(-11 * 60)
        #expect(MetrobusViewModel.staleAfterFailure(lastUpdated: elevenMinAgo, now: now) == true)
    }

    @Test("Exactly 10 min old data → not stale (boundary: > 10 min threshold)")
    func exactlyTenMinIsNotStale() {
        let now = Date()
        let tenMinAgo = now.addingTimeInterval(-10 * 60)
        #expect(MetrobusViewModel.staleAfterFailure(lastUpdated: tenMinAgo, now: now) == false)
    }

    @Test("Just over 10 min old → stale")
    func justOverTenMinIsStale() {
        let now = Date()
        let justOver = now.addingTimeInterval(-(10 * 60 + 1))
        #expect(MetrobusViewModel.staleAfterFailure(lastUpdated: justOver, now: now) == true)
    }

    // MARK: - refreshFailed flag integration

    @Test("refreshFailed is false before any fetch")
    @MainActor
    func refreshFailedInitiallyFalse() {
        let vm = MetrobusViewModel(
            dataProvider: MockTransitDataProvider(),
            cache: InMemoryCacheStorage()
        )
        #expect(vm.refreshFailed == false)
    }

    @Test("refreshFailed is true after a network error")
    @MainActor
    func refreshFailedSetOnError() async {
        let vm = MetrobusViewModel(
            dataProvider: MockTransitDataProvider(shouldFail: true),
            cache: InMemoryCacheStorage()
        )
        await vm.refresh()
        #expect(vm.refreshFailed == true)
    }

    @Test("refreshFailed is cleared on success")
    @MainActor
    func refreshFailedClearedOnSuccess() async {
        let failProvider = MockTransitDataProvider(shouldFail: true)
        let vm = MetrobusViewModel(
            dataProvider: failProvider,
            cache: InMemoryCacheStorage()
        )
        // First call: failure
        await vm.refresh()
        #expect(vm.refreshFailed == true)

        // Second call: success (swap provider via a fresh VM to keep isolation)
        let successVM = MetrobusViewModel(
            dataProvider: MockTransitDataProvider(lines: MockTransitData.lines, closures: []),
            cache: InMemoryCacheStorage()
        )
        await successVM.refresh()
        #expect(successVM.refreshFailed == false)
    }

    @Test("isStale not set when fresh data exists and refresh fails")
    @MainActor
    func isStaleNotSetWhenDataIsFresh() async throws {
        let cache = InMemoryCacheStorage()
        // Save cache that is only 2 minutes old
        try await cache.save(ScrapingResult(
            lines: MockTransitData.lines,
            scrapedAt: Date().addingTimeInterval(-2 * 60),
            source: URL(string: "https://test")!
        ))

        let vm = MetrobusViewModel(
            dataProvider: MockTransitDataProvider(shouldFail: true),
            cache: cache
        )
        await vm.loadStatus()   // loads cache → lastUpdated is ~2 min ago
        // Simulate a second explicit refresh that fails
        let failVM = MetrobusViewModel(
            dataProvider: MockTransitDataProvider(shouldFail: true),
            cache: cache
        )
        await failVM.loadStatus()
        // lastUpdated from cache is only 2 min old → should NOT be stale
        #expect(failVM.isStale == false)
    }
}
