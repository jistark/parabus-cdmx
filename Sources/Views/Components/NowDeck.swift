import SwiftUI

/// Reports a card's natural content height; the deck takes the max so the
/// pager frame fits the tallest card at any Dynamic Type size.
private struct DeckCardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Swipeable deck of "Ahora" cards (spec 2 §2). Page dots only when there
/// is something to swipe to. Selection drives the polling surface via the
/// view model (the binding's setter).
///
/// Sizing: content-hugging via PreferenceKey measurement — each card reports
/// its natural height and the pager frame becomes `max(heights) + dot
/// clearance`. The old fixed `@ScaledMetric` budget (224pt) centered a 2-row
/// card in ~70pt of dead space; measuring kills that void and stays correct
/// under Dynamic Type for free (the preference re-fires on relayout).
struct NowDeck<Card: View>: View {
    let deck: [HomeViewModel.DeckEntry]
    @Binding var visibleIndex: Int
    @ViewBuilder let card: (HomeViewModel.DeckEntry) -> Card

    /// Tallest measured card height. nil for the single frame before the
    /// first preference arrives, where `placeholderHeight` stands in.
    @State private var measuredHeight: CGFloat?

    /// Room reserved under the card for the page dots — the ONE constant in
    /// this layout (everything else is measured). Keeps the dots tight under
    /// the card (~Figma's 8pt visual gap) instead of the old ~40pt drift.
    @ScaledMetric(relativeTo: .body) private var dotClearance: CGFloat = 16

    /// Pre-measurement stand-in (≈ a 2-row card) so the first frame doesn't
    /// collapse to zero height; replaced by the real measurement immediately.
    @ScaledMetric(relativeTo: .body) private var placeholderHeight: CGFloat = 150

    var body: some View {
        #if os(iOS)
        TabView(selection: $visibleIndex) {
            ForEach(Array(deck.enumerated()), id: \.element.id) { index, entry in
                card(entry)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: DeckCardHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
                    // Top-align inside the page so a shorter card doesn't
                    // float vertically centered in the tallest card's frame.
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, Layout.screenMargin)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: deck.count > 1 ? .automatic : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        // Capture the binding (Sendable), not self: onPreferenceChange takes
        // a @Sendable closure under Swift 6 and the view itself isn't.
        .onPreferenceChange(DeckCardHeightKey.self) { [$measuredHeight] height in
            $measuredHeight.wrappedValue = height
        }
        .frame(
            height: (measuredHeight ?? placeholderHeight)
                + (deck.count > 1 ? dotClearance : 0)
        )
        #else
        // macOS test target: page style unavailable; render the visible card.
        if let entry = deck.indices.contains(visibleIndex) ? deck[visibleIndex] : deck.first {
            card(entry).padding(.horizontal, Layout.screenMargin)
        }
        #endif
    }
}

#if DEBUG && os(iOS)
/// Mirrors the home column rhythm (header → deck → section header) so the
/// spacing pass can be eyeballed against the Figma frame.
private struct NowDeckPreviewHost: View {
    let cardCount: Int
    @State private var index = 0

    var body: some View {
        let stations = Array(GTFSStations.stations(for: "1").prefix(cardCount))
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                Text("PARABÚS")
                    .font(.title.weight(.heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Layout.screenMargin)

                NowDeck(
                    deck: stations.enumerated().map { offset, station in
                        HomeViewModel.DeckEntry(
                            station: station,
                            source: offset == 0 ? .nearest : .commute(leg: "ida")
                        )
                    },
                    visibleIndex: $index
                ) { entry in
                    StationNowCard(
                        station: entry.station,
                        source: entry.source,
                        distanceMeters: 380,
                        // Vary row counts across pages to exercise the
                        // top-alignment of shorter cards.
                        liveRows: Array(previewRows.prefix(entry.source == .nearest ? 2 : 3))
                    )
                }

                Text("Tus líneas")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Layout.screenMargin)
            }
            .padding(.vertical, Layout.cardInset)
        }
    }

    private var previewRows: [ArrivalRow] {
        [
            ArrivalRow(
                serviceId: "MB1-IDA", line: "1", destination: "Tepalcates",
                state: .arriving, etaMinutes: nil, vehicleId: "MB-042", source: .realtime
            ),
            ArrivalRow(
                serviceId: "MB1-IDA", line: "1", destination: "Indios Verdes",
                state: .eta, etaMinutes: 4, vehicleId: "MB-017", source: .realtime
            ),
            ArrivalRow(
                serviceId: "MB1-REGRESO", line: "1", destination: "El Caminero",
                state: .departed, etaMinutes: nil, vehicleId: "MB-031", source: .realtime
            )
        ]
    }
}

#Preview("Single card") {
    NowDeckPreviewHost(cardCount: 1)
}

#Preview("Deck ×3") {
    NowDeckPreviewHost(cardCount: 3)
}

#Preview("Deck ×3 — dark") {
    NowDeckPreviewHost(cardCount: 3)
        .preferredColorScheme(.dark)
}
#endif
