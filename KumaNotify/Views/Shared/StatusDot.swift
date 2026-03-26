import SwiftUI

struct StatusDot: View {
    let status: MonitorStatus
    var animated: Bool = false
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 10, height: 10)
            .shadow(color: status.color.opacity(0.5), radius: isPulsing ? 6 : 0)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .animation(
                animated
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                isPulsing = animated
            }
            .onChange(of: animated) { _, newValue in
                isPulsing = newValue
            }
    }
}
