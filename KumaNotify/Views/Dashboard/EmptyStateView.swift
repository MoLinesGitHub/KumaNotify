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
            Button("Setup Wizard...") {
                onOpenWizard()
            }
            SettingsLink {
                Text("Open Settings...")
            }
            Divider()
            Button("Quit") {
                onQuit()
            }
        }
        .padding()
        .frame(width: 240)
    }
}
