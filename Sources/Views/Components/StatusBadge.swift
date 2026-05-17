import SwiftUI

struct StatusBadge: View {
    let status: ServiceStatus
    var style: Style = .compact

    enum Style {
        case compact
        case expanded
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: StatusColors.icon(for: status))
                .font(style == .compact ? .footnote : .subheadline)
                .symbolEffect(.pulse, options: .repeating, isActive: StatusColors.shouldPulse(for: status))

            if style == .expanded {
                Text(StatusColors.displayText(for: status))
                    .font(BrandTypography.statusLabel)
            }
        }
        .padding(.horizontal, style == .compact ? Layout.pillInset : Spacing.sm + 2)
        .padding(.vertical, style == .compact ? Spacing.xxs + 2 : Spacing.xs + 2)
        .frame(minHeight: Layout.minTouchTarget)
        .background(backgroundColor.opacity(SurfaceOpacity.tintMedium), in: Capsule())
        .foregroundStyle(backgroundColor)
        .accessibilityLabel(status.accessibilityLabel)
        .contentTransition(.symbolEffect(.replace))
    }

    private var backgroundColor: Color {
        StatusColors.color(for: status)
    }
}

#Preview("All States") {
    VStack(spacing: 16) {
        ForEach(ServiceStatus.allCases, id: \.self) { status in
            HStack {
                StatusBadge(status: status, style: .compact)
                StatusBadge(status: status, style: .expanded)
            }
        }
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 16) {
        ForEach(ServiceStatus.allCases, id: \.self) { status in
            StatusBadge(status: status, style: .expanded)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
