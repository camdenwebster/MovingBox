import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]

    var body: some View {
        ZStack {
            ForEach(0..<60) { index in
                ConfettiPiece(
                    color: colors[index % colors.count],
                    delay: Double(index) * 0.01,
                    animate: $animate
                )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let delay: Double
    @Binding var animate: Bool

    @State private var xOffset: CGFloat = 0
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    private let randomX = CGFloat.random(in: -150...150)
    private let randomY = CGFloat.random(in: -400...100)
    private let randomRotation = Double.random(in: 0...360)

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
            .opacity(opacity)
            .onChange(of: animate) { _, newValue in
                if newValue {
                    withAnimation(
                        .easeOut(duration: 2.5)
                            .delay(delay)
                    ) {
                        xOffset = randomX
                        yOffset = randomY
                        rotation = randomRotation
                        opacity = 0
                    }
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfettiView()
    }
}
