import SwiftUI

struct ToolbarButton: View {
    let systemName: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13))
            .foregroundStyle(isHovered ? .primary : .secondary)
            .frame(width: 30, height: 30)
            .background(isHovered ? .white.opacity(0.12) : .white.opacity(0.05), in: Circle())
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
            .onTapGesture { action() }
    }
}
