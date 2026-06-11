import SwiftUI

/// Commute leg context for the "Ahora" card: where the traveler is heading
/// during their commute window, so the card can show destination + travel
/// time + the line's health in one glance.
struct CommuteLegContext: Equatable {
    let legName: String   // "ida" / "regreso"
    let originId: String
    let destinationId: String
    let destinationName: String
}

/// Hero "Ahora" card for the home tab. Speaks the same visual language as
/// the map's mini-cenefa (LineBlock + station title + caption) so station
/// identity reads identically across the app, then answers the traveler's
/// question with one row per platform direction:
///
///   [3] AMORES
///       La más cercana · a 380 m
///   🚌 → Tepalcates           Llegando
///   🚌 → Tacubaya             4 min
///
/// During the commute window it grows a trayecto row (destination · travel
/// time · line health).
struct StationNowCard: View {
    let station: GTFSStation
    let source: NowStationResolver.Source
    /// Meters from the user to the station, when a GPS fix exists.
    let distanceMeters: Double?
    /// Present only inside the commute window.
    var commute: CommuteLegContext? = nil
    /// Real-time status of the station's line (from the shared view model).
    var lineStatus: ServiceStatus? = nil
    /// Live arrival rows from HomeViewModel — nil means "use the legacy
    /// schedule-only path" (worker down, stop uncovered, or pre-first-poll).
    var liveRows: [ArrivalRow]? = nil
    /// serviceId → cenefa hex colors (interlínea carries two).
    var serviceColors: [String: [String]] = [:]

    /// nil = loading (skeleton); empty = schedule has nothing upcoming.
    @State private var fetched: (buses: [UpcomingBus], at: Date)?
    /// "~35 min" once the worker answers; nil while loading or unavailable.
    @State private var travelTime: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Mini-cenefa header — same composition as the map's status bar.
            HStack(spacing: Spacing.sm) {
                LineBlock(lineNumber: station.lineNumber, size: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(station.name)
                        .brandTitle(BrandTypography.lineLabel)
                        .foregroundStyle(.primary)
                    Text(sourceCaption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                Spacer(minLength: 0)

                if let distance = distanceText {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                        Text(distance)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            busRows

            if commute != nil {
                Divider()
                commuteRow
            }
        }
        .padding(Layout.cardInset)
        .surface(.base, cornerRadius: Layout.cornerRadiusMedium)
        .task(id: station.id) {
            guard liveRows == nil else { return }
            await loadArrivals()
        }
        // Re-arm on every fetch: sleep until the lead bus has arrived
        // (+30 s grace), then refetch so the rows advance on their own.
        // Cancelled automatically when the card leaves the screen.
        .task(id: fetched?.at) {
            guard liveRows == nil else { return }
            guard let fetched, let first = fetched.buses.first?.waitMinutes else { return }
            try? await Task.sleep(for: .seconds(TimeInterval(first * 60 + 30)))
            guard !Task.isCancelled else { return }
            await loadArrivals()
        }
        .task(id: commute) {
            guard let commute else { return }
            travelTime = await GTFSScheduleService.shared.travelTimeString(
                from: commute.originId,
                to: commute.destinationId
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func loadArrivals() async {
        // First load shows the skeleton; expiry refetches keep the old rows
        // visible (HIG loading: never hide data behind a loader).
        let buses = await GTFSScheduleService.shared.upcomingBuses(at: station.id, limit: 3)
        fetched = (buses, Date())
    }

    // MARK: - Commute row

    @ViewBuilder
    private var commuteRow: some View {
        if let commute {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(commute.destinationName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let travelTime {
                    Text("· \(travelTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: Spacing.sm)

                if let lineStatus, lineStatus != .regular {
                    lineHealthChip(lineStatus)
                }
            }
        }
    }

    /// Actionable line-health chip: "your line has delays — leave earlier".
    private func lineHealthChip(_ status: ServiceStatus) -> some View {
        HStack(spacing: 3) {
            Image(systemName: status.icon)
                .font(.caption2.weight(.bold))
            Text(status.displayName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(StatusColors.color(for: status))
    }

    // MARK: - Bus rows (one per platform direction)

    @ViewBuilder
    private var busRows: some View {
        if let liveRows {
            if liveRows.isEmpty {
                Text("Sin servicio por ahora")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(liveRows, id: \.self) { row in
                        liveRow(row)
                    }
                }
                .animation(reduceMotion ? nil : .default, value: liveRows)
            }
        } else {
            legacyRows
        }
    }

    @ViewBuilder
    private var legacyRows: some View {
        if let fetched {
            if fetched.buses.isEmpty {
                Text("Sin horarios por ahora")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                // Re-render each minute so the countdowns age without
                // refetching — the schedule data itself doesn't change.
                TimelineView(.everyMinute) { context in
                    let elapsed = Int(context.date.timeIntervalSince(fetched.at) / 60)
                    VStack(spacing: Spacing.xs) {
                        ForEach(Array(fetched.buses.enumerated()), id: \.offset) { index, bus in
                            busRow(
                                bus,
                                wait: max(0, bus.waitMinutes - elapsed),
                                emphasized: index == 0
                            )
                        }
                    }
                }
            }
        } else {
            // Skeleton rows where the buses will be.
            VStack(spacing: Spacing.xs) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack {
                        Capsule().fill(Color.secondary.opacity(0.25))
                            .frame(width: 120, height: 13)
                        Spacer()
                        Capsule().fill(Color.secondary.opacity(0.2))
                            .frame(width: 44, height: 13)
                    }
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func busRow(_ bus: UpcomingBus, wait: Int, emphasized: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "bus.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(LineColors.color(for: station.lineNumber))

            if let headsign = bus.headsign {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(headsign)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                Text("Próximo bus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.sm)

            Text(Self.waitLabel(wait))
                .font(.subheadline.weight(emphasized ? .semibold : .regular))
                .foregroundStyle(emphasized ? Color.primary : Color.secondary)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
    }

    static func waitLabel(_ minutes: Int) -> String {
        minutes <= 0 ? String(localized: "Llegando") : String(localized: "\(minutes) min")
    }

    // MARK: - Live row

    private func liveRow(_ row: ArrivalRow) -> some View {
        let presentation = ArrivalRowPresentation(row: row)
        return HStack(spacing: Spacing.sm) {
            Image(systemName: "bus.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(serviceTint(for: row))

            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(row.destination)
                    .brandTitle(BrandTypography.statusLabel) // Movin caps — señalética; statusLabel (15pt/subheadline) fits inline without crowding
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: Spacing.sm)

            HStack(spacing: 3) {
                if presentation.showsClock {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if presentation.marquee == .arriving {
                    ChevronMarquee(direction: .arriving, tint: tone(presentation.tone))
                } else if presentation.marquee == .departed {
                    ChevronMarquee(direction: .departed, tint: tone(presentation.tone))
                }
                Text(presentation.statusText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tone(presentation.tone))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hacia \(row.destination), \(presentation.statusText)")
    }

    private func tone(_ tone: ArrivalRowPresentation.Tone) -> Color {
        switch tone {
        case .positive: StatusColors.good
        case .negative: StatusColors.critical
        case .neutral: .primary
        case .muted: .secondary
        }
    }

    /// Cenefa service color (interlínea = first color; gradient deferred);
    /// falls back to the station's line color.
    private func serviceTint(for row: ArrivalRow) -> Color {
        if let hex = serviceColors[row.serviceId]?.first, let color = Color(hexString: hex) {
            return color
        }
        return LineColors.color(for: row.line)
    }

    // MARK: - Caption

    private var sourceCaption: String {
        switch source {
        case .commute(let leg):
            return leg == "ida"
                ? String(localized: "Tu estación de ida")
                : String(localized: "Tu estación de regreso")
        case .nearest:
            if distanceText != nil {
                return String(localized: "La más cercana")
            }
            return String(localized: "La más cercana a ti")
        case .lastViewed:
            return String(localized: "Tu última estación")
        case .fallback:
            return String(localized: "Línea \(station.lineNumber)")
        }
    }

    private var distanceText: String? {
        guard let meters = distanceMeters else { return nil }
        if meters < 950 {
            return String(localized: "a \(Int(meters / 10) * 10) m")
        }
        return String(localized: "a \(String(format: "%.1f", meters / 1000)) km")
    }

    private var accessibilityLabel: String {
        var label = String(localized: "Estación \(station.name), línea \(station.lineNumber). \(sourceCaption).")
        if let distance = distanceText {
            label += " " + distance + "."
        }
        if let liveRows {
            if liveRows.isEmpty {
                label += " " + String(localized: "Sin servicio por ahora.")
            } else {
                let times = liveRows.map { row in
                    let presentation = ArrivalRowPresentation(row: row)
                    return String(localized: "hacia \(row.destination), \(presentation.statusText)")
                }.joined(separator: "; ")
                label += " " + String(localized: "Próximos buses: \(times).")
            }
        } else if let fetched {
            if fetched.buses.isEmpty {
                label += " " + String(localized: "Sin horarios por ahora.")
            } else {
                let times = fetched.buses.map { bus in
                    if let headsign = bus.headsign {
                        return String(localized: "hacia \(headsign), \(Self.waitLabel(bus.waitMinutes))")
                    }
                    return Self.waitLabel(bus.waitMinutes)
                }.joined(separator: "; ")
                label += " " + String(localized: "Próximos buses: \(times).")
            }
        }
        if let commute {
            label += " " + String(localized: "Hacia \(commute.destinationName).")
            if let travelTime {
                label += " " + String(localized: "Trayecto \(travelTime).")
            }
            if let lineStatus, lineStatus != .regular {
                label += " " + lineStatus.displayName + "."
            }
        }
        return label
    }
}

#if DEBUG
#Preview("Now card") {
    VStack {
        if let station = GTFSStations.stations(for: "1").first {
            StationNowCard(
                station: station,
                source: .nearest,
                distanceMeters: 430
            )
        }
    }
    .padding()
}

#Preview("Live rows") {
    VStack {
        if let station = GTFSStations.stations(for: "1").first {
            StationNowCard(
                station: station,
                source: .nearest,
                distanceMeters: 380,
                liveRows: [
                    ArrivalRow(
                        serviceId: "MB1-IDA",
                        line: "1",
                        destination: "Tepalcates",
                        state: .arriving,
                        etaMinutes: nil,
                        vehicleId: "MB-042",
                        source: .realtime
                    ),
                    ArrivalRow(
                        serviceId: "MB1-IDA",
                        line: "1",
                        destination: "Indios Verdes",
                        state: .eta,
                        etaMinutes: 4,
                        vehicleId: "MB-017",
                        source: .realtime
                    ),
                    ArrivalRow(
                        serviceId: "MB1-REGRESO",
                        line: "1",
                        destination: "El Caminero",
                        state: .departed,
                        etaMinutes: nil,
                        vehicleId: "MB-031",
                        source: .realtime
                    )
                ]
            )
        }
    }
    .padding()
}
#endif
