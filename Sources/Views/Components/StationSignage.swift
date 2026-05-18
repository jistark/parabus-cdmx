import SwiftUI

/// Replica visual de la cenefa oficial de señalización del Metrobús CDMX.
/// Cinco bloques en horizontal: MI (decorativo) · MB (interactivo) ·
/// banda central con nombre · número de línea · pictograma.
///
/// Tres tamaños:
///  - `.large` (~72pt): cenefa completa, usada en carrusel del mapa.
///  - `.compact` (~44pt): sin bloque MI, para rows inline (futuros consumidores).
///  - `.tile` (~56pt): cenefa completa pero padding tight (futuros list rows).
struct StationSignage: View {
    enum Size {
        case large, compact, tile

        var height: CGFloat {
            switch self {
            case .large: return 72
            case .compact: return 44
            case .tile: return 56
            }
        }

        var showsMIBlock: Bool {
            switch self {
            case .large, .tile: return true
            case .compact: return false
            }
        }

        var nameFont: Font {
            switch self {
            case .large: return BrandTypography.displayMedium
            case .compact, .tile: return BrandTypography.lineLabel
            }
        }

        var numeralFont: Font {
            switch self {
            case .large: return BrandTypography.numeralLarge
            case .tile: return BrandTypography.numeralRegular
            case .compact: return BrandTypography.numeralSmall
            }
        }
    }

    let stationName: String
    let lineNumber: String
    var subtitle: String? = nil
    var pictogramAssetName: String? = nil
    var size: Size = .large
    var onMBTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            if size.showsMIBlock {
                miBlock
            }
            mbBlock
            nameBlock
            numeralBlock
            if pictogramAssetName != nil {
                pictogramBlock
            }
        }
        .frame(height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.black.opacity(0.85), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Blocks

    private var miBlock: some View {
        ZStack {
            Color(red: 0.85, green: 0.85, blue: 0.85) // grey ~ cool gray 3
            // Diagonal pattern — simplified placeholder. Real manual uses
            // a tessellated diamond pattern; SwiftUI Canvas overlay is
            // a follow-up if we want pixel-perfect match.
            Text("MI")
                .font(BrandTypography.lineLabel)
                .foregroundStyle(.white)
        }
        .frame(width: size.height) // square
    }

    private var mbBlock: some View {
        ZStack {
            // Pantone "MB rojo" — using Línea 1 borgoña tone from CDMX palette
            // since the manual cover uses the same hue. If we want a
            // separate brand-red token, add it to BrandColors later.
            Color(red: 0.84, green: 0.20, blue: 0.23) // ~ Pantone 1807 C
            Text("MB")
                .font(BrandTypography.lineLabel)
                .foregroundStyle(.white)
        }
        .frame(width: size.height)
        .accessibilityAddTraits(onMBTap != nil ? .isButton : [])
        .accessibilityHint(onMBTap != nil ? "Cambiar de línea" : "")
        .contentShape(Rectangle())
        .onTapGesture {
            onMBTap?()
        }
    }

    private var nameBlock: some View {
        ZStack {
            LineColors.color(for: lineNumber)
            VStack(spacing: 0) {
                Text(stationName.uppercased())
                    .font(size.nameFont)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let subtitle, size == .large {
                    Text(subtitle.uppercased())
                        .font(BrandTypography.lineLabel)
                        .foregroundStyle(textColor.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private var numeralBlock: some View {
        ZStack {
            LineColors.color(for: lineNumber)
            Text(lineNumber)
                .font(size.numeralFont)
                .monospacedDigit()
                .foregroundStyle(textColor)
        }
        .frame(width: size.height * 0.7)
    }

    private var pictogramBlock: some View {
        ZStack {
            Color.black
            if let pictogramAssetName {
                Image(pictogramAssetName, bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
        .frame(width: size.height)
    }

    // MARK: - Helpers

    /// L4 (naranja Pantone 021 C #FE5000) keeps black text per manual.
    /// All other lines use white.
    private var textColor: Color {
        lineNumber == "4" ? .black : .white
    }

    private var accessibilityLabel: String {
        var label = "Estación \(stationName), línea \(lineNumber)"
        if let subtitle {
            label += ", \(subtitle)"
        }
        return label
    }
}

#if DEBUG
#Preview("Large — L1") {
    StationSignage(
        stationName: "Indios Verdes",
        lineNumber: "1",
        pictogramAssetName: nil,
        size: .large
    )
    .padding()
}

#Preview("Large — L4 (black text)") {
    StationSignage(
        stationName: "Pantitlán",
        lineNumber: "4",
        pictogramAssetName: nil,
        size: .large
    )
    .padding()
}

#Preview("Large — with subtitle") {
    StationSignage(
        stationName: "Etiopía",
        lineNumber: "3",
        subtitle: "Plaza de la Transparencia",
        pictogramAssetName: nil,
        size: .large
    )
    .padding()
}

#Preview("All sizes") {
    VStack(spacing: 16) {
        StationSignage(stationName: "Insurgentes", lineNumber: "1", size: .large)
        StationSignage(stationName: "Insurgentes", lineNumber: "1", size: .tile)
        StationSignage(stationName: "Insurgentes", lineNumber: "1", size: .compact)
    }
    .padding()
}
#endif
