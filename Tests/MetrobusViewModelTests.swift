import Foundation
import Testing
@testable import ParabusCore

@Suite("MetrobusViewModel Tests")
struct MetrobusViewModelTests {

    @Test("Loads data from cache first")
    @MainActor
    func loadsFromCacheFirst() async throws {
        // Arrange
        let cache = InMemoryCacheStorage()
        let cachedLines = [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular, affectedStations: [])
        ]
        try await cache.save(ScrapingResult(
            lines: cachedLines,
            scrapedAt: Date(),
            source: URL(string: "https://test")!
        ))

        let slowProvider = MockTransitDataProvider(delay: .seconds(2))
        let viewModel = MetrobusViewModel(dataProvider: slowProvider, cache: cache)

        // Act
        let task = Task { await viewModel.loadStatus() }
        try await Task.sleep(for: .milliseconds(100)) // Let cache load

        // Assert - should have cache data before network completes
        #expect(viewModel.lines.count == 1)
        #expect(viewModel.isLoading == true) // Still loading from network

        task.cancel()
    }

    @Test("Handles network failure gracefully with cached data")
    @MainActor
    func handlesNetworkFailureWithCache() async throws {
        // Arrange
        let cache = InMemoryCacheStorage()
        try await cache.save(ScrapingResult(
            lines: MockTransitData.lines,
            scrapedAt: Date().addingTimeInterval(-600), // 10 min old
            source: URL(string: "https://test")!
        ))

        let failingProvider = MockTransitDataProvider(shouldFail: true)
        let viewModel = MetrobusViewModel(dataProvider: failingProvider, cache: cache)

        // Act
        await viewModel.loadStatus()

        // Assert
        #expect(viewModel.lines.isEmpty == false) // Kept cached data
        #expect(viewModel.isStale == true)
        #expect(viewModel.error == nil) // No error shown when cache exists
    }

    @Test("Shows error when no cache and network fails")
    @MainActor
    func showsErrorWithoutCache() async {
        // Arrange
        let emptyCache = InMemoryCacheStorage()
        let failingProvider = MockTransitDataProvider(shouldFail: true)
        let viewModel = MetrobusViewModel(dataProvider: failingProvider, cache: emptyCache)

        // Act
        await viewModel.loadStatus()

        // Assert
        #expect(viewModel.lines.isEmpty)
        #expect(viewModel.error != nil)
    }

    @Test("Status summary shows correct message for all normal")
    @MainActor
    func statusSummaryAllNormal() async {
        // Arrange
        let normalLines = [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular, affectedStations: []),
            LineStatus(lineNumber: "2", transportType: .metrobus, status: .regular, affectedStations: [])
        ]
        let provider = MockTransitDataProvider(lines: normalLines)
        let cache = InMemoryCacheStorage()
        let viewModel = MetrobusViewModel(dataProvider: provider, cache: cache)

        // Act
        await viewModel.loadStatus()

        // Assert
        #expect(viewModel.statusSummary == "Todas las lineas operando normal")
    }

    @Test("Status summary shows incident count")
    @MainActor
    func statusSummaryWithIncidents() async {
        // Arrange
        let mixedLines = [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular, affectedStations: []),
            LineStatus(lineNumber: "2", transportType: .metrobus, status: .intervention, affectedStations: ["La Joya"]),
            LineStatus(lineNumber: "3", transportType: .metrobus, status: .suspended, affectedStations: ["Buenavista"])
        ]
        let provider = MockTransitDataProvider(lines: mixedLines)
        let cache = InMemoryCacheStorage()
        let viewModel = MetrobusViewModel(dataProvider: provider, cache: cache)

        // Act
        await viewModel.loadStatus()

        // Assert
        #expect(viewModel.statusSummary == "2 lineas con incidentes")
    }

    @Test("Lines are sorted by line number")
    @MainActor
    func linesSortedByNumber() async {
        // Arrange
        let unsortedLines = [
            LineStatus(lineNumber: "3", transportType: .metrobus, status: .regular, affectedStations: []),
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular, affectedStations: []),
            LineStatus(lineNumber: "2", transportType: .metrobus, status: .regular, affectedStations: [])
        ]
        let provider = MockTransitDataProvider(lines: unsortedLines)
        let cache = InMemoryCacheStorage()
        let viewModel = MetrobusViewModel(dataProvider: provider, cache: cache)

        // Act
        await viewModel.loadStatus()

        // Assert
        #expect(viewModel.lines.map(\.lineNumber) == ["1", "2", "3"])
    }

    @Test("Refresh updates stale flag")
    @MainActor
    func refreshClearsStaleFlag() async {
        // Arrange
        let provider = MockTransitDataProvider()
        let cache = InMemoryCacheStorage()
        let viewModel = MetrobusViewModel(dataProvider: provider, cache: cache)

        // Act
        await viewModel.loadStatus()

        // Assert
        #expect(viewModel.isStale == false)
        #expect(viewModel.lastUpdated != nil)
    }

    @Test("Clear error resets error state")
    @MainActor
    func clearErrorResetsState() async {
        // Arrange
        let failingProvider = MockTransitDataProvider(shouldFail: true)
        let cache = InMemoryCacheStorage()
        let viewModel = MetrobusViewModel(dataProvider: failingProvider, cache: cache)

        await viewModel.loadStatus()
        #expect(viewModel.error != nil)

        // Act
        viewModel.clearError()

        // Assert
        #expect(viewModel.error == nil)
    }
}
