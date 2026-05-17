import Foundation
import SwiftUI

// MARK: - Shared Constants

enum ParabusConstants {
    static let appGroupIdentifier = "group.starkji.parabus-cdmx.app"
    static let widgetCacheFileName = "widget_status.json"
    static let widgetKind = "MetrobusStatusWidget"
    static let accessoryWidgetKind = "MetrobusAccessoryWidget"
}

// MARK: - Shared Coders

/// Cached encoder/decoder/formatter instances. Allocating these per-call is
/// surprisingly expensive on iOS — JSONDecoder is ~100s of µs, DateFormatter
/// can be ~1ms (locale loading). Reuse them everywhere persistence happens.
enum SharedCoders {
    /// Default JSON encoder. No date strategy — use `isoEncoder` if you need one.
    static let plainEncoder = JSONEncoder()

    /// Default JSON decoder. No date strategy — use `isoDecoder` if you need one.
    static let plainDecoder = JSONDecoder()

    /// JSON encoder with ISO8601 date encoding.
    static let isoEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    /// JSON decoder with ISO8601 date decoding.
    static let isoDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // Note: ISO8601DateFormatter is *not* Sendable under Swift 6 strict
    // concurrency (Foundation hasn't annotated it yet) so we can't host
    // shared instances here. Allocate at the call site if you need raw
    // date parsing; for Codable use isoEncoder / isoDecoder above.
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

/// Status enum surfaced to the widget extension. Mirrors the full set in
/// `ServiceStatus` (main app) so widget rendering doesn't squash semantically
/// distinct states.
///
/// History: previously this enum lacked `.protest` and `.limited`; the
/// converter in CacheManager mapped `protest → suspended` and `limited →
/// delayed`, so a protest (highest severity in the main app — triggers urgent
/// notifications) appeared in the widget as a generic "Suspendido" pill.
/// Re-aligned in REVIEW HIGH-17.
///
/// Visual values (displayText/shortText/icon/color) for the new `.protest`
/// and `.limited` cases are reasonable defaults; the UX/UI session is
/// expected to refine them as part of widget polish.
enum WidgetServiceStatus: String, Codable, CaseIterable {
    case regular
    case unknown
    case intervention
    case limited
    case delayed
    case suspended
    case protest

    var displayText: String {
        switch self {
        case .regular: return "Normal"
        case .intervention: return "Obra"
        case .limited: return "Limitado"
        case .delayed: return "Retraso"
        case .suspended: return "Suspendido"
        case .protest: return "Manifestación"
        case .unknown: return "?"
        }
    }

    var shortText: String {
        switch self {
        case .regular: return "OK"
        case .intervention: return "Obra"
        case .limited: return "Lim."
        case .delayed: return "Retraso"
        case .suspended: return "Susp."
        case .protest: return "Marcha"
        case .unknown: return "?"
        }
    }

    var icon: String {
        switch self {
        case .regular: return "checkmark.circle.fill"
        case .intervention: return "wrench.and.screwdriver.fill"
        case .limited: return "arrow.left.arrow.right"          // partial-service indicator
        case .delayed: return "clock.badge.exclamationmark"     // time + urgency
        case .suspended: return "exclamationmark.octagon.fill"  // stop sign
        case .protest: return "megaphone.fill"                  // protest signal
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .regular: return .green
        case .intervention: return .orange  // scheduled maintenance
        case .limited: return .orange       // partial service — same family as intervention
        case .delayed: return .red          // urgent real-time issue
        case .suspended: return .red        // no service
        case .protest: return .red          // most urgent — UX may upgrade to a distinct accent
        case .unknown: return .secondary
        }
    }

    /// Ranks aligned with `ServiceStatus.severity` in the main app so the
    /// widget's `WidgetData.worstStatus` agrees with the main app's view of
    /// "which line is most affected". Order: protest > suspended > delayed >
    /// limited > intervention > unknown > regular.
    var severity: Int {
        switch self {
        case .regular: return 0
        case .unknown: return 1
        case .intervention: return 2
        case .limited: return 3
        case .delayed: return 4
        case .suspended: return 5
        case .protest: return 6
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
