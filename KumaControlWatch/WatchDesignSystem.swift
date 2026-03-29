import SwiftUI

// MARK: - Color Tokens

extension Color {
    static let kumaGlassBorder = Color.white.opacity(0.15)
    static let kumaGlassFill = Color.white.opacity(0.06)
    static let kumaGlassHighlight = Color.white.opacity(0.12)
}

// MARK: - Glass Card Modifier

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 14
    var glowColor: Color? = nil
    var intensity: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.kumaGlassHighlight,
                                        Color.kumaGlassFill,
                                        Color.clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.05),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .shadow(
                color: (glowColor ?? .clear).opacity(0.3 * intensity),
                radius: 8,
                y: 2
            )
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = 14,
        glowColor: Color? = nil,
        intensity: CGFloat = 1.0
    ) -> some View {
        modifier(GlassCardStyle(
            cornerRadius: cornerRadius,
            glowColor: glowColor,
            intensity: intensity
        ))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.08),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(25))
                .offset(x: phase * 200)
                .mask(content)
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: false)
                        .delay(0.3)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Pulse Glow

struct PulseGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isGlowing ? 0.6 : 0.15), radius: isGlowing ? radius : radius * 0.3)
            .shadow(color: color.opacity(isGlowing ? 0.3 : 0.05), radius: isGlowing ? radius * 1.5 : radius * 0.5)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: true)
                ) {
                    isGlowing = true
                }
            }
    }
}

extension View {
    func pulseGlow(color: Color, radius: CGFloat = 10) -> some View {
        modifier(PulseGlowModifier(color: color, radius: radius))
    }
}

// MARK: - Staggered Appear

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .scaleEffect(appeared ? 1 : 0.92)
            .onAppear {
                withAnimation(
                    .spring(response: 0.5, dampingFraction: 0.75)
                        .delay(baseDelay + Double(index) * 0.08)
                ) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredAppear(index: Int, baseDelay: Double = 0.1) -> some View {
        modifier(StaggeredAppearModifier(index: index, baseDelay: baseDelay))
    }
}

// MARK: - Marquee Text (horizontal scroll banner)

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    private let speed: Double = 30
    private let pauseDuration: Double = 1.5
    private let gap: CGFloat = 40

    private var needsScroll: Bool { textWidth > containerWidth && containerWidth > 0 }

    var body: some View {
        ZStack(alignment: .leading) {
            if needsScroll {
                HStack(spacing: gap) {
                    marqueeLabel
                    marqueeLabel
                }
                .offset(x: offset)
            } else {
                marqueeLabel
            }
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            if containerWidth != newWidth {
                containerWidth = newWidth
                restartIfNeeded()
            }
        }
    }

    private var marqueeLabel: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                if textWidth != newWidth {
                    textWidth = newWidth
                    restartIfNeeded()
                }
            }
    }

    private func restartIfNeeded() {
        guard needsScroll else {
            offset = 0
            return
        }
        offset = 0
        let scrollDistance = textWidth + gap
        let duration = scrollDistance / speed

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(pauseDuration * 1000)))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                offset = -scrollDistance
            }
        }
    }
}

// MARK: - Status Color Glow Card

struct StatusGlowCard<Content: View>: View {
    let statusColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .glassCard(glowColor: statusColor, intensity: 0.8)
    }
}
