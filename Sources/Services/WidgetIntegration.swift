// WidgetIntegration.swift
// Parabús
//
// Integration between main app and widget extension.
// Handles data sharing via App Groups and widget timeline reloads.

#if os(iOS)
import Foundation
import WidgetKit

// MARK: - Widget Data Writer

/// Writes data to App Group for widget consumption
actor WidgetDataWriter {

    // MARK: - Singleton

    static let shared = WidgetDataWriter()

    // MARK: - Configuration

    private let appGroupIdentifier = "group.starkji.parabus-cdmx.app"
    private let statusFileName = "metrobus_status.json"

    // MARK: - File URL

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(statusFileName)
    }

    // MARK: - Public Methods

    /// Update widget data from scraping result
    /// Call this after each successful data refresh
    func updateWidgetData(from result: ScrapingResult) async {
        guard let url = fileURL else {
            print("Widget: App Group container not available")
            return
        }

        // Convert to main app's cached data format (widget will parse this)
        let cachedData = CacheManager.CachedData(
            lines: result.lines,
            cachedAt: result.scrapedAt,
            sourceURL: result.source.absoluteString
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(cachedData)
            try data.write(to: url, options: .atomic)

            // Reload widget timelines
            reloadAllWidgets()

            print("Widget: Data updated successfully")
        } catch {
            print("Widget: Failed to write data: \(error)")
        }
    }

    /// Reload all widget timelines
    /// Call after data changes
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Reload specific widget
    func reloadWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    /// Get current widget configurations
    func getCurrentWidgets() async -> [WidgetInfo] {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                switch result {
                case .success(let widgets):
                    continuation.resume(returning: widgets)
                case .failure(let error):
                    print("Widget: Failed to get configurations: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Check if user has any widgets installed
    func hasInstalledWidgets() async -> Bool {
        let widgets = await getCurrentWidgets()
        return !widgets.isEmpty
    }
}

// MARK: - CacheManager Extension

extension CacheManager {

    /// Save result and update widget
    func saveAndUpdateWidget(_ result: ScrapingResult) async throws {
        // Save to main cache
        try save(result)

        // Update widget data
        await WidgetDataWriter.shared.updateWidgetData(from: result)
    }
}

// MARK: - Widget Kind Constants

enum WidgetKind {
    static let status = "MetrobusStatusWidget"
    static let accessory = "MetrobusAccessoryWidget"
}
#endif
