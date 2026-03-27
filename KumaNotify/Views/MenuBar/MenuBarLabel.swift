import SwiftUI

enum MenuBarLabelLogic {
    static func accessibilityDescription(
        overallStatus: OverallStatus,
        upCount: Int,
        totalCount: Int
    ) -> String {
        if case .unreachable = overallStatus {
            return overallStatus.label
        }

        return String.localizedStringWithFormat(
            String(localized: "%@. %lld of %lld monitors up."),
            overallStatus.label,
            Int64(upCount),
            Int64(totalCount)
        )
    }
}

struct MenuBarLabel: View {
    let viewModel: MenuBarViewModel

    @ViewBuilder
    private func statusIcon(size: CGFloat) -> some View {
        Image(viewModel.menuBarImage)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var accessibilityDescription: String {
        MenuBarLabelLogic.accessibilityDescription(
            overallStatus: viewModel.overallStatus,
            upCount: viewModel.upCount,
            totalCount: viewModel.totalCount
        )
    }

    var body: some View {
        Group {
            switch viewModel.iconStyle {
            case .sfSymbol:
                statusIcon(size: 16)

            case .colorDot:
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(viewModel.statusColor)

            case .textAndIcon:
                HStack(spacing: 3) {
                    statusIcon(size: 14)
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
