import SwiftUI

struct MenuBarLabel: View {
    let viewModel: MenuBarViewModel

    var body: some View {
        switch viewModel.iconStyle {
        case .sfSymbol:
            Image(systemName: viewModel.menuBarImage)
                .symbolRenderingMode(.palette)
                .foregroundStyle(viewModel.statusColor, .primary)
                .symbolEffect(.pulse, isActive: viewModel.hasActiveIncident)

        case .colorDot:
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(viewModel.statusColor)

        case .textAndIcon:
            HStack(spacing: 3) {
                Image(systemName: viewModel.menuBarImage)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(viewModel.statusColor, .primary)
                Text(viewModel.menuBarTitle)
                    .monospacedDigit()
                    .font(.caption2)
            }
        }
    }
}
