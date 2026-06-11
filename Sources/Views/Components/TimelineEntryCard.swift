import SwiftUI

/// Rescued from AlertsView (spec 2 §5) ahead of that view's spec-3
/// deprecation. Compared against AlertCard during the redesign; absorbed
/// or retired when the Alertas tab dies.
struct TimelineEntryCard: View {
    let line: LineStatus
    let isActive: Bool
    let onTap: () -> Void

    private var statusColor: Color {
        StatusColors.color(for: line.status)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                // Time / Status indicator
                VStack(spacing: 4) {
                    if isActive {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(statusColor.opacity(0.3), lineWidth: 4)
                            )
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .frame(width: Layout.minTouchTarget)

                // Line badge — uses the canonical component
                LineBadge(number: line.lineNumber, transportType: line.transportType, size: .small)
                    .frame(width: 36, height: 36)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(line.lineName)
                            .font(.subheadline.weight(.medium))

                        Spacer()

                        // Status pill
                        Text(StatusColors.shortText(for: line.status))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(SurfaceOpacity.tintMedium), in: Capsule())
                    }

                    if !line.affectedStations.isEmpty {
                        Text(line.affectedStations.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let info = line.additionalInfo {
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Layout.cardInset)
            .padding(.vertical, Spacing.sm)
            .surface(
                isActive ? .elevated : .base,
                cornerRadius: Layout.cornerRadiusMedium,
                tint: isActive ? statusColor : nil
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium)
                    .strokeBorder(
                        isActive ? statusColor.opacity(0.3) : Color.secondary.opacity(0.15),
                        lineWidth: isActive ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lineName), \(line.status.accessibilityLabel)")
        .accessibilityHint("Toca para ver detalles")
    }
}
