import Foundation

/// Maps a station id to its bundled pictogram asset (PDF in
/// Sources/Resources/Pictograms/). Returns nil for stations without
/// an extracted pictogram — `StationSignage` renders without the
/// pictogram block in that case.
enum StationPictogram {
    /// The bundle holding `Resources/Pictograms/`. `Bundle.module` only
    /// exists when compiling as a Swift Package; the iOS app target
    /// flattens resources into `Bundle.main`. Guard via `#if SWIFT_PACKAGE`
    /// — same pattern as `BrandTypography` for `Resources/Fonts/`.
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    /// Asset name (without extension) for the station's pictogram,
    /// or nil if no pictogram is bundled.
    static func assetName(for stationId: String) -> String? {
        let candidate = "pictogram-\(stationId)"
        // SPM `.copy("Sources/Resources/Pictograms")` preserves the directory
        // structure under `Bundle.module`. The iOS Xcode target's
        // synchronized root group flattens copied resources into the app
        // root. Search the subdirectory first, then the root as fallback.
        let url = bundle.url(forResource: candidate, withExtension: "pdf", subdirectory: "Pictograms")
            ?? bundle.url(forResource: candidate, withExtension: "pdf")
        return url == nil ? nil : candidate
    }
}
