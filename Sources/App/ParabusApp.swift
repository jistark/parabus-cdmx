import SwiftUI
#if os(iOS)
import UserNotifications
#endif

@main
struct ParabusApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// Single source of truth for status/maintenance state across all tabs.
    /// REVIEW CRIT-04 hoisted this here.
    @State private var statusViewModel = MetrobusViewModel()

    /// Shared deep-link + permission state for local notifications. Lives at
    /// the App root so the UNUserNotificationCenter delegate (set once at
    /// launch) can mutate `pendingDeepLink` and AlertsView/MainTabView can
    /// observe via @Environment.
    @State private var notificationRouter = NotificationRouter()

    #if os(iOS)
    /// Retained by the App so it stays alive for UNUserNotificationCenter's
    /// weak delegate reference. Created once in init.
    private let notificationDelegate: NotificationDelegate
    #endif

    init() {
        #if os(iOS)
        BackgroundRefreshManager.shared.registerBackgroundTask()
        let router = NotificationRouter()
        self._notificationRouter = State(initialValue: router)
        self.notificationDelegate = NotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = self.notificationDelegate
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(statusViewModel)
                .environment(notificationRouter)
                .task {
                    // Refresh the cached permission snapshot when the app
                    // becomes available; the Settings app or iOS dialog
                    // may have changed it while we were closed.
                    await notificationRouter.refreshPermission()
                }
        }
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                BackgroundRefreshManager.shared.scheduleAppRefresh()
            case .active:
                Task { await notificationRouter.refreshPermission() }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        #endif
    }
}
