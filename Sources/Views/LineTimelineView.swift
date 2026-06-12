import CoreLocation
import SwiftUI

/// Tab Mapa, fase 1 del "Mapa híbrido" (Figma 19:152): timeline de estaciones
/// por línea con colapso de tramos suspendidos. Vista tonta sobre
/// TimelinePlanner; los datos son los mismos [LineStatus] del home — cero
/// fetching propio (maxim: consumo Cloudflare sano). Fase 2: inspector por
/// estación reutilizando RealtimeMapView.
struct LineTimelineView: View {
    @Environment(MetrobusViewModel.self) private var viewModel
    @State private var locationCoordinator = LocationCoordinator()
    @AppStorage("timeline.selectedLine") private var selectedLine = ""
    @State private var reversed = false

    private var lineNumber: String {
        if !selectedLine.isEmpty { return selectedLine }
        let favorites = (ParabusConstants.sharedDefaults?
            .string(forKey: ParabusConstants.favoriteLinesKey) ?? "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return favorites.first ?? "1"
    }

    private var lineStatus: LineStatus? {
        viewModel.allLines.first { $0.lineNumber == lineNumber }
    }

    private var items: [TimelineItem] {
        TimelinePlanner.resolve(
            stations: MBRouteOrder.orderedStations(for: lineNumber),
            incidents: lineStatus?.incidents ?? [],
            reversed: reversed
        )
    }

    private var nearestStationId: String? {
        guard let coord = locationCoordinator.latestLocation else { return nil }
        return GTFSStations.nearestStation(to: coord, inLine: lineNumber)?.id
    }

    private var lineColor: Color { LineColors.color(for: lineNumber) }

    /// `.topBarTrailing` no existe en macOS (target de `swift test`).
    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .automatic
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    cenefa
                        .padding(.bottom, Spacing.sm)
                    ForEach(items) { item in
                        timelineRow(for: item)
                    }
                }
                .padding(.horizontal, Layout.screenMargin)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("Mapa")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: trailingPlacement) {
                    if let updated = lineStatus?.lastUpdated {
                        Text(RelativeAge.text(since: updated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable { await viewModel.refresh() }
            .task {
                await viewModel.loadStatus()
                locationCoordinator.requestLocation()
            }
        }
    }

    // MARK: - Cenefa

    private var cenefa: some View {
        HStack(spacing: Spacing.sm) {
            Menu {
                ForEach(GTFSStations.allLines, id: \.number) { line in
                    Button {
                        selectedLine = line.number
                        reversed = false
                    } label: {
                        Label("\(line.name) · \(line.route)",
                              systemImage: line.number == lineNumber ? "checkmark" : "bus.fill")
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    LineBadge(number: lineNumber, transportType: .metrobus, size: .small)
                        .frame(width: 32, height: 32)
                    Text(routeTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .accessibilityLabel("Línea \(lineNumber). Toca para cambiar de línea")

            Spacer(minLength: Spacing.xs)

            Button {
                withAnimation(.snappy) { reversed.toggle() }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)   // hit target HIG (Figma: 44pt)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(Color.secondary.opacity(0.08), in: Circle())
            .accessibilityLabel("Invertir dirección")
            .accessibilityValue(routeTitle)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .surface(.floating, cornerRadius: Layout.cornerRadiusLarge)
    }

    private var routeTitle: String {
        let stations = MBRouteOrder.orderedStations(for: lineNumber)
        guard let first = stations.first, let last = stations.last else {
            return GTFSStations.allLines.first { $0.number == lineNumber }?.route ?? ""
        }
        let a = shortTerminal(first.name), b = shortTerminal(last.name)
        return reversed ? "\(b) - \(a)" : "\(a) - \(b)"
    }

    /// "Indios Verdes L1" → "Indios Verdes" (el sufijo de plataforma es ruido
    /// en el título de cenefa).
    private func shortTerminal(_ name: String) -> String {
        name.replacingOccurrences(of: #" L\d+( (Norte|Sur|Ote|Pte))?$"#,
                                  with: "", options: .regularExpression)
    }

    // MARK: - Rows

    @ViewBuilder
    private func timelineRow(for item: TimelineItem) -> some View {
        switch item {
        case .station(let s):
            TimelineStationRow(item: s, lineColor: lineColor,
                               isCurrent: s.station.id == nearestStationId)

        case .interruptedSegment(let seg):
            HStack(alignment: .top, spacing: Spacing.sm) {
                TimelineRail(color: lineColor, style: .dashed, node: .none)
                    .overlay(ghostNodes)
                InterruptionCard(segment: seg,
                                 lastUpdated: lineStatus?.lastUpdated ?? .now)
                    .padding(.vertical, Spacing.xs)
            }

        case .wholeLineBanner(let incident):
            wholeLineBanner(incident)
        }
    }

    /// Nodos fantasma equiespaciados sobre el punteado — uno por estación
    /// colapsada hasta un máximo visual de 3 (más sería ruido).
    private var ghostNodes: some View {
        VStack {
            Spacer()
            ForEach(0..<3, id: \.self) { _ in
                TimelineRail(color: lineColor, style: .none, node: .ghost)
                    .frame(height: 10)
                Spacer()
            }
        }
    }

    private func wholeLineBanner(_ incident: Incident) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: incident.status.icon)
                .foregroundStyle(StatusColors.color(for: incident.status))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(incident.status.displayName) · toda la línea")
                    .font(.subheadline.weight(.semibold))
                if let info = incident.info, !info.isEmpty {
                    Text(info).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(Layout.cardInset)
        .surface(.elevated, cornerRadius: Layout.cornerRadiusMedium,
                 tint: StatusColors.color(for: incident.status))
        .padding(.bottom, Spacing.sm)
    }
}

#Preview("Timeline con interrupción") {
    LineTimelineView()
        .environment(MetrobusViewModel())
}
