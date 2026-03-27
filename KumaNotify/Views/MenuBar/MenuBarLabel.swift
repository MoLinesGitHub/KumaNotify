import SwiftUI

struct MenuBarLabel: View {
    let viewModel: MenuBarViewModel

    private var accessibilityDescription: String {
        if case .unreachable = viewModel.overallStatus {
            return viewModel.overallStatus.label
        }

        return String.localizedStringWithFormat(
            String(localized: "%@. %lld of %lld monitors up."),
            viewModel.overallStatus.label,
            Int64(viewModel.upCount),
            Int64(viewModel.totalCount)
        )
    }

    var body: some View {
        Group {
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
                    if !viewModel.menuBarTitle.isEmpty {
                        Text(viewModel.menuBarTitle)
                            .monospacedDigit()
                            .font(.caption2)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }
}
