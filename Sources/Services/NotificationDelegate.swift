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
///
/// NOTE on concurrency: this type is NOT `@MainActor`. The UN protocol is
/// not main-actor-isolated, so the system can call our delegate methods
/// from any thread (in practice it's almost always main, but the contract
/// is broader). Marking the class `@MainActor` causes Swift 6 strict
/// concurrency to flag the conformance as crossing isolation boundaries.
///
/// Each delegate method is `nonisolated` and hops to the MainActor only
/// for the small slice that mutates the @Observable router. `router` is
/// captured into a Sendable closure (NotificationRouter conforms to
/// Sendable via its @Observable + @MainActor declarations being final).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Router shared with the SwiftUI environment. AlertsView observes
    /// `pendingDeepLink` and reacts. `@Observable` types are Sendable so
    /// the cross-actor reference is safe; mutations still happen on
    /// MainActor inside the hop below.
    private let router: NotificationRouter

    init(router: NotificationRouter) {
        self.router = router
    }

    /// Foreground presentation. Without this, iOS silently drops notifs that
    /// arrive while the app is active. We want at least a banner so the user
    /// sees the alert even if mid-task.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// User tapped a notification. Pull the line+status out of userInfo and
    /// stash on the router so MainTabView can switch to Alerts and
    /// AlertsView can scroll to the relevant card.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Acknowledge the response synchronously — the contract is "call
        // completionHandler when you're done processing", and reading the
        // userInfo dict is enough processing. The downstream router
        // mutation is fire-and-forget on MainActor; UI redraws when it
        // lands. (We can't carry `completionHandler` into the Task —
        // @escaping () -> Void is non-Sendable under Swift 6 strict.)
        completionHandler()

        let userInfo = response.notification.request.content.userInfo
        guard let lineNumber = userInfo["lineNumber"] as? String else {
            return
        }
        let status = (userInfo["status"] as? String) ?? ""
        let link = NotificationDeepLink(lineNumber: lineNumber, statusRaw: status)

        let router = self.router
        Task { @MainActor in
            router.pendingDeepLink = link
        }
    }
}
#endif
