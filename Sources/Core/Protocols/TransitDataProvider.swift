import Foundation

/// Protocol for fetching transit status data
/// Enables mocking in tests and previews
protocol TransitDataProviding: Sendable {
    func fetchStatus() async throws -> ScrapingResult
    func fetchStatus(forceRefresh: Bool) async throws -> ScrapingResult
    func fetchStatus(forLine lineNumber: String) async throws -> LineStatus?
    func fetchMaintenanceClosures() async throws -> MaintenanceResult
}

// MARK: - Default Implementation

extension TransitDataProviding {
    /// Default implementation: forceRefresh has no effect for scrapers
    func fetchStatus(forceRefresh: Bool) async throws -> ScrapingResult {
        try await fetchStatus()
    }
}

// MARK: - MetrobusScraper Conformance

extension MetrobusScraper: TransitDataProviding {}

// MARK: - Mock Implementation for Previews/Tests

#if DEBUG
actor MockTransitDataProvider: TransitDataProviding {
    private let mockLines: [LineStatus]
    private let mockClosures: [ScheduledClosure]
    private let shouldFail: Bool
    private let delay: Duration

    init(
        lines: [LineStatus] = MetrobusScraper.mockData,
        closures: [ScheduledClosure] = MetrobusScraper.mockMaintenanceData,
        shouldFail: Bool = false,
        delay: Duration = .zero
    ) {
        self.mockLines = lines
        self.mockClosures = closures
        self.shouldFail = shouldFail
        self.delay = delay
    }

    func fetchStatus() async throws -> ScrapingResult {
        if delay != .zero {
            try await Task.sleep(for: delay)
        }

        if shouldFail {
            throw ScraperError.networkError(
                NSError(domain: "Mock", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Simulated network failure"
                ])
            )
        }

        return ScrapingResult(
            lines: mockLines,
            scrapedAt: Date(),
            source: URL(string: "https://mock.test")!
        )
    }

    func fetchStatus(forLine lineNumber: String) async throws -> LineStatus? {
        let result = try await fetchStatus()
        return result.lines.first { $0.lineNumber == lineNumber }
    }

    func fetchMaintenanceClosures() async throws -> MaintenanceResult {
        if shouldFail {
            throw ScraperError.networkError(
                NSError(domain: "Mock", code: -1)
            )
        }

        return MaintenanceResult(
            closures: mockClosures,
            scrapedAt: Date(),
            source: URL(string: "https://mock.test")!
        )
    }
}
#endif
