import Foundation
import Testing
@testable import ParabusCore

@Suite("MetrobusScraper Tests")
struct MetrobusScraperTests {

    @Test("ServiceStatus parses correctly")
    func serviceStatusParsing() {
        #expect(ServiceStatus(from: "Servicio Regular") == .regular)
        #expect(ServiceStatus(from: "servicio regular") == .regular)
        #expect(ServiceStatus(from: "Intervención en la estación") == .intervention)
        #expect(ServiceStatus(from: "Servicio Suspendido") == .suspended)
        #expect(ServiceStatus(from: "Servicio con Retraso") == .delayed)
        #expect(ServiceStatus(from: "algo desconocido") == .unknown)
    }

    @Test("ServiceStatus emoji returns correctly")
    func serviceStatusEmoji() {
        #expect(ServiceStatus.regular.emoji == "✅")
        #expect(ServiceStatus.intervention.emoji == "🔧")
        #expect(ServiceStatus.suspended.emoji == "🚫")
        #expect(ServiceStatus.delayed.emoji == "⏳")
    }

    @Test("LineStatus identifies issues correctly")
    func lineStatusIssues() {
        let normalLine = LineStatus(
            lineNumber: "1",
            transportType: .metrobus,
            status: .regular,
            affectedStations: []
        )
        #expect(normalLine.hasIssues == false)

        let lineWithIntervention = LineStatus(
            lineNumber: "2",
            transportType: .metrobus,
            status: .intervention,
            affectedStations: ["La Joya"]
        )
        #expect(lineWithIntervention.hasIssues == true)
    }

    @Test("LineStatus description formats correctly")
    func lineStatusDescription() {
        let normalLine = LineStatus(
            lineNumber: "1",
            transportType: .metrobus,
            status: .regular,
            affectedStations: []
        )
        #expect(normalLine.statusDescription == "Servicio operando con normalidad")

        let affectedLine = LineStatus(
            lineNumber: "2",
            transportType: .metrobus,
            status: .intervention,
            affectedStations: ["La Joya", "Iztacalco"]
        )
        #expect(affectedLine.statusDescription.contains("La Joya"))
        #expect(affectedLine.statusDescription.contains("Iztacalco"))
    }

    @Test("ScrapingResult filters lines with issues")
    func scrapingResultFilters() {
        let lines = [
            LineStatus(lineNumber: "1", transportType: .metrobus, status: .regular, affectedStations: []),
            LineStatus(lineNumber: "2", transportType: .metrobus, status: .intervention, affectedStations: ["Test"]),
            LineStatus(lineNumber: "3", transportType: .metrobus, status: .regular, affectedStations: []),
        ]

        let result = ScrapingResult(
            lines: lines,
            scrapedAt: Date(),
            source: URL(string: "https://example.com")!
        )

        #expect(result.linesWithIssues.count == 1)
        #expect(result.linesWithIssues.first?.lineNumber == "2")
        #expect(result.allLinesNormal == false)
    }

    @Test("Scraper fetches real data", .tags(.network))
    func fetchRealData() async throws {
        let scraper = MetrobusScraper()
        let result = try await scraper.fetchStatus()

        #expect(!result.lines.isEmpty)
        #expect(result.lines.count >= 1)

        // Verificar que las líneas tienen datos válidos
        for line in result.lines {
            #expect(!line.lineNumber.isEmpty)
            #expect(line.transportType == .metrobus)
        }
    }
}

extension Tag {
    @Tag static var network: Self
}
