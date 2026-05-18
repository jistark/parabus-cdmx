import SwiftUI

// MARK: - Affected Stations Card
//
// Primary visualization inside `LineDetailSheet`: surfaces which stations are
// affected by the active incident(s) at-a-glance. Three rendering paths:
//
//   1. Entire line — incident says "Línea Completa" or `affectedStations` is
//      empty. Hero "TODA LA LÍNEA" treatment with the total station count.
//
//   2. Specific stations — affected names matched against the canonical
//      `GTFSStations` list (fuzzy: diacritic-insensitive, case-insensitive,
//      contains-match to tolerate suffixes like "L1"). Vertical list of
//      affected stations + a "rest of the line operating normal" footer.
//
//   3. Segment notation — a single string with " - " separator (e.g.
//      "Plaza de la República - Vocacional 5") is split into endpoints and
//      both are surfaced individually.
//
// We deliberately don't draw a geographic timeline: `GTFSStations` is sorted
// alphabetically (no GTFS route order on the client post HIGH-16), so a
// vertical "line map" would be a lie. The count + list reads honestly.

struct AffectedStationsCard: View {
    let lineNumber: String
    let incidents: [Incident]

    private struct AffectedStation: Identifiable {
        let id: String
        let displayName: String
        let canonicalName: String?  // matched GTFSStation name, if any
        let worstStatus: ServiceStatus
    }

    private var allLineStations: [GTFSStation] {
        GTFSStations.stations(for: lineNumber)
    }

    private var totalStations: Int { allLineStations.count }

    /// True when any incident signals the whole line — either an explicit
    /// "Línea Completa" / "Toda la línea" sentinel, or an empty affected list.
    private var entireLine: Bool {
        guard !incidents.isEmpty else { return false }
        return incidents.contains { incident in
            if incident.affectedStations.isEmpty { return true }
            return incident.affectedStations.contains(where: Self.isWholeLineSentinel)
        }
    }

    private static func isWholeLineSentinel(_ name: String) -> Bool {
        let normalized = name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        return normalized.contains("linea completa") || normalized.contains("toda la linea")
    }

    /// Worst-status aggregation across all incidents, keyed by display name.
    /// Splits " - " segment markers into individual stations; skips sentinels.
    private var affectedStations: [AffectedStation] {
        var aggregated: [String: ServiceStatus] = [:]
        for incident in incidents {
            for rawName in incident.affectedStations where !Self.isWholeLineSentinel(rawName) {
                let names = rawName.contains(" - ")
                    ? rawName.components(separatedBy: " - ")
                    : [rawName]
                for piece in names {
                    let cleaned = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleaned.isEmpty else { continue }
                    if let existing = aggregated[cleaned], existing.severity >= incident.status.severity {
                        continue
                    }
                    aggregated[cleaned] = incident.status
                }
            }
        }
        return aggregated
            .sorted { $0.key < $1.key }
            .map { name, status in
                AffectedStation(
                    id: name,
                    displayName: name,
                    canonicalName: Self.matchToCanonical(name, stations: allLineStations),
                    worstStatus: status
                )
            }
    }

    /// Fuzzy match — diacritic-insensitive, case-insensitive, both directions
    /// (incident name might be "Plaza de la República"; canonical might be
    /// "Plaza de la República L1"). Returns the canonical name if found.
    private static func matchToCanonical(_ name: String, stations: [GTFSStation]) -> String? {
        let normalized = name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        return stations.first { station in
            let canonical = station.name.lowercased().folding(options: .diacriticInsensitive, locale: .current)
            return canonical == normalized
                || canonical.contains(normalized)
                || normalized.contains(canonical)
        }?.name
    }

    private var worstStatusOverall: ServiceStatus {
        incidents.map(\.status).max(by: { $0.severity < $1.severity }) ?? .unknown
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header

            if entireLine {
                entireLineView
            } else if affectedStations.isEmpty {
                noStationsView
            } else {
                stationsList
                if totalStations > 0 {
                    operationalFooter
                }
            }
        }
        .padding(Layout.cardInset)
        .surface(.base, cornerRadius: Layout.cornerRadiusMedium)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Estaciones afectadas")
                .brandTitle(BrandTypography.lineLabel)
                .foregroundStyle(.secondary)
            Spacer()
            countChip
        }
    }

    @ViewBuilder
    private var countChip: some View {
        if entireLine {
            Text(totalStations > 0 ? "TODA LA LÍNEA · \(totalStations)" : "TODA LA LÍNEA")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .padding(.horizontal, Layout.pillInset)
                .padding(.vertical, 4)
                .background(worstStatusOverall == .unknown
                            ? StatusColors.critical.opacity(SurfaceOpacity.tintMedium)
                            : StatusColors.color(for: worstStatusOverall).opacity(SurfaceOpacity.tintMedium),
                            in: Capsule())
                .foregroundStyle(worstStatusOverall == .unknown
                                 ? StatusColors.critical
                                 : StatusColors.color(for: worstStatusOverall))
        } else if !affectedStations.isEmpty {
            Text("\(affectedStations.count)\(totalStations > 0 ? " de \(totalStations)" : "")")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .padding(.horizontal, Layout.pillInset)
                .padding(.vertical, 4)
                .background(StatusColors.color(for: worstStatusOverall).opacity(SurfaceOpacity.tintMedium), in: Capsule())
                .foregroundStyle(StatusColors.color(for: worstStatusOverall))
        }
    }

    // MARK: - Entire-line treatment

    private var entireLineView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: StatusColors.icon(for: worstStatusOverall))
                    .font(.title2)
                    .foregroundStyle(StatusColors.color(for: worstStatusOverall))
                Text("Servicio afectado en toda la ruta")
                    .font(.subheadline.weight(.semibold))
            }

            if totalStations > 0 {
                Text("Las \(totalStations) estaciones de la línea están comprometidas hasta nuevo aviso.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Servicio comprometido hasta nuevo aviso.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Affected list

    private var stationsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(affectedStations.enumerated()), id: \.element.id) { index, station in
                stationRow(station)
                if index < affectedStations.count - 1 {
                    Divider().padding(.leading, 28)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusSmall, style: .continuous)
                .fill(Color.secondary.opacity(SurfaceOpacity.tintSubtle))
        )
    }

    private func stationRow(_ station: AffectedStation) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(StatusColors.color(for: station.worstStatus))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(station.canonicalName ?? station.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if station.canonicalName == nil {
                    Text("Estación no reconocida")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(StatusColors.shortText(for: station.worstStatus))
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(StatusColors.color(for: station.worstStatus))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs + 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(station.canonicalName ?? station.displayName), \(station.worstStatus.accessibilityLabel)")
    }

    // MARK: - Operational footer

    private var operationalFooter: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(StatusColors.good)
            let remaining = max(0, totalStations - affectedStations.count)
            Text(remaining == 0
                 ? "Sin estaciones operando"
                 : "Resto de la línea operando normal · \(remaining) estaciones")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty / fallback

    private var noStationsView: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
            Text("Sin detalle de estaciones disponible")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
#Preview("Toda la línea") {
    AffectedStationsCard(
        lineNumber: "1",
        incidents: [
            Incident(status: .suspended, affectedStations: ["Línea Completa"], info: "Retraso en el servicio por evento deportivo")
        ]
    )
    .padding()
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}

#Preview("Segmento") {
    AffectedStationsCard(
        lineNumber: "4",
        incidents: [
            Incident(status: .suspended, affectedStations: ["Plaza de la República - Vocacional 5"], info: "Por reencarpetamiento en Ponciano Arriaga desvío")
        ]
    )
    .padding()
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}

#Preview("Múltiples estaciones") {
    AffectedStationsCard(
        lineNumber: "1",
        incidents: [
            Incident(status: .intervention, affectedStations: ["Indios Verdes", "Potrero"], info: "Mantenimiento mayor"),
            Incident(status: .delayed, affectedStations: ["Tlatelolco"], info: "Alta afluencia")
        ]
    )
    .padding()
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}

#Preview("Dark Mode") {
    AffectedStationsCard(
        lineNumber: "1",
        incidents: [
            Incident(status: .suspended, affectedStations: ["Línea Completa"], info: nil)
        ]
    )
    .padding()
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
    .preferredColorScheme(.dark)
}
#endif
