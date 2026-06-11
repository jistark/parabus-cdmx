// Sources/Models/ArrivalRowPresentation.swift
import Foundation

/// Pure ArrivalRow → display mapping (spec 2 §2). Views translate `tone`
/// to colors via StatusColors so the palette stays in the theme layer.
struct ArrivalRowPresentation: Equatable {
    enum Tone { case positive, negative, neutral, muted }
    enum Marquee { case none, arriving, departed }

    let statusText: String
    let tone: Tone
    let marquee: Marquee
    /// True for schedule-sourced rows — the honest "this is timetable,
    /// not GPS" clock glyph.
    let showsClock: Bool

    init(row: ArrivalRow) {
        switch row.state {
        case .arriving:
            statusText = String(localized: "LLEGANDO")
            tone = .positive
            marquee = .arriving
            showsClock = false
        case .departed:
            statusText = String(localized: "DEJÓ LA ESTACIÓN")
            tone = .negative
            marquee = .departed
            showsClock = false
        case .eta:
            statusText = row.etaMinutes.map { "\($0) MIN" } ?? "—"
            tone = .neutral
            marquee = .none
            showsClock = false
        case .scheduled:
            statusText = row.etaMinutes.map { "\($0) MIN" } ?? "—"
            tone = .muted
            marquee = .none
            showsClock = true
        }
    }
}

/// Hex parsing split from SwiftUI.Color so it's testable on the macOS
/// test target without color-space equality games.
enum ColorHex {
    static func components(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xFF) / 255.0,
            Double((value >> 8) & 0xFF) / 255.0,
            Double(value & 0xFF) / 255.0
        )
    }
}
