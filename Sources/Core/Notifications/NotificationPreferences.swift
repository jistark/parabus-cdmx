import Foundation

/// Reads user-selected notification preferences from `UserDefaults`. Mirrors
/// the `@AppStorage` keys used by SettingsView so the BackgroundRefreshManager
/// can consume them without a SwiftUI dependency.
///
/// REVIEW LOW-11 was that these toggles persisted but nothing read them —
/// notifications fired for protest regardless of user choice. This type
/// closes that gap.
struct NotificationPreferences: Sendable {
    /// Master switch — if false, no notifications at all.
    let enabled: Bool
    /// Only notify when an incident affects one of the user's favorite
    /// lines (from the `favoriteLines` CSV in @AppStorage).
    let favoriteLineNumbers: Set<String>
    /// Per-status user preferences.
    let notifyProtest: Bool
    let notifySuspended: Bool
    let notifyDelayed: Bool
    let notifyLimited: Bool
    let notifyIntervention: Bool
    let notifyMaintenance: Bool

    /// Load current preferences. Defaults match the SettingsView toggle
    /// defaults (notificationsEnabled = true, favorites = "1,2,3", protest
    /// + suspended + delayed on, intervention + maintenance off, limited
    /// on by default since it's a real-time disruption).
    static func current(defaults: UserDefaults = .standard) -> NotificationPreferences {
        NotificationPreferences(
            enabled: defaults.object(forKey: "notificationsEnabled") as? Bool ?? true,
            favoriteLineNumbers: Self.parseFavorites(
                defaults.string(forKey: "favoriteLines") ?? "1,2,3"
            ),
            // .protest is always on when the master switch is on — it's the
            // most urgent state. We don't expose a separate toggle for it.
            notifyProtest: true,
            notifySuspended: defaults.object(forKey: "notifySuspended") as? Bool ?? true,
            notifyDelayed: defaults.object(forKey: "notifyDelayed") as? Bool ?? true,
            notifyLimited: defaults.object(forKey: "notifyLimited") as? Bool ?? true,
            notifyIntervention: defaults.object(forKey: "notifyIntervention") as? Bool ?? false,
            notifyMaintenance: defaults.object(forKey: "notifyMaintenance") as? Bool ?? false
        )
    }

    /// Decide whether a line with the given status should fire a notification.
    /// Checks the master switch, the per-status toggle, AND the favorites
    /// filter.
    func shouldNotify(line lineNumber: String, status: ServiceStatus) -> Bool {
        guard enabled else { return false }
        guard favoriteLineNumbers.contains(lineNumber) else { return false }
        switch status {
        case .protest: return notifyProtest
        case .suspended: return notifySuspended
        case .delayed: return notifyDelayed
        case .limited: return notifyLimited
        case .intervention: return notifyIntervention
        case .regular, .unknown: return false
        }
    }

    private static func parseFavorites(_ csv: String) -> Set<String> {
        Set(csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
}
