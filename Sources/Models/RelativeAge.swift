import Foundation

/// Shared "act. hace N min" age formatting for status cards (AlertCard,
/// LineInlineDetail).
///
/// Manual formatting — RelativeDateTimeFormatter renders a just-fetched
/// timestamp as the future-tense "dentro de 0 s". "act." (actualizado)
/// because `lastUpdated` is the fetch time, not the incident start — the
/// worker doesn't expose incident start time; first-seen tracking is a
/// spec-3 candidate.
enum RelativeAge {
    static func text(since date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 5 { return String(localized: "act. ahora") }
        if seconds < 60 { return String(localized: "act. hace \(seconds) s") }
        if seconds < 3600 { return String(localized: "act. hace \(seconds / 60) min") }
        return String(localized: "act. hace \(seconds / 3600) h")
    }
}
