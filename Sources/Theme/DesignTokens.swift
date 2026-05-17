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

    // MARK: - Semantic Spacing Aliases (A6)
    //
    // Use these for layout decisions; reach for Spacing.* only when you need a
    // raw value off the 8pt grid. The matrix below documents how surfaces and
    // padding pair up at every level of the visual hierarchy.
    //
    //  ┌─────────────────┬──────────────┬─────────────────┐
    //  │ Surface         │ Inset (pad)  │ Outer spacing   │
    //  ├─────────────────┼──────────────┼─────────────────┤
    //  │ Screen edges    │ —            │ screenMargin 20 │
    //  │ Between sections│ —            │ sectionSpacing 24│
    //  │ Inside a card   │ cardInset 16 │ —               │
    //  │ Between cards   │ —            │ inlineSpacing 12│
    //  │ Inside a pill   │ pillInset 10 │ —               │
    //  └─────────────────┴──────────────┴─────────────────┘

    /// Horizontal padding from screen edges to content (`Spacing.lg` = 20pt)
    static let screenMargin: CGFloat = Spacing.lg

    /// Vertical gap between top-level sections (`Spacing.xl` = 24pt)
    static let sectionSpacing: CGFloat = Spacing.xl

    /// Interior padding for a card or banner (`Spacing.md` = 16pt)
    static let cardInset: CGFloat = Spacing.md

    /// Vertical gap between cards or rows in a stack (`Spacing.sm` = 12pt)
    static let inlineSpacing: CGFloat = Spacing.sm

    /// Horizontal padding inside small pills, chips, capsules (`Spacing.xs` + 2pt)
    static let pillInset: CGFloat = 10
}

// MARK: - Status Colors

/// Semantic colors for service status indicators.
///
/// Hue progression encodes severity: green → yellow → orange → amber → red → pink.
/// Each step changes hue (not just intensity) so users with color-vision
/// deficiencies can still distinguish them; icons (`StatusColors.icon(for:)`)
/// reinforce the signal.
///
/// We use SwiftUI's semantic colors (`.green`, `.red`, …) instead of Pantone
/// brand colors because:
///   - System colors auto-adapt to dark mode, accessibility contrast settings,
///     and platform conventions
///   - Pantone palette is reserved for brand identity (line badges, corporate
///     header) — mixing the two would conflate "this is L4" with "this is a
///     warning"
/// One exception: `delay` is a custom amber tuned for WCAG AA contrast on
/// white backgrounds, which the system orange doesn't always meet.
enum StatusColors {
    /// Green - service operating normally
    /// Light: #34C759 | Dark: #30D158
    static let good = Color.green

    /// Yellow - real-time partial service (limited between stations).
    /// Distinct from `warning` because limited is *currently happening*, not
    /// scheduled — lower commitment than orange but still attention-worthy.
    static let attention = Color.yellow

    /// Orange - scheduled disruption (planned intervention / maintenance).
    /// Predictable, calmer urgency than `attention` or `delay`.
    /// Light: #FF9500 | Dark: #FF9F0A
    static let warning = Color.orange

    /// Amber - service degraded but flowing (delayed).
    /// Custom hex tuned for WCAG AA contrast against white; sits between
    /// `warning` and `critical` to signal "moving, but slowly".
    static let delay = Color(red: 0.85, green: 0.55, blue: 0.0)

    /// Red - service stopped (suspended).
    /// Light: #FF3B30 | Dark: #FF453A
    static let critical = Color.red

    /// Pink - external urgent event (manifestación / protest).
    /// Highest severity and visually distinct from `critical` so users
    /// instantly recognize "this is not a maintenance issue, it's an
    /// external disruption".
    static let urgent = Color.pink

    /// Gray - unknown status or stale data
    static let unknown = Color.secondary

    /// Returns the appropriate color for a service status
    static func color(for status: ServiceStatus) -> Color {
        switch status {
        case .regular:      return good
        case .intervention: return warning
        case .limited:      return attention
        case .delayed:      return delay
        case .suspended:    return critical
        case .protest:      return urgent
        case .unknown:      return unknown
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

// MARK: - Line Brand Colors (CDMX Movilidad Integrada — OFFICIAL Pantone)
//
// Source of truth: ref/manual-mi-mb.pdf section 3 (Metrobús > Pantone), values
// transcribed in ref/CDMX_PALETTE.md. Hex codes are sRGB from the manual; we
// render them in Display-P3 color space so they pop on modern iPhone displays
// while still hitting the same nominal values on legacy sRGB devices.
//
// These differ noticeably from the previous approximations:
//   L1 went from rojo brillante to borgoña, L3 from verde to olivo, L4 from
//   oro to naranja puro, L5 from cyan to navy, L7 from teal to verde profundo.

/// Official Metrobús CDMX line colors (Pantone-derived, Display-P3).
enum LineColors {
    /// Line 1 - Insurgentes — PANTONE 1807 C / #A4343A
    static let line1 = Color(.displayP3, red: 164/255, green: 52/255, blue: 58/255, opacity: 1)

    /// Line 2 - Eje 4 Sur — PANTONE 2602 C / #87189D
    static let line2 = Color(.displayP3, red: 135/255, green: 24/255, blue: 157/255, opacity: 1)

    /// Line 3 - Eje 1 Poniente — PANTONE 377 C / #7A9A01
    static let line3 = Color(.displayP3, red: 122/255, green: 154/255, blue: 1/255, opacity: 1)

    /// Line 4 - Buenavista-Aeropuerto — PANTONE Orange 021 C / #FE5000
    static let line4 = Color(.displayP3, red: 254/255, green: 80/255, blue: 0/255, opacity: 1)

    /// Line 5 - Eje 3 Oriente — PANTONE 2757 C / #001E60
    static let line5 = Color(.displayP3, red: 0/255, green: 30/255, blue: 96/255, opacity: 1)

    /// Line 6 - Aragón-El Rosario — PANTONE Rhodamine Red C / #E10098
    static let line6 = Color(.displayP3, red: 225/255, green: 0/255, blue: 152/255, opacity: 1)

    /// Line 7 - Indios Verdes-Campo Marte — PANTONE 349 C / #046A38
    static let line7 = Color(.displayP3, red: 4/255, green: 106/255, blue: 56/255, opacity: 1)

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

// MARK: - Brand Corporate Colors (Metrobús + Movilidad Integrada)

/// Metrobús corporate identity and CDMX Movilidad Integrada neutrals.
/// Source: ref/manual-mi-mb.pdf (Pantone Coated → sRGB transcription).
enum BrandColors {
    /// Metrobús corporate red — PANTONE 186 C / #C8102E
    /// Use for branded headers, primary actions, hero accents.
    static let metrobusRed = Color(.displayP3, red: 200/255, green: 16/255, blue: 46/255, opacity: 1)

    /// PANTONE Cool Gray 5 C / #B1B3B3 — soft neutral for backgrounds.
    static let neutralLight = Color(.displayP3, red: 177/255, green: 179/255, blue: 179/255, opacity: 1)

    /// PANTONE Cool Gray 10 C / #63666A — complementary text/icons in maps
    /// (per manual line 240).
    static let neutralMedium = Color(.displayP3, red: 99/255, green: 102/255, blue: 106/255, opacity: 1)

    /// PANTONE Cool Gray 11 C / #53565A — emphasized text on light surfaces.
    static let neutralDark = Color(.displayP3, red: 83/255, green: 86/255, blue: 90/255, opacity: 1)

    /// Process Black / #231F20 — body text, primary content.
    static let neutralAbsolute = Color(.displayP3, red: 35/255, green: 31/255, blue: 32/255, opacity: 1)
}

// MARK: - Transport Modal Colors (CDMX Movilidad Integrada — multimodal)

/// Placeholders for future intermodal transfer UI (Metro icons, Trolebús,
/// Cablebús, RTP, etc.). The manual section pages for these modes embed colors
/// as images that `pdftotext` couldn't extract — values will be filled in when
/// the actual UI need arises. Until then these resolve to neutral so missing
/// data doesn't masquerade as a real branded color.
enum TransportModalColors {
    /// STC Metro (CDMX heavy rail) — TODO: extract from manual section 2.
    static let metro = BrandColors.neutralMedium

    /// Cablebús (aerial cable transit) — TODO: extract from manual section 4.
    static let cablebus = BrandColors.neutralMedium

    /// Trolebús (Servicio de Transportes Eléctricos) — TODO: section 5.
    static let trolebus = BrandColors.neutralMedium

    /// RTP (Red de Transporte de Pasajeros) — TODO: section 7.
    static let rtp = BrandColors.neutralMedium

    /// Tren Ligero (light rail) — TODO: section 5 (STE).
    static let trenLigero = BrandColors.neutralMedium

    /// Suburbano/Tren Interurbano — TODO: section 10.
    static let suburbano = BrandColors.neutralMedium

    /// Ecobici (bike share) — TODO: section 6.
    static let ecobici = BrandColors.neutralMedium
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

// MARK: - Liquid Glass Primitives (A5)
//
// Single source of truth for translucent surfaces. iOS 26 uses real
// `.glassEffect(...)` with refraction; iOS 18-25 fall back to `.ultraThinMaterial`
// equivalents. Both honor `accessibilityReduceTransparency` by collapsing to a
// solid neutral fill.
//
// The legacy `glassCard()` and `statusGlass()` extensions now delegate to
// `.surface(_:)`, so existing call sites continue to work unchanged.

/// Visual hierarchy of a glass surface. Higher levels stand out more from the
/// background and grab more attention.
enum SurfaceLevel {
    /// Subtle inline tile — line cards, list rows, info blocks.
    case base

    /// Prominent banner — active incident alerts, status callouts.
    case elevated

    /// Pulled-out element — sheets, toolbars, content over a map.
    case floating

    /// Tint applied on iOS 26 to give each level distinct depth.
    var iOS26Tint: Color {
        switch self {
        case .base: return .clear
        case .elevated: return Color.primary.opacity(0.04)
        case .floating: return Color.primary.opacity(0.08)
        }
    }

    /// Fallback material used on iOS 18-25.
    @available(iOS 15.0, *)
    var legacyMaterial: Material {
        switch self {
        case .base: return .ultraThinMaterial
        case .elevated: return .thinMaterial
        case .floating: return .regularMaterial
        }
    }
}

/// Applies a Liquid-Glass-aware surface to any view. Use through `.surface(_:)`.
struct SurfaceModifier: ViewModifier {
    let level: SurfaceLevel
    let cornerRadius: CGFloat
    let tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    init(level: SurfaceLevel, cornerRadius: CGFloat, tint: Color? = nil) {
        self.level = level
        self.cornerRadius = cornerRadius
        self.tint = tint
    }

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(solidFallback)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content
                .background(glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(legacyBackground)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var solidFallback: some View {
        let base = Color(white: colorScheme == .dark ? 0.15 : 0.95)
        return ZStack {
            base
            if let tint {
                tint.opacity(SurfaceOpacity.tintSubtle)
            } else {
                level.iOS26Tint
            }
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    @ViewBuilder
    private var glassBackground: some View {
        let resolvedTint = tint ?? level.iOS26Tint
        Color.clear
            .glassEffect(.regular.tint(resolvedTint), in: .rect(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var legacyBackground: some View {
        let resolvedTint = tint ?? level.iOS26Tint
        ZStack {
            Rectangle().fill(level.legacyMaterial)
            if resolvedTint != .clear {
                resolvedTint.opacity(SurfaceOpacity.tintLight)
            }
        }
    }
}

extension View {
    /// Apply a Liquid Glass surface. Use this for any translucent card, banner,
    /// or floating element across the app — it's the single switchpoint between
    /// iOS 26 `.glassEffect` and the iOS 18-25 material fallback.
    ///
    /// - Parameters:
    ///   - level: Visual hierarchy. `.base` = subtle, `.elevated` = banner,
    ///            `.floating` = sheets/toolbars.
    ///   - cornerRadius: Corner rounding. Defaults to `Layout.cornerRadiusMedium`.
    ///   - tint: Optional brand tint (e.g. status color). When nil, uses the
    ///           level's neutral tint.
    func surface(
        _ level: SurfaceLevel = .base,
        cornerRadius: CGFloat = Layout.cornerRadiusMedium,
        tint: Color? = nil
    ) -> some View {
        modifier(SurfaceModifier(level: level, cornerRadius: cornerRadius, tint: tint))
    }
}

// MARK: - Liquid Glass Container

/// On iOS 26, groups multiple `.surface(_:)` siblings so their glass effects
/// morph together (e.g. when one transitions in/out, the surrounding glass
/// flows around it). On older OS versions it's a transparent passthrough.
///
/// Wrap a group of related glass cards (e.g. the alerts list) to get unified
/// refraction behavior.
struct LiquidGlassContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer { content }
        } else {
            content
        }
    }
}

// MARK: - View Modifiers (Legacy Facades)
//
// `glassCard()` and `statusGlass()` are kept as façades so existing call sites
// don't need to change. New code should reach for `.surface(_:)` directly.

/// Applies standard card styling with glass effect.
///
/// Façade over `.surface(.base)`. Kept for backward compatibility — new code
/// should prefer `.surface(_:)` directly for clarity.
struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let hasBorder: Bool
    let borderColor: Color

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
            .surface(.base, cornerRadius: cornerRadius)
            .overlay(borderOverlay)
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
    /// Applies glass card styling. Façade over `.surface(.base)`.
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

/// Applies status-tinted glass background. Façade over `.surface(_:tint:)`.
struct StatusGlassModifier: ViewModifier {
    let status: ServiceStatus
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let tint: Color? = status.isNormal ? nil : StatusColors.color(for: status)
        let level: SurfaceLevel = status.isNormal ? .base : .elevated
        let borderColor = StatusColors.color(for: status).opacity(
            status.isNormal ? SurfaceOpacity.border : SurfaceOpacity.borderStrong
        )

        return content
            .surface(level, cornerRadius: cornerRadius, tint: tint)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: status.isNormal ? 0.5 : 1.5)
            )
    }
}

extension View {
    /// Applies status-colored glass background. Façade over `.surface(_:tint:)`.
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
