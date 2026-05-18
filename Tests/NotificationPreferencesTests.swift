import Foundation
import Testing
@testable import ParabusCore

@Suite("NotificationPreferences Tests")
struct NotificationPreferencesTests {

    /// Build a UserDefaults backed by a unique suite name per test so the
    /// per-test mutations don't leak into the host process's standard
    /// defaults or into other tests running in parallel.
    private func makeDefaults() -> UserDefaults {
        let suite = "NotificationPreferencesTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    // MARK: - Defaults

    @Test("Defaults: enabled, common statuses on, intervention/maintenance off")
    func defaultsMatchSettingsView() {
        let prefs = NotificationPreferences.current(defaults: makeDefaults())
        #expect(prefs.enabled == true)
        #expect(prefs.notifyProtest == true)
        #expect(prefs.notifySuspended == true)
        #expect(prefs.notifyDelayed == true)
        #expect(prefs.notifyLimited == true)
        #expect(prefs.notifyIntervention == false)
        #expect(prefs.notifyMaintenance == false)
        #expect(prefs.favoriteLineNumbers == ["1", "2", "3"])
    }

    @Test("Custom favorites CSV parses correctly")
    func parsesFavoritesCSV() {
        let d = makeDefaults()
        d.set("4,5,7", forKey: "favoriteLines")
        let prefs = NotificationPreferences.current(defaults: d)
        #expect(prefs.favoriteLineNumbers == ["4", "5", "7"])
    }

    @Test("Whitespace and empty entries in favorites CSV are ignored")
    func favoritesCSVStripsJunk() {
        let d = makeDefaults()
        d.set(" 1, ,  2 ,3", forKey: "favoriteLines")
        let prefs = NotificationPreferences.current(defaults: d)
        #expect(prefs.favoriteLineNumbers == ["1", "2", "3"])
    }

    // MARK: - shouldNotify decision matrix

    @Test("Master switch off blocks every notification")
    func masterSwitchOff() {
        let d = makeDefaults()
        d.set(false, forKey: "notificationsEnabled")
        let prefs = NotificationPreferences.current(defaults: d)
        // Even protest (always-on by hard rule) is blocked when master is off.
        #expect(prefs.shouldNotify(line: "1", status: .protest) == false)
        #expect(prefs.shouldNotify(line: "1", status: .suspended) == false)
    }

    @Test("Non-favorite line is filtered out even if status is enabled")
    func filtersByFavorites() {
        let d = makeDefaults()
        d.set("1,3", forKey: "favoriteLines")
        let prefs = NotificationPreferences.current(defaults: d)
        #expect(prefs.shouldNotify(line: "1", status: .protest) == true)
        #expect(prefs.shouldNotify(line: "2", status: .protest) == false) // not favorited
        #expect(prefs.shouldNotify(line: "3", status: .delayed) == true)
    }

    @Test("Per-status toggles gate individual statuses")
    func perStatusToggles() {
        let d = makeDefaults()
        d.set(false, forKey: "notifyDelayed")
        d.set(true, forKey: "notifyIntervention")
        let prefs = NotificationPreferences.current(defaults: d)
        #expect(prefs.shouldNotify(line: "1", status: .delayed) == false)
        #expect(prefs.shouldNotify(line: "1", status: .intervention) == true)
        // Default-on statuses unaffected
        #expect(prefs.shouldNotify(line: "1", status: .suspended) == true)
    }

    @Test("Regular and unknown statuses never notify")
    func regularAndUnknownNeverNotify() {
        let prefs = NotificationPreferences.current(defaults: makeDefaults())
        #expect(prefs.shouldNotify(line: "1", status: .regular) == false)
        #expect(prefs.shouldNotify(line: "1", status: .unknown) == false)
    }

    @Test("Protest is hardcoded ON when master is on")
    func protestAlwaysOn() {
        let prefs = NotificationPreferences.current(defaults: makeDefaults())
        #expect(prefs.notifyProtest == true)
        #expect(prefs.shouldNotify(line: "1", status: .protest) == true)
    }
}

@Suite("IncidentNotificationKey Tests", .serialized)
struct IncidentNotificationKeyTests {

    @Test("Same line + status + day produces same key")
    func roundtripStableKey() {
        let day = Date(timeIntervalSince1970: 1_699_963_200)
        let cal = utcCalendar
        let k1 = IncidentNotificationKey.make(lineNumber: "1", status: "suspended", day: day, calendar: cal)
        let k2 = IncidentNotificationKey.make(
            lineNumber: "1",
            status: "suspended",
            day: day.addingTimeInterval(6 * 60 * 60), // same day in UTC
            calendar: cal
        )
        #expect(k1 == k2)
    }

    @Test("Different statuses on same line produce distinct keys")
    func statusDifferentiated() {
        let day = Date(timeIntervalSince1970: 1_699_963_200)
        let cal = utcCalendar
        let suspended = IncidentNotificationKey.make(lineNumber: "1", status: "suspended", day: day, calendar: cal)
        let delayed = IncidentNotificationKey.make(lineNumber: "1", status: "delayed", day: day, calendar: cal)
        #expect(suspended != delayed)
    }

    @Test("timestamp() roundtrips through make()")
    func timestampRoundtrip() {
        let day = Date(timeIntervalSince1970: 1_699_963_200)
        let cal = utcCalendar
        let key = IncidentNotificationKey.make(lineNumber: "3", status: "intervention", day: day, calendar: cal)
        let expected = cal.startOfDay(for: day).timeIntervalSince1970
        #expect(IncidentNotificationKey.timestamp(from: key) == expected)
    }

    @Test("timestamp() returns nil for legacy ProtestKey format")
    func timestampRejectsOldFormat() {
        // The legacy ProtestKey format ("protest_L1_TIMESTAMP") is intentionally
        // not parsed by IncidentNotificationKey — AnyNotificationKey handles
        // mixed datasets during cleanup.
        let legacyKey = ProtestKey.make(lineNumber: "1", day: Date())
        #expect(IncidentNotificationKey.timestamp(from: legacyKey) == nil)
    }

    @Test("AnyNotificationKey reads BOTH legacy and new formats")
    func anyKeyHandlesBothFormats() {
        let day = Date(timeIntervalSince1970: 1_699_963_200)
        let cal = utcCalendar
        let legacy = ProtestKey.make(lineNumber: "1", day: day, calendar: cal)
        let new = IncidentNotificationKey.make(lineNumber: "1", status: "suspended", day: day, calendar: cal)
        #expect(AnyNotificationKey.timestamp(from: legacy) != nil)
        #expect(AnyNotificationKey.timestamp(from: new) != nil)
        #expect(AnyNotificationKey.timestamp(from: "garbage") == nil)
    }

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
}
