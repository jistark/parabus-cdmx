import Foundation
import SwiftUI
import Testing
@testable import ParabusCore

/// SeveritySymbol is the pure-function color/icon mapper used by both the
/// widget extension and the Live Activity. It lives outside any `#if os(iOS)`
/// guard so swift test on the macOS host can verify the mapping.
///
/// The mapping is load-bearing: a wrong value here renders a Live Activity
/// protest (highest urgency) as a green checkmark — REVIEW HIGH-17 caught
/// exactly that regression in the previous implementation.
@Suite("SeveritySymbol Tests")
struct SeveritySymbolTests {

    @Test("icon mapping covers all 7 ServiceStatus severities")
    func iconCoverage() {
        // Verify every severity rung has a distinct, non-empty SF Symbol name.
        let icons = (0...6).map { SeveritySymbol.icon(severity: $0) }
        #expect(icons.allSatisfy { !$0.isEmpty })
        #expect(Set(icons).count == icons.count, "every severity should have a unique icon")
    }

    @Test("icon mapping has the exact expected SF Symbols (regression for HIGH-17)")
    func iconExactValues() {
        // Frozen so a careless edit to the switch body trips this test.
        #expect(SeveritySymbol.icon(severity: 0) == "checkmark.circle.fill")
        #expect(SeveritySymbol.icon(severity: 1) == "questionmark.circle.fill")
        #expect(SeveritySymbol.icon(severity: 2) == "wrench.and.screwdriver.fill")
        #expect(SeveritySymbol.icon(severity: 3) == "arrow.left.arrow.right")
        #expect(SeveritySymbol.icon(severity: 4) == "clock.badge.exclamationmark")
        #expect(SeveritySymbol.icon(severity: 5) == "exclamationmark.octagon.fill")
        #expect(SeveritySymbol.icon(severity: 6) == "megaphone.fill")
    }

    @Test("out-of-range severity falls back to regular (defensive)")
    func iconFallback() {
        // Sinoptico Plus shouldn't emit severity > 6, but make sure we don't
        // crash or return garbage if it does.
        #expect(SeveritySymbol.icon(severity: 7) == "checkmark.circle.fill")
        #expect(SeveritySymbol.icon(severity: -1) == "checkmark.circle.fill")
        #expect(SeveritySymbol.icon(severity: Int.max) == "checkmark.circle.fill")
    }

    @Test("color mapping returns distinct colors for top 4 urgent levels")
    func colorDistinctness() {
        // The top urgent rungs (delayed, limited, suspended, protest) must be
        // visually distinct — color-blind users rely on hue separation, not
        // just intensity. We check that the rendered Color values differ.
        let protestC = SeveritySymbol.color(severity: 6)
        let suspendedC = SeveritySymbol.color(severity: 5)
        let delayedC = SeveritySymbol.color(severity: 4)
        let limitedC = SeveritySymbol.color(severity: 3)

        // SwiftUI Color doesn't conform to Equatable in a useful way for
        // semantic colors; compare via descriptions.
        let descriptions = [protestC, suspendedC, delayedC, limitedC].map { String(describing: $0) }
        #expect(Set(descriptions).count == 4, "expected 4 distinct colors, got \(descriptions)")
    }

    @Test("color mapping returns regular (green) for severity 0")
    func colorRegular() {
        let c = SeveritySymbol.color(severity: 0)
        let description = String(describing: c)
        #expect(description.contains("green"), "severity 0 should be green; got \(description)")
    }
}
