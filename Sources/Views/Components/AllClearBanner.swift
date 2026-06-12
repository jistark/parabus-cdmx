import SwiftUI

/// "All clear" banner for the home ("Todo bien") — rescued from the
/// retired AlertsView (spec 2 §5).
struct AllClearBanner: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}
