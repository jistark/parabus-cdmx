import SwiftUI

// MARK: - Design Tokens for Parabús
// iOS 26 Transit Status App
// Generated from DESIGN_SYSTEM.md

// MARK: - Spacing (8pt Grid)

/// Spacing values following the 8pt grid system
enum Spacing {
    /// 4pt - Tight spacing (icon-to-text in badges)
    static let xxs: CGFloat = 4

    /// 8pt - Compact spacing (between related elements)
    static let xs: CGFloat = 8

    /// 12pt - Default component spacing
    static let sm: CGFloat = 12

    /// 16pt - Section padding, card insets
    static let md: CGFloat = 16

    /// 20pt - Screen edge padding
    static let lg: CGFloat = 20

    /// 24pt - Section separation
    static let xl: CGFloat = 24

    /// 32pt - Major section breaks
    static let xxl: CGFloat = 32
}

// MARK: - Layout Constants

enum Layout {
    // MARK: - Touch Targets

    /// Minimum touch target per Apple HIG (44pt)
    static let minTouchTarget: CGFloat = 44

    // MARK: - Corner Radii

    /// Small elements: badges, pills (8pt)
    static let cornerRadiusSmall: CGFloat = 8

    /// Cards, tiles (14pt)
    static let cornerRadiusMedium: CGFloat = 14

    /// Sheets, large containers (20pt)
    static let cornerRadiusLarge: CGFloat = 20

    // MARK: - Component Sizes

    /// Line badge small (32pt) - lists, compact UI
    static let badgeSmall: CGFloat = 32

    /// Line badge regular (48pt) - cards, banners
    static let badgeRegular: CGFloat = 48

    /// Line badge large (56pt) - detail headers
    static let badgeLarge: CGFloat = 56

    // MARK: - Grid

    /// Grid columns for lines (iPhone compact)
    static let lineGridColumns = 4

    /// Grid columns for lines (iPad/regular width)
    static let lineGridColumnsWide = 7

    // MARK: - Card

    /// Minimum card height for line tiles
    static let cardMinHeight: CGFloat = 100

    /// Alert row minimum height
    static let alertRowMinHeight: CGFloat = 64
}

// MARK: - Status Colors

/// Semantic colors for service status indicators
enum StatusColors {
    /// Green - service operating normally
    /// Light: #34C759 | Dark: #30D158
    static let good = Color.green

    /// Orange - partial service / intervention / scheduled maintenance
    /// Light: #FF9500 | Dark: #FF9F0A
    static let warning = Color.orange

    /// Red - service suspended or major delays
    /// Light: #FF3B30 | Dark: #FF453A
    static let critical = Color.red

    /// Gray - unknown status or stale data
    static let unknown = Color.secondary

    /// Returns the appropriate color for a service status
    static func color(for status: ServiceStatus) -> Color {
        switch status {
        case .regular:
            return good
        case .intervention:
            return warning
        case .limited:
            return warning  // Limited service is a warning
        case .delayed:
            return critical
        case .suspended:
            return critical
        case .protest:
            return critical  // Protest is urgent/critical
        case .unknown:
            return unknown
        }
    }

    /// SF Symbol icon for a status
    static func icon(for status: ServiceStatus) -> String {
        switch status {
        case .regular:
            return "checkmark.circle.fill"
        case .intervention:
            return "wrench.and.screwdriver.fill"
        case .limited:
            return "arrow.left.arrow.right"
        case .delayed:
            return "clock.badge.exclamationmark"
        case .suspended:
            return "xmark.octagon.fill"
        case .protest:
            return "megaphone.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    /// Whether the status icon should pulse
    static func shouldPulse(for status: ServiceStatus) -> Bool {
        status == .suspended || status == .delayed || status == .protest
    }

    /// Short localized text for a status (widget/compact UI)
    static func shortText(for status: ServiceStatus) -> String {
        switch status {
        case .regular: return "OK"
        case .intervention: return "Obra"
        case .limited: return "Limitado"
        case .delayed: return "Retraso"
        case .suspended: return "Susp."
        case .protest: return "Protestas"
        case .unknown: return "?"
        }
    }

    /// Full localized text for a status
    static func displayText(for status: ServiceStatus) -> String {
        switch status {
        case .regular: return "Servicio normal"
        case .intervention: return "Intervencion activa"
        case .limited: return "Servicio limitado"
        case .delayed: return "Con retraso"
        case .suspended: return "Suspendido"
        case .protest: return "Manifestacion"
        case .unknown: return "Desconocido"
        }
    }
}

// MARK: - Line Brand Colors

/// Official Metrobus CDMX line colors
enum LineColors {
    /// Line 1 - Insurgentes (Red)
    static let line1 = Color(red: 0.83, green: 0.18, blue: 0.18)

    /// Line 2 - Eje 4 Sur (Purple)
    static let line2 = Color(red: 0.48, green: 0.18, blue: 0.56)

    /// Line 3 - Eje 1 Poniente (Green)
    static let line3 = Color(red: 0.13, green: 0.55, blue: 0.13)

    /// Line 4 - Buenavista-Aeropuerto (Gold)
    static let line4 = Color(red: 0.96, green: 0.65, blue: 0.14)

    /// Line 5 - Eje 3 Oriente (Blue)
    static let line5 = Color(red: 0.00, green: 0.48, blue: 0.65)

    /// Line 6 - Aragon-El Rosario (Magenta)
    static let line6 = Color(red: 0.80, green: 0.00, blue: 0.47)

    /// Line 7 - Indios Verdes-Campo Marte (Teal)
    static let line7 = Color(red: 0.00, green: 0.60, blue: 0.40)

    /// Fallback gray for unknown lines
    static let unknown = Color.gray

    /// Returns the brand color for a line number
    static func color(for lineNumber: String) -> Color {
        switch lineNumber {
        case "1": return line1
        case "2": return line2
        case "3": return line3
        case "4": return line4
        case "5": return line5
        case "6": return line6
        case "7": return line7
        default: return unknown
        }
    }
}

// MARK: - Surface & Material Opacities

/// Standard opacities for backgrounds and materials
enum SurfaceOpacity {
    /// Subtle tint for cards (6%)
    static let tintSubtle: Double = 0.06

    /// Light tint for status cards (10%)
    static let tintLight: Double = 0.10

    /// Medium tint for emphasis (15%)
    static let tintMedium: Double = 0.15

    /// Border opacity (20%)
    static let border: Double = 0.20

    /// Strong border for status indicators (40%)
    static let borderStrong: Double = 0.40
}

// MARK: - Animation Constants

enum AnimationDuration {
    /// Quick interactions (0.2s)
    static let fast: Double = 0.2

    /// Standard transitions (0.3s)
    static let normal: Double = 0.3

    /// Longer, more noticeable animations (0.4s)
    static let slow: Double = 0.4
}

// MARK: - Typography Presets

/// Pre-configured font styles following HIG
enum Typography {
    /// Card title, line name in detail view
    static let cardTitle = Font.title2.weight(.semibold)

    /// Section headers
    static let sectionHeader = Font.headline

    /// Line name in compact cards
    static let lineLabel = Font.caption.weight(.medium)

    /// Status text in badges
    static let statusLabel = Font.subheadline.weight(.medium)

    /// Timestamps, tertiary info
    static let timestamp = Font.caption2

    /// Badge numbers (large)
    static let badgeNumber = Font.title.weight(.bold)
}

// MARK: - Accessibility Extensions

extension ServiceStatus {
    /// Full accessibility label for VoiceOver
    var accessibilityLabel: String {
        switch self {
        case .regular:
            return "Servicio operando con normalidad"
        case .intervention:
            return "Intervencion activa en la linea"
        case .limited:
            return "Servicio limitado entre estaciones"
        case .delayed:
            return "Servicio con retrasos"
        case .suspended:
            return "Servicio suspendido"
        case .protest:
            return "Servicio afectado por manifestacion"
        case .unknown:
            return "Estado del servicio desconocido"
        }
    }
}

// MARK: - View Modifiers

/// Applies standard card styling with glass effect
struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let hasBorder: Bool
    let borderColor: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = Layout.cornerRadiusMedium,
        hasBorder: Bool = true,
        borderColor: Color = .secondary
    ) {
        self.cornerRadius = cornerRadius
        self.hasBorder = hasBorder
        self.borderColor = borderColor
    }

    func body(content: Content) -> some View {
        content
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(borderOverlay)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if reduceTransparency {
            Color(white: colorScheme == .dark ? 0.15 : 0.95)
        } else {
            Color.clear.background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if hasBorder {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor.opacity(SurfaceOpacity.border), lineWidth: 0.5)
        }
    }
}

extension View {
    /// Applies glass card styling appropriate for iOS 26
    func glassCard(
        cornerRadius: CGFloat = Layout.cornerRadiusMedium,
        hasBorder: Bool = true,
        borderColor: Color = .secondary
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            hasBorder: hasBorder,
            borderColor: borderColor
        ))
    }
}

/// Applies status-tinted glass background
struct StatusGlassModifier: ViewModifier {
    let status: ServiceStatus
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        StatusColors.color(for: status).opacity(
                            status.isNormal ? SurfaceOpacity.border : SurfaceOpacity.borderStrong
                        ),
                        lineWidth: status.isNormal ? 0.5 : 1.5
                    )
            )
    }

    @ViewBuilder
    private var backgroundView: some View {
        if reduceTransparency {
            Color(white: colorScheme == .dark ? 0.15 : 0.95)
        } else {
            StatusColors.color(for: status)
                .opacity(status.isNormal ? 0 : SurfaceOpacity.tintSubtle)
                .background(.ultraThinMaterial)
        }
    }
}

extension View {
    /// Applies status-colored glass background
    func statusGlass(for status: ServiceStatus, cornerRadius: CGFloat = Layout.cornerRadiusMedium) -> some View {
        modifier(StatusGlassModifier(status: status, cornerRadius: cornerRadius))
    }
}

// MARK: - Conditional Animation Modifier

struct ReduceMotionAnimation: ViewModifier {
    let animation: Animation
    let value: AnyHashable

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Applies animation only if Reduce Motion is OFF
    func animateIfAllowed<V: Hashable>(_ animation: Animation, value: V) -> some View {
        modifier(ReduceMotionAnimation(animation: animation, value: AnyHashable(value)))
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct DesignTokensPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Status Colors
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Status Colors")
                        .font(.headline)

                    HStack(spacing: Spacing.md) {
                        ForEach(ServiceStatus.allCases, id: \.self) { status in
                            VStack {
                                Circle()
                                    .fill(StatusColors.color(for: status))
                                    .frame(width: 40, height: 40)

                                Text(StatusColors.shortText(for: status))
                                    .font(.caption2)
                            }
                        }
                    }
                }

                // Line Colors
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Line Colors")
                        .font(.headline)

                    HStack(spacing: Spacing.xs) {
                        ForEach(1...7, id: \.self) { num in
                            ZStack {
                                Circle()
                                    .fill(LineColors.color(for: "\(num)").gradient)
                                    .frame(width: 40, height: 40)

                                Text("\(num)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                // Spacing
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Spacing Scale")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        spacingRow("xxs", Spacing.xxs)
                        spacingRow("xs", Spacing.xs)
                        spacingRow("sm", Spacing.sm)
                        spacingRow("md", Spacing.md)
                        spacingRow("lg", Spacing.lg)
                        spacingRow("xl", Spacing.xl)
                        spacingRow("xxl", Spacing.xxl)
                    }
                }

                // Badge Sizes
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Badge Sizes")
                        .font(.headline)

                    HStack(spacing: Spacing.md) {
                        badgeSizeDemo("small", Layout.badgeSmall)
                        badgeSizeDemo("regular", Layout.badgeRegular)
                        badgeSizeDemo("large", Layout.badgeLarge)
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .frame(width: 40, alignment: .leading)

            Rectangle()
                .fill(Color.accentColor)
                .frame(width: value, height: 16)

            Text("\(Int(value))pt")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func badgeSizeDemo(_ name: String, _ size: CGFloat) -> some View {
        VStack {
            ZStack {
                Circle()
                    .fill(LineColors.line1.gradient)
                    .frame(width: size, height: size)

                Text("1")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(name)
                .font(.caption2)
        }
    }
}

#Preview("Design Tokens") {
    DesignTokensPreview()
}

#Preview("Glass Cards") {
    VStack(spacing: Spacing.md) {
        Text("Normal Card")
            .padding()
            .frame(maxWidth: .infinity)
            .glassCard()

        Text("Status Card - Issue")
            .padding()
            .frame(maxWidth: .infinity)
            .statusGlass(for: .intervention)

        Text("Status Card - Suspended")
            .padding()
            .frame(maxWidth: .infinity)
            .statusGlass(for: .suspended)
    }
    .padding()
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}

#Preview("Glass Cards - Dark") {
    VStack(spacing: Spacing.md) {
        Text("Normal Card")
            .padding()
            .frame(maxWidth: .infinity)
            .glassCard()

        Text("Status Card - Issue")
            .padding()
            .frame(maxWidth: .infinity)
            .statusGlass(for: .intervention)
    }
    .padding()
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
    .preferredColorScheme(.dark)
}
#endif
