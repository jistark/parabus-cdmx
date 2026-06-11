import SwiftUI

/// Swipeable deck of "Ahora" cards (spec 2 §2). Page dots only when there
/// is something to swipe to. Selection drives the polling surface via the
/// view model (the binding's setter).
struct NowDeck<Card: View>: View {
    let deck: [HomeViewModel.DeckEntry]
    @Binding var visibleIndex: Int
    @ViewBuilder let card: (HomeViewModel.DeckEntry) -> Card

    var body: some View {
        #if os(iOS)
        TabView(selection: $visibleIndex) {
            ForEach(Array(deck.enumerated()), id: \.element.id) { index, entry in
                card(entry)
                    .tag(index)
                    .padding(.horizontal, Layout.screenMargin)
                    // Lift the card off the bottom of the pager frame so the
                    // page dots render below it instead of over it.
                    .padding(.bottom, deck.count > 1 ? Spacing.lg : 0)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: deck.count > 1 ? .automatic : .never))
        .frame(height: deckHeight)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        #else
        // macOS test target: page style unavailable; render the visible card.
        if let entry = deck.indices.contains(visibleIndex) ? deck[visibleIndex] : deck.first {
            card(entry).padding(.horizontal, Layout.screenMargin)
        }
        #endif
    }

    /// Scales with Dynamic Type so the pager frame grows with the text.
    /// Budget: cardInset×2 (32) + mini-cenefa header (36) + 12 spacing
    /// + 3 rows (~73 with xs gaps) + commute divider+row (~45) ≈ 198,
    /// plus ~26 of page-dot clearance below → 224 at default size.
    @ScaledMetric(relativeTo: .body) private var deckHeight: CGFloat = 224
}
