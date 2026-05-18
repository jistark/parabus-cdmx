import Foundation
import Observation

/// Shared notification-driven state that lives at the App root and propagates
/// to MainTabView and AlertsView via `@Environment`. Two responsibilities:
///   1. Pending deep links (a notification was tapped while the app was in
///      background; we need to surface what line/status to highlight).
///   2. Permission state mirror (the actual source of truth is
///      UNUserNotificationCenter's settings; this is a cached snapshot that
///      views can read without an async hop).
@Observable
@MainActor
final class NotificationRouter {
    /// Most recently tapped notification, if any. AlertsView consumes and
    /// clears it after handling.
    var pendingDeepLink: NotificationDeepLink?

    /// Cached permission state. Update via `refreshPermission()`.
    var permissionAuthorized: Bool = false

    /// Update the cached permission state from the system. Call on app
    /// foregrounding and after toggle changes.
    func refreshPermission() async {
        #if os(iOS)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
        #else
        permissionAuthorized = false
        #endif
    }
}

/// Identifies what a tapped notification wants the app to surface. Currently
/// only AlertsView with a line filter; expand here if push-notifications or
/// new categories arrive.
struct NotificationDeepLink: Equatable, Sendable {
    let lineNumber: String
    /// Empty string for protest-or-unknown — Alerts shows the line summary
    /// without status-specific scrolling.
    let statusRaw: String

    var status: ServiceStatus? {
        ServiceStatus(rawValue: statusRaw)
    }
}

#if os(iOS)
import UserNotifications
#endif
