import SwiftUI

struct LineBadge: View {
    let number: String
    let transportType: TransportType
    var size: Size = .regular

    @Environment(\.colorScheme) private var colorScheme

    enum Size {
        case small, regular, large

        var dimension: CGFloat {
            switch self {
            case .small: 32
            case .regular: 40
            case .large: 56
            }
        }

        /// Minimum touch target (44pt)
        var touchTarget: CGFloat {
            max(dimension, 44)
        }
    }

    var body: some View {
        Group {
            if let image = TransitImageLoader.loadOfficialImage(
                for: number,
                transportType: transportType
            ) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.dimension, height: size.dimension)
            } else {
                fallbackBadge
            }
        }
        .frame(minWidth: size.touchTarget, minHeight: size.touchTarget)
        .accessibilityLabel("\(transportType.displayName) linea \(number)")
    }

    /// Fallback badge for lines without official icons
    private var fallbackBadge: some View {
        ZStack {
            Circle()
                .fill(lineColor.gradient)

            Text(number)
                .font(fallbackFont)
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
        }
        .frame(width: size.dimension, height: size.dimension)
        .shadow(color: lineColor.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 4, y: 2)
    }

    /// Brand-typography numeral — Tipo Movin CDMX Bold, scaled per badge size.
    /// Uses `.monospacedDigit()` so multi-character labels ("A", "10") don't
    /// jitter against single-character ones in adjacent badges.
    private var fallbackFont: Font {
        switch size {
        case .small: BrandTypography.numeralSmall
        case .regular: BrandTypography.numeralRegular
        case .large: BrandTypography.numeralLarge
        }
    }

    private var lineColor: Color {
        LineColors.color(for: number)
    }
}

#Preview("Official Icons - All Sizes") {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            ForEach(1...7, id: \.self) { num in
                LineBadge(number: "\(num)", transportType: .metrobus, size: .small)
            }
        }

        HStack(spacing: 16) {
            ForEach(1...7, id: \.self) { num in
                LineBadge(number: "\(num)", transportType: .metrobus, size: .regular)
            }
        }

        HStack(spacing: 16) {
            ForEach(1...7, id: \.self) { num in
                LineBadge(number: "\(num)", transportType: .metrobus, size: .large)
            }
        }
    }
    .padding()
}

#Preview("Fallback Badge") {
    HStack(spacing: 16) {
        LineBadge(number: "A", transportType: .metro, size: .regular)
        LineBadge(number: "8", transportType: .metrobus, size: .regular)
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            ForEach(1...7, id: \.self) { num in
                LineBadge(number: "\(num)", transportType: .metrobus, size: .regular)
            }
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
