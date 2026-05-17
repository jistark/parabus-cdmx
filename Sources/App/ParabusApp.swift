import SwiftUI

@main
struct ParabusApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if os(iOS)
        BackgroundRefreshManager.shared.registerBackgroundTask()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
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
