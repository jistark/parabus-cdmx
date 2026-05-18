import SwiftUI

// MARK: - Metrobús Line Shape
//
// The iconic "B" silhouette used across the Metrobús system for every line
// badge. Pages 17-23 of the Movilidad Integrada manual show the construction:
// a left rectangle attached to two right-bulging half-circles (top smaller,
// bottom larger), meeting at a pinch point on the middle-right.
//
// Drawn as a SwiftUI Path so it renders crisp at every size — replaces the
// bitmap line icons from TransitImageLoader that pixelated at small sizes.
//
//                ┌─────────┐
//                │         ╲
//                │          ╲       ← top lobe (smaller arc, radius 0.20·h)
//                │          ╱
//                ├──pinch──╱        ← right pinch at x = 0.65·w, y = 0.40·h
//                │          ╲
//                │           ╲      ← bottom lobe (larger arc, radius 0.30·h)
//                │           ╱
//                └─────────╱
//                left edge   right peak at x ≈ 0.95·w
//
// Asymmetry — bottom lobe larger — is what gives the mark its "B" reading
// rather than reading as a "D".

struct MetrobusLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Operate on a square inscribed in the rect so the shape stays
        // proportional regardless of how the caller sizes us.
        let side = min(rect.width, rect.height)
        let x0 = rect.midX - side / 2
        let y0 = rect.midY - side / 2

        // Proportions (in units of the square's side):
        let pinchXRatio: CGFloat = 0.65   // x of the inward dip at the right
        let topRadiusRatio: CGFloat = 0.20
        let bottomRadiusRatio: CGFloat = 0.30
        // Constraint: top_diameter + bottom_diameter must equal 1
        //   2·topR + 2·bottomR = 1   → 0.40 + 0.60 = 1.00 ✓

        let pinchX = x0 + side * pinchXRatio
        let topR = side * topRadiusRatio
        let bottomR = side * bottomRadiusRatio

        let topCenter = CGPoint(x: pinchX, y: y0 + topR)
        let bottomCenter = CGPoint(x: pinchX, y: y0 + side - bottomR)

        var p = Path()
        // Start top-left, walk clockwise around the silhouette.
        p.move(to: CGPoint(x: x0, y: y0))
        // Top edge → pinch column
        p.addLine(to: CGPoint(x: pinchX, y: y0))
        // Top lobe — half-circle bulging right
        p.addArc(
            center: topCenter,
            radius: topR,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        // Bottom lobe — larger half-circle bulging right
        p.addArc(
            center: bottomCenter,
            radius: bottomR,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        // Bottom edge ← pinch column
        p.addLine(to: CGPoint(x: x0, y: y0 + side))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#if DEBUG
struct MetrobusLineShapePreview: View {
    var body: some View {
        VStack(spacing: 40) {
            // Pure silhouette
            MetrobusLineShape()
                .fill(Color(red: 164/255, green: 52/255, blue: 58/255))
                .frame(width: 200, height: 200)

            // Stacked at small sizes — proves it scales crisp
            HStack(spacing: 20) {
                ForEach(1...7, id: \.self) { num in
                    ZStack {
                        MetrobusLineShape()
                            .fill(lineColor(num).gradient)
                        // Number sits in the LEFT block of the B (visually
                        // balanced — the right lobes already attract the eye).
                        Text("\(num)")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(.white)
                            .offset(x: -8)   // shift left of geometric center
                    }
                    .frame(width: 60, height: 60)
                }
            }

            // At icon scale (32pt)
            HStack(spacing: 12) {
                ForEach(1...7, id: \.self) { num in
                    ZStack {
                        MetrobusLineShape()
                            .fill(lineColor(num))
                        Text("\(num)")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .offset(x: -4)
                    }
                    .frame(width: 32, height: 32)
                }
            }
        }
        .padding()
    }

    private func lineColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 164/255, green: 52/255, blue: 58/255)
        case 2: return Color(red: 135/255, green: 24/255, blue: 157/255)
        case 3: return Color(red: 122/255, green: 154/255, blue: 1/255)
        case 4: return Color(red: 254/255, green: 80/255, blue: 0/255)
        case 5: return Color(red: 0/255, green: 30/255, blue: 96/255)
        case 6: return Color(red: 225/255, green: 0/255, blue: 152/255)
        case 7: return Color(red: 4/255, green: 106/255, blue: 56/255)
        default: return .gray
        }
    }
}

#Preview("Metrobús Line Shape") {
    MetrobusLineShapePreview()
}

#Preview("Dark Mode") {
    MetrobusLineShapePreview()
        .preferredColorScheme(.dark)
}
#endif
