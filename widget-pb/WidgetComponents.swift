import SwiftUI
import WidgetKit

// MARK: - Widget Line Badge
//
// The Metrobús "B" silhouette + line number, sized for widget surfaces.
// Adapts to the widget rendering mode:
//   .fullColor → branded Pantone fill + white number
//   .accented  → system-accented monochrome (lock screen, dynamic wallpapers)
//   .vibrant   → translucent system fill
//
// In accented/vibrant modes the system flattens custom colors, so we let
// SwiftUI handle the tinting and just provide the shape. `widgetAccentable()`
// on the badge ensures the system uses the line color as the accent in the
// accented rendering mode where supported.

struct WidgetLineBadge: View {
    let lineNumber: String
    var size: BadgeSize = .regular

    @Environment(\.widgetRenderingMode) private var renderingMode

    enum BadgeSize {
        case mini      // 20pt — inline rows
        case small     // 32pt — compact lists
        case regular   // 44pt — single-line displays
        case large     // 72pt — hero positions

        var dimension: CGFloat {
            switch self {
            case .mini: return 20
            case .small: return 32
            case .regular: return 44
            case .large: return 72
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .mini: return 10
            case .small: return 16
            case .regular: return 22
            case .large: return 36
            }
        }
    }

    var body: some View {
        ZStack {
            shapeLayer
            Text(lineNumber)
                .font(.custom("TipoMovinCDMX-Bold", size: size.fontSize))
                .foregroundStyle(numberColor)
                .monospacedDigit()
                // Number sits in the rectangular left block of the B —
                // shifting left compensates for the right-bulging lobes.
                .offset(x: -size.dimension * 0.12)
        }
        .frame(width: size.dimension, height: size.dimension)
        .widgetAccentable()
        .accessibilityLabel("Línea \(lineNumber)")
    }

    /// In accented/vibrant rendering the system controls the fill — the line
    /// number reads as primary text. Only in fullColor do we keep the white
    /// numeral on the colored shape (max contrast).
    private var numberColor: Color {
        renderingMode == .fullColor ? .white : .primary
    }

    @ViewBuilder
    private var shapeLayer: some View {
        if renderingMode == .fullColor {
            MetrobusLineShape()
                .fill(WidgetLineColor.color(for: lineNumber))
        } else {
            // Accented / vibrant: hand the system a flat shape it can tint
            // through the widget rendering pipeline.
            MetrobusLineShape()
                .fill(Color.primary)
        }
    }
}

// MARK: - Widget Status Pill
//
// Compact pill: status icon + short label. Mirrors the app's StatusBadge but
// without surface effects (widget surfaces are constrained).

struct WidgetStatusPill: View {
    let status: WidgetServiceStatus
    var size: PillSize = .regular

    @Environment(\.widgetRenderingMode) private var renderingMode

    enum PillSize {
        case mini, regular

        var iconFont: Font {
            switch self {
            case .mini: return .caption2.weight(.bold)
            case .regular: return .caption.weight(.bold)
            }
        }

        var textFont: Font {
            switch self {
            case .mini: return .caption2.weight(.semibold)
            case .regular: return .caption.weight(.semibold)
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .mini: return 2
            case .regular: return 4
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .mini: return 6
            case .regular: return 8
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(size.iconFont)
            Text(status.shortText)
                .font(size.textFont)
                .textCase(.uppercase)
        }
        .foregroundStyle(pillForeground)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(pillBackground, in: Capsule())
    }

    private var pillForeground: Color {
        renderingMode == .accented ? .primary : status.color
    }

    private var pillBackground: Color {
        renderingMode == .accented
            ? Color.primary.opacity(0.15)
            : status.color.opacity(0.18)
    }
}

// MARK: - Skeleton Badge (loading state)

struct WidgetBadgeSkeleton: View {
    var size: WidgetLineBadge.BadgeSize = .regular

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        MetrobusLineShape()
            .fill(skeletonFill)
            .frame(width: size.dimension, height: size.dimension)
            .accessibilityHidden(true)
    }

    private var skeletonFill: Color {
        renderingMode == .accented
            ? Color.primary.opacity(0.15)
            : Color.secondary.opacity(0.25)
    }
}

// MARK: - Hero Status (all-clear / single critical)

/// Big centered SF Symbol + label. Used for systemSmall when there's a single
/// dominant message, and for the all-clear case at any size.
struct WidgetHeroStatus: View {
    let icon: String
    let title: String
    let subtitle: String?
    let tint: Color

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(renderingMode == .accented ? .primary : tint)
                .widgetAccentable()

            Text(title)
                .font(.custom("TipoMovinCDMX-Bold", size: 15, relativeTo: .subheadline))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
