import Foundation

// MARK: - Protest Key (platform-agnostic, exposed for testing)

/// Encodes/decodes the de-duplication keys used to track which protests
/// have already triggered a notification today. Kept outside the
/// `#if os(iOS)` block below so the pure-string logic is unit-testable on
/// macOS (no BackgroundTasks/UserNotifications dependency).
///
/// Key format: `"protest_L<line>_<timestamp>"` where `<timestamp>` is a
/// `TimeInterval` from a `Date`. The old inline implementation parsed by
/// `split(_:on:).last` which silently breaks if `lineNumber` ever contains
/// an underscore. Using a fixed prefix sentinel here makes that robust.
enum ProtestKey {
    private static let prefix = "protest_L"
    private static let separator: Character = "_"

    /// Build a deduplication key for a protest detected on `lineNumber` on a
    /// given calendar day. Two calls with the same `(lineNumber, day)` produce
    /// the same key.
    static func make(lineNumber: String, day: Date, calendar: Calendar = .current) -> String {
        let dayStart = calendar.startOfDay(for: day).timeIntervalSince1970
        return "\(prefix)\(lineNumber)\(separator)\(dayStart)"
    }

    /// Extract the timestamp portion from a key produced by `make(...)`.
    /// Returns nil if the key wasn't produced by `make` (wrong prefix or
    /// non-numeric tail).
    static func timestamp(from key: String) -> TimeInterval? {
        guard key.hasPrefix(prefix) else { return nil }
        let tail = key.dropFirst(prefix.count) // "<line>_<timestamp>"
        guard let lastSep = tail.lastIndex(of: separator) else { return nil }
        let timestampPart = tail[tail.index(after: lastSep)...]
        return Double(timestampPart)
    }
}

#if os(iOS)
import BackgroundTasks
import UserNotifications

/// Maneja el background refresh para actualizar datos periodicamente
@MainActor
final class BackgroundRefreshManager {

    // MARK: - Constants

    static let shared = BackgroundRefreshManager()

    /// Identificador del task (debe coincidir con Info.plist)
    static let taskIdentifier = "com.parabus.app.refresh"

    /// Intervalo mínimo entre refreshes (15 minutos es el mínimo de iOS)
    private let minimumInterval: TimeInterval = 15 * 60

    // MARK: - Dependencies

    private let dataProvider = APITransitDataProvider()
    private let cache = CacheManager()

    /// Track which protests we've already notified about
    private var notifiedProtestKeys: Set<String> = []

    // MARK: - Init

    private init() {
        // Load previously notified protests from UserDefaults
        if let saved = UserDefaults.standard.stringArray(forKey: "notifiedProtestKeys") {
            notifiedProtestKeys = Set(saved)
        }
    }

    // MARK: - Registration

    /// Registra el background task. Llamar en didFinishLaunching
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                self?.handleAppRefresh(task: task)
            }
        }
    }

    /// Programa el siguiente refresh
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Error programando background refresh: \(error)")
        }
    }

    /// Cancela cualquier refresh programado
    func cancelScheduledRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }

    // MARK: - Notification Permission

    /// Request notification permissions
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    // MARK: - Task Handling

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Programar el siguiente refresh
        scheduleAppRefresh()

        // Crear task para el refresh
        let refreshTask = Task {
            do {
                let result = try await dataProvider.fetchStatus()
                try await cache.save(result)

                // Check for protests and send urgent notifications
                await checkForProtestsAndNotify(lines: result.lines)

                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        // Manejar expiración
        task.expirationHandler = {
            refreshTask.cancel()
        }
    }

    // MARK: - Protest Detection & Notifications

    /// Check for protest status and send urgent local notifications
    private func checkForProtestsAndNotify(lines: [LineStatus]) async {
        let protestLines = lines.filter { $0.status == .protest }

        for line in protestLines {
            // Create unique key for this protest
            let protestKey = ProtestKey.make(lineNumber: line.lineNumber, day: Date())

            // Skip if we've already notified about this protest today
            guard !notifiedProtestKeys.contains(protestKey) else { continue }

            // Send urgent notification
            await sendProtestNotification(for: line)

            // Mark as notified
            notifiedProtestKeys.insert(protestKey)
            saveNotifiedProtests()
        }

        // Clean up old protest keys (older than 24 hours)
        cleanupOldProtestKeys()
    }

    private func sendProtestNotification(for line: LineStatus) async {
        let content = UNMutableNotificationContent()
        content.title = "🚨 Manifestación en Línea \(line.lineNumber)"
        content.body = line.additionalInfo ?? "Servicio afectado por manifestación. Considera rutas alternativas."
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "PROTEST_ALERT"

        // Add line info for deep linking
        content.userInfo = [
            "lineNumber": line.lineNumber,
            "status": "protest"
        ]

        let request = UNNotificationRequest(
            identifier: "protest_\(line.lineNumber)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Notificación de manifestación enviada para Línea \(line.lineNumber)")
        } catch {
            print("❌ Error enviando notificación: \(error)")
        }
    }

    private func saveNotifiedProtests() {
        UserDefaults.standard.set(Array(notifiedProtestKeys), forKey: "notifiedProtestKeys")
    }

    private func cleanupOldProtestKeys() {
        let oneDayAgo = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 - 86400
        notifiedProtestKeys = notifiedProtestKeys.filter { key in
            guard let timestamp = ProtestKey.timestamp(from: key) else { return false }
            return timestamp > oneDayAgo
        }
        saveNotifiedProtests()
    }

    /// Clear all notifications and reset protest tracking (for testing)
    func resetProtestNotifications() {
        notifiedProtestKeys.removeAll()
        saveNotifiedProtests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension BackgroundRefreshManager {
    /// Simula un background refresh para testing
    func simulateBackgroundRefresh() async {
        do {
            let result = try await dataProvider.fetchStatus()
            try await cache.save(result)

            // Also check for protests in simulation
            await checkForProtestsAndNotify(lines: result.lines)

            print("✅ Background refresh simulado exitoso: \(result.lines.count) líneas")

            // Log any protests found
            let protests = result.lines.filter { $0.status == .protest }
            if !protests.isEmpty {
                print("🚨 Manifestaciones detectadas: \(protests.map { "L\($0.lineNumber)" }.joined(separator: ", "))")
            }
        } catch {
            print("❌ Background refresh simulado falló: \(error)")
        }
    }

    /// Simulate a protest notification for testing
    func simulateProtestNotification(forLine lineNumber: String = "1") async {
        let testLine = LineStatus(
            lineNumber: lineNumber,
            transportType: .metrobus,
            status: .protest,
            affectedStations: ["Insurgentes", "Reforma"],
            additionalInfo: "Manifestación en curso. Servicio suspendido temporalmente."
        )
        await sendProtestNotification(for: testLine)
    }
}
#endif

#endif // os(iOS)
