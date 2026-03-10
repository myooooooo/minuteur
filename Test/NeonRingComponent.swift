import SwiftUI

struct NeonRingComponent: View {
    let progress: Double
    let colors: [Color]
    let lineWidth: CGFloat
    var glowIntensity: Double = 0

    var body: some View {
        let gradient = AngularGradient(
            gradient: Gradient(colors: [colors[0], colors[1], colors[0]]),
            center: .center
        )

        let glowRadius: CGFloat = 5 + CGFloat(glowIntensity) * 20
        let glowOpacity: Double = 0.5 + glowIntensity * 0.4

        return ZStack {
            Circle()
                .stroke(Color(white: 0.1), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: colors[0].opacity(glowOpacity), radius: glowRadius, x: 0, y: 0)
                .shadow(color: colors[1].opacity(glowOpacity * 0.5), radius: glowRadius * 0.6, x: 0, y: 0)
        }
        // Isolated GPU rasterization only for the neon ring.
        .drawingGroup()
    }
}

#Preview {
    NeonRingComponent(progress: 0.66, colors: [.cyan, .indigo], lineWidth: 8)
        .frame(width: 240, height: 240)
        .padding()
        .background(Color.black)
}
