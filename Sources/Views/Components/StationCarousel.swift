import SwiftUI

/// Carrusel paginado horizontal de StationSignage.large.
/// Posicionado al fondo del map. Cada item es la cenefa de una estación
/// en la línea actual. Notifica al parent vía `selectedStationId`.
struct StationCarousel: View {

    let stations: [GTFSStation]
    @Binding var selectedStationId: String?
    let onMBTap: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: Spacing.md) {
                ForEach(stations) { station in
                    StationSignage(
                        stationName: station.name,
                        lineNumber: station.lineNumber,
                        pictogramAssetName: StationPictogram.assetName(for: station.id),
                        size: .large,
                        onMBTap: onMBTap
                    )
                    .containerRelativeFrame(.horizontal, count: 1, spacing: Spacing.md)
                    .id(station.id)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, Layout.screenMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedStationId, anchor: .center)
    }
}

#if DEBUG
private struct CarouselPreviewWrapper: View {
    @State private var selected: String? = GTFSStations.stations(for: "1").first?.id
    var body: some View {
        StationCarousel(
            stations: GTFSStations.stations(for: "1"),
            selectedStationId: $selected,
            onMBTap: { print("MB tapped") }
        )
        .frame(height: 80)
        .padding(.vertical)
    }
}

#Preview {
    CarouselPreviewWrapper()
}
#endif
