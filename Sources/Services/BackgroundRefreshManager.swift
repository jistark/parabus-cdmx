import Foundation

// MARK: - Incident Notification Keys (platform-agnostic, exposed for testing)

/// Status-aware dedup key for incident notifications. Format:
/// `"incidentnotif_L<line>_<status>_<dayStartTimestamp>"`. Two calls with
/// the same `(lineNumber, status, day)` produce the same key — so a
/// `.suspended` notif on L1 doesn't dedupe a `.delayed` notif on L1 the
/// same day (they're distinct user-facing events).
enum IncidentNotificationKey {
    private static let prefix = "incidentnotif_L"
    private static let separator: Character = "_"

    static func make(
        lineNumber: String,
        status: String,
        day: Date,
        calendar: Calendar = .current
    ) -> String {
        let dayStart = calendar.startOfDay(for: day).timeIntervalSince1970
        return "\(prefix)\(lineNumber)\(separator)\(status)\(separator)\(dayStart)"
    }

    static func timestamp(from key: String) -> TimeInterval? {
        guard key.hasPrefix(prefix) else { return nil }
        let tail = key.dropFirst(prefix.count) // "<line>_<status>_<timestamp>"
        guard let lastSep = tail.lastIndex(of: separator) else { return nil }
        let timestampPart = tail[tail.index(after: lastSep)...]
        return Double(timestampPart)
    }
}

/// Legacy protest-only dedup key. Kept intact so:
///   - Keys already persisted in UserDefaults from previous app versions
///     continue to dedupe (no double-notify storm on upgrade).
///   - The existing BackgroundRefreshTests suite keeps asserting the
///     original format semantics.
/// New incident notifications should use `IncidentNotificationKey.make`
/// with an explicit status so suspended/delayed/limited/etc. can dedup
/// independently of protest.
enum ProtestKey {
    private static let prefix = "protest_L"
    private static let separator: Character = "_"

    static func make(lineNumber: String, day: Date, calendar: Calendar = .current) -> String {
        let dayStart = calendar.startOfDay(for: day).timeIntervalSince1970
        return "\(prefix)\(lineNumber)\(separator)\(dayStart)"
    }

    static func timestamp(from key: String) -> TimeInterval? {
        guard key.hasPrefix(prefix) else { return nil }
        let tail = key.dropFirst(prefix.count)
        guard let lastSep = tail.lastIndex(of: separator) else { return nil }
        let timestampPart = tail[tail.index(after: lastSep)...]
        return Double(timestampPart)
    }
}

/// Used by cleanup to find a timestamp in any of the supported key formats.
/// Returns nil if neither parser recognizes the key.
enum AnyNotificationKey {
    static func timestamp(from key: String) -> TimeInterval? {
        IncidentNotificationKey.timestamp(from: key)
            ?? ProtestKey.timestamp(from: key)
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

                await checkAndNotify(lines: result.lines)

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

    // MARK: - Incident Detection & Notifications

    /// Check status payload for incidents the user wants to be notified
    /// about and fire local notifications for newly-detected ones.
    /// Respects the master switch, per-status toggles, and the favorites
    /// filter (REVIEW LOW-11 — these toggles used to be ignored).
    func checkAndNotify(lines: [LineStatus]) async {
        let prefs = NotificationPreferences.current()
        guard prefs.enabled else { return }

        for line in lines {
            // A line can have multiple incidents (e.g. delayed + intervention).
            // Treat each distinct status as its own notifiable event so the
            // user doesn't lose visibility on a second-priority incident
            // when a more urgent one is also active.
            let distinctStatuses = Set(line.incidents.map(\.status))
            for status in distinctStatuses where prefs.shouldNotify(line: line.lineNumber, status: status) {
                let key = IncidentNotificationKey.make(
                    lineNumber: line.lineNumber,
                    status: status.rawValue,
                    day: Date()
                )
                guard !notifiedProtestKeys.contains(key) else { continue }
                await sendIncidentNotification(for: line, status: status)
                notifiedProtestKeys.insert(key)
            }
        }

        saveNotifiedProtests()
        cleanupOldProtestKeys()
    }

    /// Build and post a local notification for a single (line, status) pair.
    /// Severity-appropriate sound and interruption level:
    ///   - protest / suspended → timeSensitive + defaultCritical (loudest
    ///     iOS allows without a true-critical-alert entitlement)
    ///   - delayed / limited / intervention → active + default sound
    private func sendIncidentNotification(for line: LineStatus, status: ServiceStatus) async {
        let content = UNMutableNotificationContent()
        content.title = "\(statusIcon(status)) Línea \(line.lineNumber): \(statusLabel(status))"

        // Body: prefer the line's additional info (operator's own words),
        // fall back to stations affected, then to a generic phrase.
        if let info = line.additionalInfo, !info.isEmpty {
            content.body = info
        } else if !line.affectedStations.isEmpty {
            content.body = "Afectación en: " + line.affectedStations.prefix(3).joined(separator: ", ")
        } else {
            content.body = "Servicio reportado con \(statusLabel(status).lowercased())."
        }

        switch status {
        case .protest, .suspended:
            content.sound = .defaultCritical
            content.interruptionLevel = .timeSensitive
        default:
            content.sound = .default
            content.interruptionLevel = .active
        }

        content.categoryIdentifier = "INCIDENT_ALERT"
        content.userInfo = [
            "lineNumber": line.lineNumber,
            "status": status.rawValue,
        ]

        let request = UNNotificationRequest(
            identifier: "incident_\(line.lineNumber)_\(status.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Notification sent: L\(line.lineNumber) \(status.rawValue)")
        } catch {
            print("Notification failed: \(error)")
        }
    }

    private func statusLabel(_ status: ServiceStatus) -> String {
        switch status {
        case .protest: return "Manifestación"
        case .suspended: return "Suspendido"
        case .delayed: return "Retraso"
        case .limited: return "Servicio limitado"
        case .intervention: return "Intervención"
        case .regular: return "Servicio regular"
        case .unknown: return "Estado desconocido"
        }
    }

    private func statusIcon(_ status: ServiceStatus) -> String {
        switch status {
        case .protest: return "🚨"
        case .suspended: return "⛔"
        case .delayed: return "⏳"
        case .limited: return "🚧"
        case .intervention: return "🔧"
        case .regular: return "✅"
        case .unknown: return "❓"
        }
    }

    private func saveNotifiedProtests() {
        UserDefaults.standard.set(Array(notifiedProtestKeys), forKey: "notifiedProtestKeys")
    }

    private func cleanupOldProtestKeys() {
        let oneDayAgo = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 - 86400
        notifiedProtestKeys = notifiedProtestKeys.filter { key in
            guard let timestamp = AnyNotificationKey.timestamp(from: key) else { return false }
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

            // Also run the notification path in simulation
            await checkAndNotify(lines: result.lines)

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
        await sendIncidentNotification(for: testLine, status: .protest)
    }
}
#endif

#endif // os(iOS)
