import Foundation
import Testing
@testable import ParabusCore

/// Tests for the pure-string protest-key helpers. The BackgroundRefreshManager
/// itself (BGTaskScheduler + UNUserNotificationCenter integration) is
/// system-framework-bound and only meaningful in a simulator integration
/// test — out of scope for unit tests via `swift test`.
@Suite("ProtestKey Tests")
struct ProtestKeyTests {

    /// 2023-11-14 12:00:00 UTC. Mid-day so +6h stays on the same UTC date.
    private static let referenceDate = Date(timeIntervalSince1970: 1_699_963_200)

    /// All key-generation tests use a UTC calendar so day boundaries are
    /// stable regardless of the host machine's timezone. The production code
    /// defaults to Calendar.current which is correct for CDMX users; for
    /// determinism in tests we pin to UTC.
    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    // MARK: - Roundtrip

    @Test("make + timestamp roundtrip")
    func roundtrip() {
        let key = ProtestKey.make(lineNumber: "1", day: Self.referenceDate, calendar: Self.utcCalendar)
        let ts = ProtestKey.timestamp(from: key)
        #expect(ts != nil)
        let expected = Self.utcCalendar.startOfDay(for: Self.referenceDate).timeIntervalSince1970
        #expect(ts == expected)
    }

    @Test("same (line, day) produces identical keys for dedup")
    func sameInputsSameKey() {
        // 12:00 UTC and 18:00 UTC are unambiguously the same UTC day.
        let noon = Self.referenceDate
        let sameDayLater = noon.addingTimeInterval(6 * 60 * 60)
        let k1 = ProtestKey.make(lineNumber: "3", day: noon, calendar: Self.utcCalendar)
        let k2 = ProtestKey.make(lineNumber: "3", day: sameDayLater, calendar: Self.utcCalendar)
        #expect(k1 == k2, "two calls on the same UTC day should produce the same key")
    }

    @Test("different lines produce different keys")
    func differentLinesDifferentKeys() {
        let k1 = ProtestKey.make(lineNumber: "1", day: Self.referenceDate, calendar: Self.utcCalendar)
        let k2 = ProtestKey.make(lineNumber: "7", day: Self.referenceDate, calendar: Self.utcCalendar)
        #expect(k1 != k2)
    }

    @Test("different days produce different keys")
    func differentDaysDifferentKeys() {
        let day1 = Self.referenceDate
        let day2 = day1.addingTimeInterval(24 * 60 * 60)
        let k1 = ProtestKey.make(lineNumber: "1", day: day1, calendar: Self.utcCalendar)
        let k2 = ProtestKey.make(lineNumber: "1", day: day2, calendar: Self.utcCalendar)
        #expect(k1 != k2)
    }

    // MARK: - timestamp() robustness

    @Test("timestamp returns nil for keys without the protest_L prefix")
    func nilForWrongPrefix() {
        #expect(ProtestKey.timestamp(from: "") == nil)
        #expect(ProtestKey.timestamp(from: "random_string_1234.5") == nil)
        #expect(ProtestKey.timestamp(from: "Protest_L1_123") == nil) // case-sensitive
        #expect(ProtestKey.timestamp(from: "protest_X_123") == nil)
    }

    @Test("timestamp returns nil when tail isn't numeric")
    func nilForNonNumericTimestamp() {
        #expect(ProtestKey.timestamp(from: "protest_L1_notanumber") == nil)
        #expect(ProtestKey.timestamp(from: "protest_L1_") == nil)
    }

    @Test("timestamp survives a multi-character line identifier")
    func multiCharLine() {
        // Theoretical: BRT/M1/etc. While today lineNumber is always "1"-"7",
        // the parse should still work with longer identifiers.
        let key = "protest_LM1_1700000000.0"
        #expect(ProtestKey.timestamp(from: key) == 1_700_000_000.0)
    }

    @Test("timestamp uses the LAST underscore as separator (regression for split-last bug)")
    func lastUnderscoreSeparator() {
        // If lineNumber ever contains an underscore the OLD parser using
        // `split(_:on:).last` would have lost the timestamp. Our prefix-based
        // implementation finds the LAST underscore which keeps the timestamp
        // intact regardless of how many separators are in the line portion.
        let key = "protest_LX_Y_Z_1700000000.0"
        #expect(ProtestKey.timestamp(from: key) == 1_700_000_000.0)
    }

    // MARK: - Cleanup semantics

    @Test("keys older than 24h are filtered out, newer ones kept")
    func cleanupFiltersByAge() {
        let now = Date()
        let oneDayAgo = now.timeIntervalSince1970 - 86400
        let twoDaysAgo = now.timeIntervalSince1970 - 86400 * 2
        let halfDayAgo = now.timeIntervalSince1970 - 43200

        let cutoff = oneDayAgo
        let candidates: [(String, TimeInterval)] = [
            ("protest_L1_\(now.timeIntervalSince1970)", now.timeIntervalSince1970),
            ("protest_L2_\(halfDayAgo)", halfDayAgo),
            ("protest_L3_\(twoDaysAgo)", twoDaysAgo),
            ("garbage_key_42", -1), // unparseable → also filtered out
        ]

        let kept = candidates.filter { (key, _) in
            guard let ts = ProtestKey.timestamp(from: key) else { return false }
            return ts > cutoff
        }

        let keptLines = kept.map { $0.0 }
        #expect(keptLines.contains { $0.contains("L1") })
        #expect(keptLines.contains { $0.contains("L2") })
        #expect(keptLines.allSatisfy { !$0.contains("L3") })
        #expect(keptLines.allSatisfy { !$0.contains("garbage") })
    }
}
