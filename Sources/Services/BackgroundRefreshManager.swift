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
@preconcurrency import BackgroundTasks
import UserNotifications

/// Background refresh + local notification orchestrator. Lives as an actor
/// (not @MainActor) because its work is I/O, not UI: network fetch, cache
/// save, UNUserNotificationCenter posts. The registration and scheduling
/// entry points are `nonisolated` so the App scene-phase glue can call them
/// synchronously where iOS expects it.
actor BackgroundRefreshManager {

    // MARK: - Constants

    static let shared = BackgroundRefreshManager()

    /// Identificador del task (debe coincidir con Info.plist)
    static let taskIdentifier = "com.parabus.app.refresh"

    /// Intervalo mínimo entre refreshes (15 minutos es el mínimo de iOS)
    private static let minimumInterval: TimeInterval = 15 * 60

    // MARK: - Dependencies

    private let dataProvider = APITransitDataProvider()
    private let cache = CacheManager()

    /// Notification dedup keys → the day-start timestamp at which the
    /// notification fired. Stored as a Codable dict instead of a Set<String>
    /// so cleanup doesn't have to re-parse the timestamp out of the key
    /// suffix every time.
    private var notifiedKeys: [String: Date] = [:]

    private static let storageKey = "notifiedIncidentKeys"
    private static let legacyStorageKey = "notifiedProtestKeys"

    // MARK: - Init

    private init() {
        // Prefer the dict storage when present.
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let dict = try? SharedCoders.plainDecoder.decode([String: Date].self, from: data) {
            notifiedKeys = dict
            return
        }

        // Legacy migration from `stringArray` storage. The timestamp lives
        // in the key suffix; AnyNotificationKey.timestamp recovers it for
        // both ProtestKey and IncidentNotificationKey shapes.
        if let saved = UserDefaults.standard.stringArray(forKey: Self.legacyStorageKey) {
            for key in saved {
                if let ts = AnyNotificationKey.timestamp(from: key) {
                    notifiedKeys[key] = Date(timeIntervalSince1970: ts)
                }
            }
            UserDefaults.standard.removeObject(forKey: Self.legacyStorageKey)
            persistNotifiedKeys()
        }
    }

    // MARK: - Registration (nonisolated — App init expects synchronous calls)

    /// Register the background task with iOS. Must run during App init —
    /// BGTaskScheduler requires registration before launch completes.
    nonisolated func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task {
                await Self.shared.handleAppRefresh(task: task)
            }
        }
    }

    /// Programa el siguiente refresh. Llamable desde cualquier contexto.
    nonisolated func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.minimumInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Log.background.error("Error programando background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Notification Permission

    /// Request notification permissions
    func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Log.background.error("Error requesting notification permission: \(error.localizedDescription, privacy: .public)")
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
                guard notifiedKeys[key] == nil else { continue }
                await sendIncidentNotification(for: line, status: status)
                notifiedKeys[key] = Calendar.current.startOfDay(for: Date())
            }
        }

        persistNotifiedKeys()
        pruneOldNotifiedKeys()
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
            Log.background.info("Notification sent: L\(line.lineNumber, privacy: .public) \(status.rawValue, privacy: .public)")
        } catch {
            Log.background.error("Notification failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated private func statusLabel(_ status: ServiceStatus) -> String {
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

    nonisolated private func statusIcon(_ status: ServiceStatus) -> String {
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

    private func persistNotifiedKeys() {
        guard let data = try? SharedCoders.plainEncoder.encode(notifiedKeys) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func pruneOldNotifiedKeys() {
        let cutoff = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86400)
        notifiedKeys = notifiedKeys.filter { $0.value > cutoff }
        persistNotifiedKeys()
    }

    /// Clear all notifications and reset incident-dedup tracking (for testing).
    func resetProtestNotifications() {
        notifiedKeys.removeAll()
        persistNotifiedKeys()
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

            Log.background.notice("Background refresh simulado: \(result.lines.count, privacy: .public) líneas")

            // Log any protests found
            let protests = result.lines.filter { $0.status == .protest }
            if !protests.isEmpty {
                let summary = protests.map { "L\($0.lineNumber)" }.joined(separator: ", ")
                Log.background.notice("Manifestaciones detectadas: \(summary, privacy: .public)")
            }
        } catch {
            Log.background.error("Background refresh simulado falló: \(error.localizedDescription, privacy: .public)")
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
