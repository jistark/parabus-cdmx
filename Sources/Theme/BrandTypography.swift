import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreText

// MARK: - Brand Typography (Tipo Movin CDMX)
//
// Tipo Movin CDMX is the official typeface of CDMX Mobility System (Movilidad
// Integrada). In Parabús it provides brand accent in display headers, line
// names, and tabular numerals. SF Pro remains the default for body, lists, and
// system chrome — see `Typography` in DesignTokens.swift for those presets.
//
// Source manual: ref/manual-mi-mb.pdf
// OTF files:     Sources/Resources/Fonts/
// PostScript:    TipoMovinCDMX-{Light,Regular,Bold} + matching -Italic suffixes.
//
// ★ Dynamic Type: every preset wraps UIFont(name:size:) in UIFontMetrics so the
// custom font respects the user's accessibility text size. Never use
// `.font(.custom("TipoMovinCDMX-Bold", size: …))` directly — that bypasses
// Dynamic Type and breaks accessibility.

// MARK: - Brand Title Modifier
//
// Per the MB Movilidad Integrada manual, Tipo Movin CDMX is always set in
// uppercase — even when the source string is in mixed case. `brandTitle(_:)`
// combines the font + `.textCase(.uppercase)` so call sites stay readable
// ("Líneas" in code → "LÍNEAS" on screen) and we never forget the case rule.
//
// Safe to use on digits/symbols: `.textCase(.uppercase)` is a no-op there.

extension View {
    /// Brand typography with the obligatory all-caps rendering.
    /// Use this instead of `.font(BrandTypography.X)` for every Tipo Movin text.
    func brandTitle(_ font: Font) -> some View {
        self.font(font).textCase(.uppercase)
    }
}

/// PostScript names of the registered Tipo Movin CDMX faces.
enum BrandFont {
    static let light = "TipoMovinCDMX-Light"
    static let regular = "TipoMovinCDMX-Regular"
    static let bold = "TipoMovinCDMX-Bold"
    static let italic = "TipoMovinCDMX-Italic"
    static let boldItalic = "TipoMovinCDMX-BoldItalic"
    static let lightItalic = "TipoMovinCDMX-LightItalic"
}

/// Tipo Movin CDMX presets — display, numerals, and line names with Dynamic Type support.
enum BrandTypography {

    // MARK: - Display (titles, hero headers)

    /// Large display title — screen header ("Parabús", "Mis rutas")
    /// Scales relative to `.largeTitle`.
    static let displayLarge = scaled(BrandFont.bold, size: 34, relativeTo: .largeTitle)

    /// Medium display — sheet headers (line name in LineDetailSheet)
    /// Scales relative to `.title`.
    static let displayMedium = scaled(BrandFont.bold, size: 28, relativeTo: .title)

    /// Small display — secondary headers, empty state titles
    /// Scales relative to `.title2`.
    static let displaySmall = scaled(BrandFont.regular, size: 22, relativeTo: .title2)

    // MARK: - Line identity

    /// Line label — "Línea 1", "Indios Verdes" in cards and sheets
    /// Scales relative to `.headline`.
    static let lineLabel = scaled(BrandFont.bold, size: 17, relativeTo: .headline)

    /// Status label — short text in StatusBadge
    /// Scales relative to `.subheadline`.
    static let statusLabel = scaled(BrandFont.regular, size: 15, relativeTo: .subheadline)

    // MARK: - Numerals (tabular)

    /// Large numerals — line number in badge .large size (56pt badge)
    /// Use with `.monospacedDigit()` modifier in HStack to prevent jitter.
    static let numeralLarge = scaled(BrandFont.bold, size: 28, relativeTo: .title)

    /// Regular numerals — line number in badge .regular size (40pt badge)
    static let numeralRegular = scaled(BrandFont.bold, size: 17, relativeTo: .headline)

    /// Small numerals — line number in badge .small size (32pt badge)
    static let numeralSmall = scaled(BrandFont.bold, size: 13, relativeTo: .footnote)

    // MARK: - Internal

    /// Build a SwiftUI Font from a custom PostScript name with UIFontMetrics scaling.
    ///
    /// If the font fails to load (e.g. before registration), falls back to system
    /// font at the same size + scaling — avoids crashes during early app launch
    /// or in previews that bypass `BrandFontRegistration.registerAll()`.
    static func scaled(_ postScriptName: String, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        BrandFontRegistration.registerOnce()

        #if canImport(UIKit)
        let uiStyle = textStyle.uiTextStyle
        let base = UIFont(name: postScriptName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: postScriptName.contains("Bold") ? .bold : .regular)
        let scaled = UIFontMetrics(forTextStyle: uiStyle).scaledFont(for: base)
        return Font(scaled)
        #else
        return .custom(postScriptName, size: size, relativeTo: textStyle)
        #endif
    }
}

// MARK: - Font Registration

/// Bridges the OTF files into the runtime font catalog.
///
/// Two build paths reach this code:
/// - **xcodeproj** (the real app + widget targets) — fonts are bundled via
///   Sources/Resources/Fonts and widget-pb/Fonts, registered automatically by
///   iOS through `UIAppFonts` in each target's Info.plist. `registerOnce()` is
///   a no-op here because the system has already done the work.
/// - **swift build** (CLI tests, previews) — there's no main bundle and no
///   Info.plist, so we register programmatically from `Bundle.module`. Guarded
///   by `#if SWIFT_PACKAGE` because Bundle.module only exists in SwiftPM
///   compilation units.
enum BrandFontRegistration {
    static func registerOnce() {
        #if SWIFT_PACKAGE
        _ = registrationToken
        #endif
    }

    #if SWIFT_PACKAGE
    private static let registrationToken: Bool = {
        let fileNames = [
            "Tipo Movin CDMX Light",
            "Tipo Movin CDMX Regular",
            "Tipo Movin CDMX Bold",
            "Tipo Movin CDMX Italic",
            "Tipo Movin CDMX Bold Italic",
            "Tipo Movin CDMX Light Italic"
        ]

        for name in fileNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "otf", subdirectory: "Fonts") else {
                #if DEBUG
                Log.theme.error("Missing OTF: \(name, privacy: .public).otf")
                #endif
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                #if DEBUG
                if let err = error?.takeRetainedValue() {
                    let nsError = err as Error as NSError
                    // 304/305 = already registered (idempotent) → ignore
                    if nsError.code != 305 && nsError.code != 304 {
                        Log.theme.error("Failed registering \(name, privacy: .public): \(nsError.localizedDescription, privacy: .public)")
                    }
                }
                #endif
            }
        }
        return true
    }()
    #endif
}

#if canImport(UIKit)
private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        case .extraLargeTitle, .extraLargeTitle2: return .largeTitle
        @unknown default: return .body
        }
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct BrandTypographyPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Group {
                    Text("Display Large").font(BrandTypography.displayLarge)
                    Text("Display Medium").font(BrandTypography.displayMedium)
                    Text("Display Small").font(BrandTypography.displaySmall)
                }
                Divider()
                Group {
                    Text("Línea 1 — Insurgentes").font(BrandTypography.lineLabel)
                    Text("Servicio Regular").font(BrandTypography.statusLabel)
                }
                Divider()
                Group {
                    HStack {
                        Text("1").font(BrandTypography.numeralLarge).monospacedDigit()
                        Text("2").font(BrandTypography.numeralRegular).monospacedDigit()
                        Text("3").font(BrandTypography.numeralSmall).monospacedDigit()
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }
}

#Preview("Brand Typography") {
    BrandTypographyPreview()
}

#Preview("Brand Typography — Large Text") {
    BrandTypographyPreview()
        .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}
#endif
