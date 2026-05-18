#if os(iOS)
import Foundation
import UserNotifications

/// `UNUserNotificationCenterDelegate` implementation. Two jobs:
///   1. When a notification arrives while the app is in the foreground,
///      decide how to present it (banner + sound rather than nothing).
///   2. When the user taps a delivered notification, parse the userInfo
///      into a `NotificationDeepLink` and hand it to the router.
///
/// Wired in `ParabusApp.init` via `UNUserNotificationCenter.current().delegate`.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Router shared with the SwiftUI environment. AlertsView observes
    /// `pendingDeepLink` and reacts.
    let router: NotificationRouter

    init(router: NotificationRouter) {
        self.router = router
    }

    /// Foreground presentation. Without this, iOS silently drops notifs that
    /// arrive while the app is active. We want at least a banner so the user
    /// sees the alert even if mid-task.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// User tapped a notification. Pull the line+status out of userInfo and
    /// stash on the router so MainTabView can switch to Alerts and
    /// AlertsView can scroll to the relevant card.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard let lineNumber = userInfo["lineNumber"] as? String else {
            return
        }
        let status = (userInfo["status"] as? String) ?? ""
        router.pendingDeepLink = NotificationDeepLink(
            lineNumber: lineNumber,
            statusRaw: status
        )
    }
}
#endif
