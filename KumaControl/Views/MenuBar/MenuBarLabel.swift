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

    private enum Metrics {
        static let iconOnlySize: CGFloat = 12
        static let textAndIconSize: CGFloat = 10
        static let iconBoundingBox: CGFloat = 16
    }

    @ViewBuilder
    private func statusIcon(size: CGFloat) -> some View {
        Image(viewModel.menuBarImage)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .frame(width: Metrics.iconBoundingBox, height: Metrics.iconBoundingBox)
            .clipped()
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
                statusIcon(size: Metrics.iconOnlySize)
                    .symbolEffect(.pulse, isActive: viewModel.hasActiveIncident)

            case .colorDot:
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(viewModel.statusColor)
                    .symbolEffect(.pulse, isActive: viewModel.hasActiveIncident)

            case .textAndIcon:
                HStack(spacing: 3) {
                    statusIcon(size: Metrics.textAndIconSize)
                        .symbolEffect(.pulse, isActive: viewModel.hasActiveIncident)
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
