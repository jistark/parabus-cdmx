#if os(iOS)
import Foundation
import ActivityKit
import SwiftUI

// MARK: - Live Activity Attributes

/// Defines the data for Metrobus disruption Live Activities
@available(iOS 16.1, *)
struct MetrobusDisruptionAttributes: ActivityAttributes {
    /// Static data that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        let status: String
        let statusSeverity: Int
        let affectedStations: [String]
        let additionalInfo: String?
        let updatedAt: Date
    }

    /// Line number (static for the activity)
    let lineNumber: String
    /// Line name
    let lineName: String
    /// When the disruption started
    let startedAt: Date
}

// MARK: - Live Activity Colors
//
// `statusSeverity` mirrors `ServiceStatus.severity` from the main app
// (LiveActivityService passes it through as `line.status.severity`):
//   protest=6 > suspended=5 > delayed=4 > limited=3 > intervention=2 >
//   unknown=1 > regular=0
//
// Previously this switch only handled 2/3/4 and bucketed everything else
// as "regular" — protest and suspended disruptions rendered with a green
// checkmark. Aligned in REVIEW HIGH-17.
//
// Colors mirror `StatusColors.color(for:)` in DesignTokens.swift and
// `WidgetServiceStatus.color` in SharedTypes.swift.

@available(iOS 16.1, *)
extension MetrobusDisruptionAttributes.ContentState {
    var statusColor: Color {
        switch statusSeverity {
        case 6: return .pink                                       // protest
        case 5: return .red                                        // suspended
        case 4: return Color(red: 0.85, green: 0.55, blue: 0.0)    // delayed (WCAG-amber)
        case 3: return .yellow                                     // limited
        case 2: return .orange                                     // intervention
        case 1: return .secondary                                  // unknown
        default: return .green                                     // regular
        }
    }

    var statusIcon: String {
        switch statusSeverity {
        case 6: return "megaphone.fill"
        case 5: return "exclamationmark.octagon.fill"
        case 4: return "clock.badge.exclamationmark"
        case 3: return "arrow.left.arrow.right"
        case 2: return "wrench.and.screwdriver.fill"
        case 1: return "questionmark.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Push Notification Payload Structure

/// Structure for push notifications to update Live Activities
/// Send to APNs with topic: <bundle-id>.push-type.liveactivity
@available(iOS 16.1, *)
struct LiveActivityPushPayload: Codable {
    let aps: APSPayload
    let contentState: MetrobusDisruptionAttributes.ContentState

    struct APSPayload: Codable {
        let timestamp: Int
        let event: String // "update" or "end"
        let contentState: MetrobusDisruptionAttributes.ContentState
        let dismissalDate: Int? // Unix timestamp for auto-dismiss
        let staleDate: Int? // Unix timestamp when data becomes stale

        enum CodingKeys: String, CodingKey {
            case timestamp
            case event
            case contentState = "content-state"
            case dismissalDate = "dismissal-date"
            case staleDate = "stale-date"
        }
    }
}

// MARK: - Activity Token Info

/// Information about an active Live Activity for server registration
@available(iOS 16.1, *)
struct LiveActivityTokenInfo: Codable {
    let lineNumber: String
    let pushToken: String
    let activityId: String
    let createdAt: Date
}

#endif
