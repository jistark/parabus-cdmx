import Foundation
import WidgetKit

/// Service for triggering widget updates from the main app
enum WidgetService {

    /// Reload all Metrobus widgets
    static func reloadAllWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: ParabusConstants.widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: ParabusConstants.accessoryWidgetKind)
    }

    /// Reload widgets after a data refresh
    static func reloadAfterDataUpdate() {
        // Small delay to ensure cache is written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            reloadAllWidgets()
        }
    }

    /// Get current widget configurations (for debugging)
    static func getCurrentConfigurations() async -> [WidgetInfo] {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                switch result {
                case .success(let widgets):
                    continuation.resume(returning: widgets)
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
