import Foundation

/// Maps a station id to its bundled pictogram asset (PDF in
/// Sources/Resources/Pictograms/). Returns nil for stations without
/// an extracted pictogram — `StationSignage` renders without the
/// pictogram block in that case.
enum StationPictogram {
    /// Asset name (without extension) for the station's pictogram,
    /// or nil if no pictogram is bundled.
    static func assetName(for stationId: String) -> String? {
        let candidate = "pictogram-\(stationId)"
        // Check bundle resources. Bundle.module exposes Resources/Pictograms.
        let url = Bundle.module.url(forResource: candidate, withExtension: "pdf")
        return url == nil ? nil : candidate
    }
}
