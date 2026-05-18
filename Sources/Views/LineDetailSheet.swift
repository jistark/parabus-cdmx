import SwiftUI

/// Detail sheet for a single line. Three blocks readable at the `.medium`
/// detent without scrolling: WHO (line identity), WHY (reason per incident),
/// and WHERE (affected stations as a card with count + names).
///
/// `.large` is a drag-up affordance for very long incident texts or many
/// affected stations — the default `.medium` keeps the parent visible so
/// users can quickly compare against the list they came from.
struct LineDetailSheet: View {
    let line: LineStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Dynamic Type support - unified badge size
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = Layout.badgeRegular

    private var statusColor: Color { StatusColors.color(for: line.status) }

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                compactHeader
                    .padding(.top, Spacing.sm)

                if !line.incidents.isEmpty {
                    if hasAnyReason {
                        reasonsSection
                    }
                    AffectedStationsCard(
                        lineNumber: line.lineNumber,
                        incidents: line.incidents
                    )
                } else {
                    allClearMessage
                        .padding(.top, Spacing.lg)
                }

                Spacer(minLength: Spacing.xl)
            }
            .padding(.horizontal, Layout.cardInset)
        }
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #endif
    }

    // MARK: - Hero Header

    private var compactHeader: some View {
        HStack(spacing: Layout.cardInset) {
            LineBadge(number: line.lineNumber, transportType: line.transportType, size: .large)
                .frame(width: badgeSize, height: badgeSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(line.lineName)
                    .brandTitle(BrandTypography.displayMedium)
                statusPill
            }

            Spacer()
        }
        .padding(Layout.cardInset)
        .surface(
            line.status.isNormal ? .base : .elevated,
            cornerRadius: Layout.cornerRadiusLarge - 4,
            tint: line.status.isNormal ? nil : statusColor
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lineName), \(line.status.accessibilityLabel)")
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: StatusColors.icon(for: line.status))
                .font(.caption.weight(.semibold))
                .symbolEffect(.pulse, options: .repeating, isActive: shouldPulse && !reduceMotion)

            Text(StatusColors.displayText(for: line.status))
                .brandTitle(BrandTypography.statusLabel)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs - 2)
        .background(statusColor.opacity(SurfaceOpacity.tintLight), in: Capsule())
    }

    // MARK: - Reasons section
    //
    // One row per incident with its (status icon + reason text). When several
    // incidents share the same reason or none of them have one, we collapse
    // to a single explanatory pill so the section never reads as filler.

    private var hasAnyReason: Bool {
        line.incidents.contains { ($0.info?.isEmpty == false) }
    }

    private var reasonsSection: some View {
        VStack(alignment: .leading, spacing: Layout.inlineSpacing) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(StatusColors.warning)
                Text(line.incidents.count == 1 ? "Razón" : "Razones")
                    .brandTitle(BrandTypography.lineLabel)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: Spacing.xs) {
                ForEach(reasonsToShow.indices, id: \.self) { idx in
                    reasonRow(reasonsToShow[idx])
                }
            }
        }
    }

    /// Drops incidents with no info — they'd render as bare status pills and
    /// add noise. Incidents without a reason are already represented by the
    /// header's status pill and the affected-stations card.
    private var reasonsToShow: [Incident] {
        line.incidents
            .filter { ($0.info?.isEmpty == false) }
            .sorted { $0.status > $1.status }
    }

    private func reasonRow(_ incident: Incident) -> some View {
        let color = StatusColors.color(for: incident.status)
        return HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: StatusColors.icon(for: incident.status))
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(incident.info ?? StatusColors.displayText(for: incident.status))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.sm)
        .surface(.base, cornerRadius: Layout.cornerRadiusSmall)
    }

    // MARK: - All clear

    private var allClearMessage: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(StatusColors.good)
            Text("Sin incidentes reportados")
                .brandTitle(BrandTypography.lineLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    // MARK: - Helpers

    private var shouldPulse: Bool {
        line.status == .suspended || line.status == .delayed || line.status == .protest
    }
}

// MARK: - Previews

#Preview("Toda la línea — suspendida") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "1",
        transportType: .metrobus,
        status: .suspended,
        affectedStations: ["Línea Completa"],
        additionalInfo: "Retraso en el servicio por evento deportivo"
    ))
}

#Preview("Segmento afectado") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "4",
        transportType: .metrobus,
        status: .suspended,
        affectedStations: ["Plaza de la República - Vocacional 5"],
        additionalInfo: "Por reencarpetamiento en Ponciano Arriaga desvío"
    ))
}

#Preview("Múltiples incidentes") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "1",
        transportType: .metrobus,
        incidents: [
            Incident(status: .suspended, affectedStations: ["Indios Verdes", "Potrero"], info: "Cierre temporal por obras"),
            Incident(status: .delayed, affectedStations: ["Buenavista L1"], info: "Alta afluencia de usuarios"),
            Incident(status: .intervention, affectedStations: ["La Raza L1"], info: "Mantenimiento mayor")
        ]
    ))
}

#Preview("Sin incidentes") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "1",
        transportType: .metrobus,
        status: .regular,
        affectedStations: []
    ))
}

#Preview("Dark Mode") {
    LineDetailSheet(line: LineStatus(
        lineNumber: "4",
        transportType: .metrobus,
        status: .protest,
        affectedStations: ["Plaza de la República - Vocacional 5"],
        additionalInfo: "Marcha rumbo al Zócalo, desvíos activos"
    ))
    .preferredColorScheme(.dark)
}
