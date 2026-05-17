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

// MARK: - Mock Implementation for Previews/Tests

#if DEBUG
/// Static fixtures for SwiftUI previews and unit tests. Previously lived in
/// MetrobusScraper's DEBUG extension; moved here when the scraper itself was
/// deleted.
enum MockTransitData {
    static let lines: [LineStatus] = [
        LineStatus(
            lineNumber: "1",
            transportType: .metrobus,
            status: .regular,
            affectedStations: []
        ),
        LineStatus(
            lineNumber: "2",
            transportType: .metrobus,
            status: .intervention,
            affectedStations: ["La Joya", "Iztacalco"],
            additionalInfo: "Por mantenimiento a la estacion"
        ),
        LineStatus(
            lineNumber: "3",
            transportType: .metrobus,
            status: .regular,
            affectedStations: []
        ),
        LineStatus(
            lineNumber: "4",
            transportType: .metrobus,
            status: .delayed,
            affectedStations: ["Buenavista"],
            additionalInfo: "Manifestacion en inmediaciones"
        ),
    ]

    static let maintenance: [ScheduledClosure] = [
        ScheduledClosure(
            lineNumber: "1",
            stationName: "Manuel Gonzalez",
            direction: .both,
            reason: .majorMaintenance,
            closurePeriod: "4 y 5 de Diciembre",
            parsedDates: nil,
            hours: nil
        ),
        ScheduledClosure(
            lineNumber: "1",
            stationName: "Buenavista",
            direction: .northbound,
            reason: .maintenance,
            closurePeriod: "8 de diciembre, de las 20 horas al cierre",
            parsedDates: nil,
            hours: ClosureHours(startHour: 20, endHour: nil, description: "hasta el cierre")
        ),
        ScheduledClosure(
            lineNumber: "3",
            stationName: "Etiopía",
            direction: .both,
            reason: .majorMaintenance,
            closurePeriod: "Del 2 al 6 de diciembre",
            parsedDates: nil,
            hours: nil
        ),
    ]
}

actor MockTransitDataProvider: TransitDataProviding {
    private let mockLines: [LineStatus]
    private let mockClosures: [ScheduledClosure]
    private let shouldFail: Bool
    private let delay: Duration

    init(
        lines: [LineStatus] = MockTransitData.lines,
        closures: [ScheduledClosure] = MockTransitData.maintenance,
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
