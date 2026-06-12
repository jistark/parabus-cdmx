import Foundation
import Testing
@testable import ParabusCore

/// RelativeAge is the shared "act. hace N min" formatter used by AlertCard
/// and LineInlineDetail. The thresholds are load-bearing: the < 5 s branch
/// exists because RelativeDateTimeFormatter renders a just-fetched timestamp
/// as the future-tense "dentro de 0 s".
@Suite("RelativeAge Tests")
struct RelativeAgeTests {

    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    @Test("just fetched reads 'act. ahora'")
    func justNow() {
        #expect(RelativeAge.text(since: now, now: now) == "act. ahora")
        #expect(RelativeAge.text(since: now.addingTimeInterval(-4), now: now) == "act. ahora")
    }

    @Test("seconds bucket below one minute")
    func seconds() {
        #expect(RelativeAge.text(since: now.addingTimeInterval(-30), now: now) == "act. hace 30 s")
        #expect(RelativeAge.text(since: now.addingTimeInterval(-59), now: now) == "act. hace 59 s")
    }

    @Test("minutes bucket below one hour")
    func minutes() {
        #expect(RelativeAge.text(since: now.addingTimeInterval(-60), now: now) == "act. hace 1 min")
        #expect(RelativeAge.text(since: now.addingTimeInterval(-420), now: now) == "act. hace 7 min")
        #expect(RelativeAge.text(since: now.addingTimeInterval(-3599), now: now) == "act. hace 59 min")
    }

    @Test("hours bucket at one hour and beyond")
    func hours() {
        #expect(RelativeAge.text(since: now.addingTimeInterval(-3600), now: now) == "act. hace 1 h")
        #expect(RelativeAge.text(since: now.addingTimeInterval(-7800), now: now) == "act. hace 2 h")
    }

    @Test("future timestamps clamp to 'act. ahora'")
    func futureClamps() {
        #expect(RelativeAge.text(since: now.addingTimeInterval(120), now: now) == "act. ahora")
    }
}
