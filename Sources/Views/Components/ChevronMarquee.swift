import SwiftUI

/// Three-chevron walking-light animation indicating bus arrival direction.
///
/// **Animation choice — `TimelineView` not `phaseAnimator`:**
/// `phaseAnimator`'s content closure signature is `(content: Content, phase: Phase) -> some View`
/// where `content` is the *same* view being modified — it cannot rebuild the row with different
/// per-chevron opacities on each phase. Replacing `content` entirely inside the closure bypasses
/// the interpolation engine, producing a jump-cut rather than a smooth fade.
/// `TimelineView(.animation(minimumInterval: 0.4))` redraws every ~0.4 s, and a simple
/// `Int(date.timeIntervalSinceReferenceDate / 0.4) % 3` gives us a clean `0→1→2→0…` cycle.
/// Each chevron image's `.opacity` is then driven by that integer, and SwiftUI animates the
/// opacity change via the `.animation(.easeInOut(duration: 0.4), value: litIndex)` modifier.
struct ChevronMarquee: View {

    // MARK: - Public API

    enum Direction { case arriving, departed }

    let direction: Direction
    let tint: Color

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        if reduceMotion {
            // Reduce Motion: all three chevrons fully opaque, no movement.
            chevronRow(litIndex: nil)
        } else {
            TimelineView(.animation(minimumInterval: 0.4, paused: false)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.4) % 3
                let lit = direction == .arriving ? tick : (2 - tick)
                chevronRow(litIndex: lit)
                    .animation(.easeInOut(duration: 0.4), value: lit)
            }
        }
    }

    // MARK: - Helpers

    private var symbol: String {
        direction == .arriving ? "chevron.right" : "chevron.left"
    }

    @ViewBuilder
    private func chevronRow(litIndex: Int?) -> some View {
        HStack(spacing: -1) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: symbol)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(tint)
                    .opacity(litIndex == nil || litIndex == index ? 1.0 : 0.25)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Marquee states") {
    VStack(alignment: .trailing, spacing: 16) {
        HStack(spacing: 4) {
            ChevronMarquee(direction: .arriving, tint: .green)
            Text("LLEGANDO").font(.caption.weight(.bold)).foregroundStyle(.green)
        }
        HStack(spacing: 4) {
            ChevronMarquee(direction: .departed, tint: .red)
            Text("DEJÓ LA ESTACIÓN").font(.caption.weight(.bold)).foregroundStyle(.red)
        }
    }
    .padding()
}
#endif
