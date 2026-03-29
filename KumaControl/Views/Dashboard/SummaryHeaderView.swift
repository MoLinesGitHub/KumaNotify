import SwiftUI

enum SummaryHeaderViewLogic {
    static func latencyValueText(_ latency: Int) -> String {
        "\(latency)"
    }

    static func lastIncidentText(_ date: Date) -> String {
        String(
            format: String(localized: "Last incident %@"),
            date.formatted(.relative(presentation: .named))
        )
    }
}

struct SummaryHeaderView: View {
    let summary: String
    let latency: Int?
    let overallStatus: OverallStatus
    var lastIncidentDate: Date?

    @State private var pulseScale: CGFloat = 1.0
    @State private var innerGlow: CGFloat = 0.4

    private var statusColor: Color { overallStatus.color }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                // Glass orb (like watch)
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    statusColor.opacity(0.25),
                                    statusColor.opacity(0.05),
                                    .clear,
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 30
                            )
                        )
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulseScale)

                    // Orb body
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    statusColor.opacity(0.65),
                                    statusColor.opacity(0.35),
                                    statusColor.opacity(0.12),
                                ],
                                center: UnitPoint(x: 0.35, y: 0.3),
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay {
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
                                        endRadius: 14
                                    )
                                )
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.05),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: statusColor.opacity(0.4), radius: 8)

                    Image(systemName: overallStatus.sfSymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                    ) {
                        pulseScale = 1.08
                        innerGlow = 0.55
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(overallStatus.label)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(summary)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let latency {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(SummaryHeaderViewLogic.latencyValueText(latency))
                            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(statusColor)
                        Text("ms avg")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let lastIncidentDate {
                HStack(spacing: 4) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.kumaGreen.opacity(0.6))
                        .accessibilityHidden(true)
                    Text(SummaryHeaderViewLogic.lastIncidentText(lastIncidentDate))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            statusColor.opacity(0.08),
                            statusColor.opacity(0.02),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.horizontal, 6)
        }
    }
}
