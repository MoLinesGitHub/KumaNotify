import SwiftUI

struct EmptyStateView: View {
    let onOpenWizard: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Kuma Notify")
                .font(.headline)
            Text("Configure a server in Settings")
                .font(.caption)
                .foregroundStyle(.secondary)

            MenuBarButton(title: "Setup Wizard...", icon: "wand.and.stars") {
                onOpenWizard()
            }

            SettingsLink {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings...")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Divider()

            MenuBarButton(title: "Quit", icon: "power") {
                onQuit()
            }
        }
        .padding()
        .frame(width: 240)
    }
}

struct MenuBarButton: View {
    let title: LocalizedStringKey
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isHovered ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 6))
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
