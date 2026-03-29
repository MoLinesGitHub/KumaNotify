import SwiftUI

struct WatchStatusOrbView: View {
    let summary: WatchStatusSummary
    @State private var pulseScale: CGFloat = 1.0
    @State private var innerGlow: CGFloat = 0.4
    @State private var appeared = false

    private let orbSize: CGFloat = 52

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            summary.color.opacity(0.3),
                            summary.color.opacity(0.05),
                            .clear,
                        ],
                        center: .center,
                        startRadius: orbSize * 0.3,
                        endRadius: orbSize * 0.8
                    )
                )
                .frame(width: orbSize * 1.6, height: orbSize * 1.6)
                .scaleEffect(pulseScale)

            // Glass orb body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            summary.color.opacity(0.7),
                            summary.color.opacity(0.4),
                            summary.color.opacity(0.15),
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: orbSize * 0.5
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    // Inner glass highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(innerGlow),
                                    Color.white.opacity(0.05),
                                    .clear,
                                ],
                                center: UnitPoint(x: 0.3, y: 0.25),
                                startRadius: 0,
                                endRadius: orbSize * 0.35
                            )
                        )
                }
                .overlay {
                    // Glass border
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: summary.color.opacity(0.5), radius: 10)

            // Status text overlay
            VStack(spacing: 1) {
                if summary.totalCount > 0 {
                    Text("\(summary.upCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/\(summary.totalCount)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.3)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                appeared = true
            }
            withAnimation(
                .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.12
                innerGlow = 0.6
            }
        }
    }
}
