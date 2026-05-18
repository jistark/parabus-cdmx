import SwiftUI

@main
struct ParabusApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// Single source of truth for status/maintenance state across all tabs.
    /// Previously each of MainTabView, ContentView, AlertsView, and
    /// CommuteTabView held its own `@State` MetrobusViewModel — 4 parallel
    /// network round-trips on cold launch, 4 independent caches, badge
    /// counts that could drift if any one tab's fetch failed (REVIEW
    /// CRIT-04). Hoisting to the App root with `.environment(_:)` injection
    /// gives every tab the same Observable instance.
    @State private var statusViewModel = MetrobusViewModel()

    init() {
        #if os(iOS)
        BackgroundRefreshManager.shared.registerBackgroundTask()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(statusViewModel)
        }
        #if os(iOS)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                BackgroundRefreshManager.shared.scheduleAppRefresh()
            case .active, .inactive:
                break
            @unknown default:
                break
            }
        }
        #endif
    }
}
