import SwiftUI

/// Detail sheet for a station: full-size cenefa + every upcoming arrival +
/// the line's real-time status. Opened from the home "Ahora" card with a
/// zoom transition (the cenefa grows from the card — same object, closer).
struct StationDetailSheet: View {
    let station: GTFSStation
    /// Real-time status of the station's line, when the caller has it.
    var lineStatus: LineStatus? = nil

    /// nil = loading; empty = nothing upcoming.
    @State private var arrivals: [ScheduledArrival]?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    StationSignage(
                        stationName: station.name,
                        lineNumber: station.lineNumber,
                        pictogramAssetName: StationPictogram.assetName(for: station.id),
                        size: .large
                    )

                    if let lineStatus, lineStatus.hasIssues {
                        statusBanner(lineStatus)
                    }

                    arrivalsSection
                }
                .padding(Layout.screenMargin)
            }
            .navigationTitle(station.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Listo")) { dismiss() }
                }
            }
            .task(id: station.id) {
                arrivals = nil
                arrivals = await GTFSScheduleService.shared.nextArrivals(at: station.id, limit: 8)
            }
        }
    }

    // MARK: - Status banner

    private func statusBanner(_ line: LineStatus) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: line.status.icon)
                .foregroundStyle(StatusColors.color(for: line.status))
            VStack(alignment: .leading, spacing: 2) {
                Text(line.status.displayName)
                    .font(.subheadline.weight(.semibold))
                if let info = line.additionalInfo {
                    Text(info)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(Layout.cardInset)
        .surface(.elevated, cornerRadius: Layout.cornerRadiusMedium, tint: StatusColors.color(for: line.status))
    }

    // MARK: - Arrivals

    @ViewBuilder
    private var arrivalsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Próximas llegadas")
                .brandTitle(BrandTypography.lineLabel)
                .foregroundStyle(.secondary)

            if let arrivals {
                if arrivals.isEmpty {
                    Text("Sin horarios por ahora")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, Spacing.sm)
                } else {
                    TimelineView(.everyMinute) { context in
                        arrivalRows(arrivals, now: context.date)
                    }
                }
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack {
                            Capsule().fill(Color.secondary.opacity(0.25))
                                .frame(width: 52, height: 14)
                            Spacer()
                            Capsule().fill(Color.secondary.opacity(0.2))
                                .frame(width: 64, height: 12)
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .accessibilityLabel(String(localized: "Cargando llegadas"))
            }
        }
    }

    private func arrivalRows(_ arrivals: [ScheduledArrival], now: Date) -> some View {
        // CDMX clock, same convention as the schedule data.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Mexico_City") ?? .current
        let nowMinutes = calendar.component(.hour, from: now) * 60
            + calendar.component(.minute, from: now)

        return VStack(spacing: 0) {
            ForEach(Array(arrivals.enumerated()), id: \.element.id) { index, arrival in
                let wait = max(0, arrival.arrivalMinutes - nowMinutes)
                HStack(spacing: Spacing.sm) {
                    Text(arrival.arrivalTime)
                        .font(.body.weight(index == 0 ? .semibold : .regular))
                        .monospacedDigit()

                    if let headsign = arrival.headsign {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.bold))
                            Text(headsign)
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Text(StationNowCard.waitLabel(wait))
                        .font(.subheadline)
                        .foregroundStyle(index == 0 ? Color.primary : Color.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
                .padding(.vertical, Spacing.xs)
                .accessibilityElement(children: .combine)

                if index < arrivals.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, Layout.cardInset)
        .padding(.vertical, Spacing.xs)
        .surface(.base, cornerRadius: Layout.cornerRadiusMedium)
    }
}

#if DEBUG
#Preview("Station detail") {
    StationDetailSheet(station: GTFSStations.stations(for: "1").first!)
}
#endif
