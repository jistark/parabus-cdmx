import Foundation
import SwiftUI

// MARK: - Shared Constants

enum ParabusConstants {
    static let appGroupIdentifier = "group.starkji.parabus-cdmx.app"
    static let widgetCacheFileName = "widget_status.json"
    static let widgetKind = "MetrobusStatusWidget"
    static let accessoryWidgetKind = "MetrobusAccessoryWidget"
}

// MARK: - Widget Data Types

/// Lightweight line status for widget display
struct WidgetLineStatus: Codable, Identifiable {
    let id: String
    let lineNumber: String
    let status: WidgetServiceStatus
    let affectedStationsCount: Int
    let incidentCount: Int

    var hasIssues: Bool {
        status != .regular || affectedStationsCount > 0
    }
}

/// Simplified status enum for widget
enum WidgetServiceStatus: String, Codable, CaseIterable {
    case regular
    case intervention
    case suspended
    case delayed
    case unknown

    var displayText: String {
        switch self {
        case .regular: return "Normal"
        case .intervention: return "Obra"
        case .suspended: return "Suspendido"
        case .delayed: return "Retraso"
        case .unknown: return "?"
        }
    }

    var shortText: String {
        switch self {
        case .regular: return "OK"
        case .intervention: return "Obra"
        case .suspended: return "Susp."
        case .delayed: return "Retraso"
        case .unknown: return "?"
        }
    }

    var icon: String {
        switch self {
        case .regular: return "checkmark.circle.fill"
        case .intervention: return "wrench.and.screwdriver.fill"
        case .suspended: return "exclamationmark.octagon.fill"  // Octagon = stop sign
        case .delayed: return "clock.badge.exclamationmark"     // Time + urgency
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .regular: return .green
        case .intervention: return .orange  // Orange for scheduled maintenance
        case .suspended: return .red
        case .delayed: return .red  // Red for delays (urgent real-time issue)
        case .unknown: return .secondary
        }
    }

    var severity: Int {
        switch self {
        case .regular: return 0
        case .unknown: return 1
        case .delayed: return 2
        case .intervention: return 3
        case .suspended: return 4
        }
    }
}

/// Data structure stored in App Group for widget
struct WidgetData: Codable {
    let lines: [WidgetLineStatus]
    let updatedAt: Date
    let isStale: Bool

    var linesWithIssues: [WidgetLineStatus] {
        lines.filter { $0.hasIssues }
    }

    var worstStatus: WidgetServiceStatus {
        lines.map(\.status).max(by: { $0.severity < $1.severity }) ?? .regular
    }

    var affectedLinesCount: Int {
        linesWithIssues.count
    }

    var allClear: Bool {
        linesWithIssues.isEmpty
    }

    static let placeholder = WidgetData(
        lines: (1...7).map { num in
            WidgetLineStatus(
                id: "\(num)",
                lineNumber: "\(num)",
                status: .regular,
                affectedStationsCount: 0,
                incidentCount: 0
            )
        },
        updatedAt: Date(),
        isStale: false
    )
}

// MARK: - Widget Cache Reader

enum WidgetCacheReader {
    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ParabusConstants.appGroupIdentifier
        )
    }

    static func load() -> WidgetData? {
        guard let url = containerURL?.appendingPathComponent(ParabusConstants.widgetCacheFileName) else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetData.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(_ widgetData: WidgetData) throws {
        guard let url = containerURL?.appendingPathComponent(ParabusConstants.widgetCacheFileName) else {
            throw NSError(domain: "WidgetCache", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "App Group container not available"
            ])
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(widgetData)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - Line Colors for Widget

enum WidgetLineColor {
    static func color(for lineNumber: String) -> Color {
        switch lineNumber {
        case "1": return Color(red: 0.83, green: 0.18, blue: 0.18)
        case "2": return Color(red: 0.48, green: 0.18, blue: 0.56)
        case "3": return Color(red: 0.13, green: 0.55, blue: 0.13)
        case "4": return Color(red: 0.96, green: 0.65, blue: 0.14)
        case "5": return Color(red: 0.00, green: 0.48, blue: 0.65)
        case "6": return Color(red: 0.80, green: 0.00, blue: 0.47)
        case "7": return Color(red: 0.00, green: 0.60, blue: 0.40)
        default: return .gray
        }
    }
}
