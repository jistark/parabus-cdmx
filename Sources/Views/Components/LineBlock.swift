import SwiftUI

/// Solid Pantone block with the line numeral — the cenefa identity anchor,
/// shared by the map's mini-cenefa and the home "Ahora" card so station
/// identity reads the same everywhere. L4 keeps black text per the MB
/// signage manual.
struct LineBlock: View {
    let lineNumber: String
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LineColors.color(for: lineNumber))
            Text(lineNumber)
                .font(BrandTypography.numeralRegular)
                .monospacedDigit()
                .foregroundStyle(lineNumber == "4" ? Color.black : Color.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(String(localized: "Línea \(lineNumber)"))
    }
}

#if DEBUG
#Preview("Line blocks") {
    HStack {
        ForEach(["1", "2", "3", "4", "5", "6", "7"], id: \.self) {
            LineBlock(lineNumber: $0)
        }
    }
    .padding()
}
#endif
