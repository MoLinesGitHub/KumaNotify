import SwiftUI

// MARK: - Kuma Icon Shapes (from SVG paths, normalized to unit square)

struct KumaRoundedRect: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cornerRadius = w * 0.22
        return Path(roundedRect: CGRect(
            x: w * 0.08, y: h * 0.08,
            width: w * 0.84, height: h * 0.84
        ), cornerRadius: cornerRadius, style: .continuous)
    }
}

struct KumaCheckShape: Shape {
    var animatableData: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        let p1 = CGPoint(x: w * 0.399, y: h * 0.523)
        let p2 = CGPoint(x: w * 0.463, y: h * 0.587)
        let p3 = CGPoint(x: w * 0.611, y: h * 0.434)
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        return path.trimmedPath(from: 0, to: animatableData)
    }
}

struct KumaXShape: Shape {
    var animatableData: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.402, y: h * 0.418))
        path.addLine(to: CGPoint(x: w * 0.598, y: h * 0.614))
        path.move(to: CGPoint(x: w * 0.598, y: h * 0.418))
        path.addLine(to: CGPoint(x: w * 0.402, y: h * 0.614))
        return path.trimmedPath(from: 0, to: animatableData)
    }
}

struct KumaExclamationShape: Shape {
    var animatableData: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.396))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.540))
        let dotCenter = CGPoint(x: w * 0.50, y: h * 0.617)
        let dotRadius = w * 0.039
        path.move(to: CGPoint(x: dotCenter.x + dotRadius, y: dotCenter.y))
        path.addArc(
            center: dotCenter, radius: dotRadius,
            startAngle: .zero, endAngle: .degrees(360),
            clockwise: false
        )
        return path.trimmedPath(from: 0, to: animatableData)
    }
}

struct KumaDashShape: Shape {
    var animatableData: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.394, y: h * 0.502))
        path.addLine(to: CGPoint(x: w * 0.606, y: h * 0.502))
        return path.trimmedPath(from: 0, to: animatableData)
    }
}

// MARK: - Splash Icon Phase

private enum SplashIconPhase: Int, CaseIterable {
    case dash = 0
    case exclamation = 1
    case cross = 2
    case check = 3

    var glowColor: Color {
        switch self {
        case .dash: .appStatusOffline
        case .exclamation: .appStatusDegraded
        case .cross: .appStatusDown
        case .check: .kumaGreen
        }
    }
}

// MARK: - Splash View

struct WatchSplashView: View {
    let isDataLoaded: Bool
    let onFinished: () -> Void

    @State private var rectTrim: CGFloat = 0
    @State private var currentPhase: SplashIconPhase = .dash
    @State private var iconOpacity: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0
    @State private var exitScale: CGFloat = 1
    @State private var exitOpacity: CGFloat = 1
    @State private var animationComplete = false

    private let iconSize: CGFloat = 72
    private let strokeWidth: CGFloat = 5
    private let iconStrokeWidth: CGFloat = 4.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                KumaRoundedRect()
                    .trim(from: 0, to: rectTrim)
                    .stroke(
                        LinearGradient(
                            colors: [Color.kumaGreenLight, Color.kumaGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: currentPhase.glowColor.opacity(glowIntensity * 0.5), radius: 8)

                iconStrokeView(KumaDashShape(animatableData: 1), phase: .dash)
                iconStrokeView(KumaExclamationShape(animatableData: 1), phase: .exclamation)
                iconStrokeView(KumaXShape(animatableData: 1), phase: .cross)
                iconStrokeView(KumaCheckShape(animatableData: 1), phase: .check)
            }
            .frame(width: iconSize, height: iconSize)
            .scaleEffect(exitScale)
            .opacity(exitOpacity)
        }
        .task {
            await runFullAnimation()
        }
    }

    private func iconStrokeView<S: Shape>(_ shape: S, phase: SplashIconPhase) -> some View {
        shape
            .stroke(
                phase.glowColor,
                style: StrokeStyle(
                    lineWidth: iconStrokeWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .opacity(currentPhase == phase ? iconOpacity : 0)
            .shadow(
                color: phase.glowColor.opacity(currentPhase == phase ? glowIntensity * 0.7 : 0),
                radius: 6
            )
    }

    private func runFullAnimation() async {
        // Phase 1: Draw the rounded rect
        withAnimation(.easeOut(duration: 0.6)) {
            rectTrim = 1.0
        }
        try? await Task.sleep(for: .milliseconds(650))

        // Phase 2: Cycle through icons dash → ! → X
        for phase: SplashIconPhase in [.dash, .exclamation, .cross] {
            currentPhase = phase
            withAnimation(.easeIn(duration: 0.25)) {
                iconOpacity = 1
                glowIntensity = 1
            }
            try? await Task.sleep(for: .milliseconds(500))

            withAnimation(.easeOut(duration: 0.2)) {
                iconOpacity = 0
                glowIntensity = 0
            }
            try? await Task.sleep(for: .milliseconds(200))
        }

        // Phase 3: Land on checkmark
        currentPhase = .check
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            iconOpacity = 1
            glowIntensity = 1
        }

        // Wait for data if not ready (max 3s extra)
        if !isDataLoaded {
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(100))
                if isDataLoaded { break }
            }
        }
        try? await Task.sleep(for: .milliseconds(500))

        // Phase 4: Exit
        withAnimation(.easeIn(duration: 0.35)) {
            exitScale = 0.6
            exitOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(400))
        onFinished()
    }
}
