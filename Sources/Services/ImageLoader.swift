import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Centralized image loading for transit line badges
/// Handles platform differences and asset catalog availability
enum TransitImageLoader {

    /// Attempts to load official Metrobus icon from asset catalog
    /// Returns nil if asset unavailable (e.g., SPM builds without resources)
    ///
    /// - Parameters:
    ///   - lineNumber: The line number (e.g., "1", "2", etc.)
    ///   - transportType: The transport system type
    /// - Returns: SwiftUI Image if asset exists, nil otherwise
    static func loadOfficialImage(
        for lineNumber: String,
        transportType: TransportType
    ) -> Image? {
        guard transportType == .metrobus,
              let lineNum = Int(lineNumber),
              (1...7).contains(lineNum) else {
            return nil
        }

        let assetName = "MB\(lineNum)"

        #if canImport(UIKit)
        if let uiImage = UIImage(named: assetName) {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(named: assetName) {
            return Image(nsImage: nsImage)
        }
        #endif

        return nil
    }

    /// Convenience overload accepting LineStatus directly
    static func loadOfficialImage(for line: LineStatus) -> Image? {
        loadOfficialImage(for: line.lineNumber, transportType: line.transportType)
    }
}
