import SwiftUI

struct NeonCircle: View {
    var body: some View {
        Circle()
            .stroke(lineWidth: 5)
            .foregroundStyle(.cyan)
            .shadow(color: .cyan, radius: 10)
            .drawingGroup() // Isole ici uniquement
    }
}

struct NeonRingView: View {
    let progress: Double
    let colors: [Color]
    let lineWidth: CGFloat

    var body: some View {
        let gradient = AngularGradient(
            gradient: Gradient(colors: [colors[0], colors[1], colors[0]]),
            center: .center
        )

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
                .shadow(color: colors[0].opacity(0.7), radius: 10, x: 0, y: 0)
        }
        .frame(width: 250, height: 250)
        // Isolated GPU rasterization point.
        .drawingGroup()
    }
}

#Preview {
    NeonRingView(progress: 0.7, colors: [.cyan, .indigo], lineWidth: 8)
        .frame(width: 240, height: 240)
        .padding()
        .background(Color.black)
}
