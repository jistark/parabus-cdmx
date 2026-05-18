import SwiftUI

/// Sheet `.medium` que aparece al tap del bloque MB de `StationSignage.large`.
/// Rejilla de 7 chips circulares (color Pantone + número). Tap = onSelect + dismiss.
struct LineChangeSheet: View {

    let currentLine: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let lines = ["1","2","3","4","5","6","7"]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("CAMBIAR DE LÍNEA")
                    .font(BrandTypography.lineLabel)
                    .foregroundStyle(.secondary)
                Text("Metrobús")
                    .font(BrandTypography.displayMedium)
            }
            .padding(.horizontal, Layout.screenMargin)
            .padding(.top, Spacing.lg)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: Spacing.md)],
                spacing: Spacing.md
            ) {
                ForEach(lines, id: \.self) { line in
                    lineChip(line)
                }
            }
            .padding(.horizontal, Layout.screenMargin)

            Spacer()
        }
    }

    private func lineChip(_ line: String) -> some View {
        Button {
            onSelect(line)
            dismiss()
        } label: {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(LineColors.color(for: line).gradient)
                        .frame(width: 64, height: 64)
                    Text(line)
                        .font(BrandTypography.numeralLarge)
                        .monospacedDigit()
                        .foregroundStyle(line == "4" ? .black : .white)
                }
                .overlay(
                    Circle()
                        .strokeBorder(
                            line == currentLine ? LineColors.color(for: line) : Color.clear,
                            lineWidth: 3
                        )
                        .frame(width: 72, height: 72)
                )
                Text("Línea \(line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Línea \(line)\(line == currentLine ? ", seleccionada" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
#Preview {
    LineChangeSheet(currentLine: "1") { newLine in
        print("Selected: \(newLine)")
    }
    .presentationDetents([.medium])
}
#endif
