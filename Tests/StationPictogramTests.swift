import Foundation
import Testing
@testable import ParabusCore

@Suite("StationPictogram lookup")
struct StationPictogramTests {

    @Test("Returns nil for unknown stationId")
    func unknownStation() {
        #expect(StationPictogram.assetName(for: "does-not-exist") == nil)
    }

    @Test("Returns nil for empty stationId")
    func emptyStation() {
        #expect(StationPictogram.assetName(for: "") == nil)
    }

    /// Sanity test: if ANY pictograms got extracted, this verifies the
    /// lookup wiring works end-to-end. If pictogram extraction skipped
    /// some/all stations, this still passes — just doesn't exercise the
    /// "found" branch.
    @Test("Some stations may have bundled pictograms")
    func anyExtractedPictogram() {
        let allLines = ["1","2","3","4","5","6","7"]
        let anyFound = allLines
            .flatMap { GTFSStations.stations(for: $0) }
            .contains { station in
                StationPictogram.assetName(for: station.id) != nil
            }
        // We don't assert true/false; we just exercise the path. Coverage
        // is informational. Use `print` only for human-eye signal.
        if anyFound {
            // If found, double-check naming convention: "pictogram-" prefix.
            let firstFound = allLines
                .flatMap { GTFSStations.stations(for: $0) }
                .compactMap { StationPictogram.assetName(for: $0.id) }
                .first
            #expect(firstFound?.hasPrefix("pictogram-") == true)
        }
    }
}
