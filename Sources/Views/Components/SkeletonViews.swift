import SwiftUI

// MARK: - Shimmer Effect

/// A shimmer animation modifier for skeleton loading states
/// Respects Reduce Motion accessibility setting
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(shimmerOverlay(for: content))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }

    @ViewBuilder
    private func shimmerOverlay(for content: Content) -> some View {
        if !reduceMotion {
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * 2)
                .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
            }
            .mask(content)
        }
    }
}

extension View {
    /// Applies a shimmer loading effect
    /// Automatically disabled when Reduce Motion is enabled
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shape

/// A placeholder shape for skeleton loading states
struct SkeletonShape: View {
    enum Style {
        case circle
        case capsule
        case roundedRect(cornerRadius: CGFloat)
    }

    let style: Style

    @Environment(\.colorScheme) private var colorScheme

    private var fillColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    var body: some View {
        switch style {
        case .circle:
            Circle()
                .fill(fillColor)
        case .capsule:
            Capsule()
                .fill(fillColor)
        case .roundedRect(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fillColor)
        }
    }
}

// MARK: - Line Carousel Skeleton

/// Skeleton placeholder for the lines carousel during initial load
struct LinesCarouselSkeleton: View {
    private let lineCount = 7

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<lineCount, id: \.self) { _ in
                    LineCarouselCardSkeleton()
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollDisabled(true)
        .accessibilityLabel("Cargando lineas")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Skeleton for a single line card in the carousel
struct LineCarouselCardSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            // Badge placeholder
            SkeletonShape(style: .circle)
                .frame(width: 56, height: 56)
                .shimmer()

            // Status text placeholder
            SkeletonShape(style: .capsule)
                .frame(width: 48, height: 12)
                .shimmer()
        }
        .frame(width: 70)
    }
}

// MARK: - Incident Card Skeleton

/// Skeleton placeholder for incident alert banners
struct IncidentCardSkeleton: View {
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.04)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Line badge placeholder
            SkeletonShape(style: .circle)
                .frame(width: 48, height: 48)
                .shimmer()

            // Text content placeholders
            VStack(alignment: .leading, spacing: 6) {
                // Line name
                SkeletonShape(style: .capsule)
                    .frame(width: 100, height: 14)
                    .shimmer()

                // Incident summary
                SkeletonShape(style: .capsule)
                    .frame(width: 160, height: 12)
                    .shimmer()
            }

            Spacer()

            // Status badge placeholder
            SkeletonShape(style: .capsule)
                .frame(width: 72, height: 28)
                .shimmer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Full Content Skeleton

/// Complete skeleton view for initial load state
/// Shows carousel skeleton + incident placeholders
struct ContentSkeleton: View {
    /// Number of incident card placeholders to show
    let incidentCardCount: Int

    init(incidentCardCount: Int = 2) {
        self.incidentCardCount = incidentCardCount
    }

    var body: some View {
        VStack(spacing: 24) {
            // Lines section skeleton
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                HStack {
                    SkeletonShape(style: .capsule)
                        .frame(width: 60, height: 16)
                        .shimmer()

                    Spacer()

                    SkeletonShape(style: .capsule)
                        .frame(width: 100, height: 12)
                        .shimmer()
                }
                .padding(.horizontal, 20)

                // Carousel
                LinesCarouselSkeleton()
            }

            // Incidents section skeleton
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                HStack(spacing: 8) {
                    SkeletonShape(style: .circle)
                        .frame(width: 20, height: 20)
                        .shimmer()

                    SkeletonShape(style: .capsule)
                        .frame(width: 120, height: 16)
                        .shimmer()
                }
                .padding(.horizontal, 20)

                // Incident cards
                VStack(spacing: 8) {
                    ForEach(0..<incidentCardCount, id: \.self) { _ in
                        IncidentCardSkeleton()
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cargando estado del servicio")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Refreshing Header Indicator

/// Subtle inline loading indicator for the header during pull-to-refresh
struct RefreshingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            if reduceMotion {
                // Static indicator for reduce motion
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                // Animated spinner
                ProgressView()
                    .controlSize(.mini)
            }

            Text("Actualizando...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Actualizando estado del servicio")
    }
}

// MARK: - Previews

#Preview("Lines Carousel Skeleton") {
    VStack {
        LinesCarouselSkeleton()
    }
    .padding(.vertical)
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}

#Preview("Incident Card Skeleton") {
    VStack(spacing: 12) {
        IncidentCardSkeleton()
        IncidentCardSkeleton()
    }
    .padding()
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}

#Preview("Full Content Skeleton") {
    ScrollView {
        ContentSkeleton(incidentCardCount: 3)
    }
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}

#Preview("Full Content Skeleton - Dark") {
    ScrollView {
        ContentSkeleton(incidentCardCount: 2)
    }
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
    .preferredColorScheme(.dark)
}

#Preview("Refreshing Indicator") {
    VStack {
        RefreshingIndicator()
    }
    .padding()
}

#Preview("Large Text") {
    ScrollView {
        ContentSkeleton()
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
    #if os(iOS)
    .background(Color(.systemGroupedBackground))
    #endif
}
