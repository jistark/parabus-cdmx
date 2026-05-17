import SwiftUI

struct StatusBadge: View {
    let status: ServiceStatus
    var style: Style = .compact

    enum Style {
        case compact
        case expanded
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(style == .compact ? .footnote : .subheadline)
                .symbolEffect(.pulse, options: .repeating, isActive: shouldPulse)

            if style == .expanded {
                Text(status.rawValue)
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, style == .compact ? 10 : 14)
        .padding(.vertical, style == .compact ? 6 : 10)
        .frame(minHeight: 44) // Ensure 44pt touch target
        .background(backgroundColor.opacity(0.15), in: Capsule())
        .foregroundStyle(backgroundColor)
        .accessibilityLabel(status.rawValue)
        .contentTransition(.symbolEffect(.replace))
    }

    private var iconName: String {
        switch status {
        case .regular: "checkmark.circle.fill"
        case .intervention: "wrench.and.screwdriver.fill"
        case .limited: "arrow.left.arrow.right"
        case .delayed: "clock.fill"
        case .suspended: "xmark.circle.fill"
        case .protest: "megaphone.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private var backgroundColor: Color {
        StatusColors.color(for: status)
    }

    private var shouldPulse: Bool {
        status == .suspended || status == .delayed || status == .protest
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
