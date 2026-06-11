// Tests/HomeHelpersTests.swift
import Foundation
import Testing
@testable import ParabusCore

@Suite("Favorite lines parsing")
struct FavoriteLinesTests {
    @Test func parsesCSV() {
        #expect(FavoriteLines.parse("1,3,7") == ["1", "3", "7"])
        #expect(FavoriteLines.parse("") == [])
        #expect(FavoriteLines.asSet("2,2,5") == Set(["2", "5"]))
    }
}

@Suite("Incident severity grouping")
struct IncidentGroupingTests {
    // LineStatus has no init(lineNumber:status:incidents:); use the convenience
    // init that takes transportType + status and builds the Incident internally.
    private func line(_ n: String, _ status: ServiceStatus) -> LineStatus {
        LineStatus(lineNumber: n, transportType: .metrobus, status: status)
    }

    @Test func ordersBySeverityDescending() {
        let lines = [
            line("1", .limited), line("2", .protest), line("3", .delayed),
            line("4", .suspended), line("5", .intervention),
        ]
        let grouped = IncidentGrouping.grouped(lines)
        #expect(grouped.map(\.lineNumber) == ["2", "4", "3", "1", "5"])
    }

    @Test func preservesInputOrderWithinSameSeverity() {
        let lines = [line("7", .delayed), line("3", .delayed)]
        #expect(IncidentGrouping.grouped(lines).map(\.lineNumber) == ["7", "3"])
    }
}
