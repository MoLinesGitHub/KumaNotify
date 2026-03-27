import SwiftUI

struct SparklineView: View {
    let dataPoints: [Int]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard dataPoints.count >= 2 else { return }
            let maxVal = Double(dataPoints.max() ?? 1)
            let minVal = Double(dataPoints.min() ?? 0)
            let range = max(maxVal - minVal, 1)

            let points: [CGPoint] = dataPoints.enumerated().map { index, point in
                let x = size.width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let y = size.height * (1 - (Double(point) - minVal) / range)
                return CGPoint(x: x, y: y)
            }

            // Fill gradient under the line
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: points[0].x, y: size.height))
            for pt in points { fillPath.addLine(to: pt) }
            fillPath.addLine(to: CGPoint(x: points.last!.x, y: size.height))
            fillPath.closeSubpath()

            let gradient = Gradient(colors: [color.opacity(0.3), color.opacity(0.05)])
            context.fill(
                fillPath,
                with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )

            // Stroke line
            var linePath = Path()
            for (i, pt) in points.enumerated() {
                if i == 0 { linePath.move(to: pt) }
                else { linePath.addLine(to: pt) }
            }
            context.stroke(linePath, with: .color(color), lineWidth: 1.5)

            // Last point dot
            if let last = points.last {
                let dot = CGRect(x: last.x - 2, y: last.y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dot), with: .color(color))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Response time trend"))
        .accessibilityValue(sparklineSummary)
    }

    private var sparklineSummary: String {
        guard !dataPoints.isEmpty else { return "" }
        let last = dataPoints.last ?? 0
        let min = dataPoints.min() ?? 0
        let max = dataPoints.max() ?? 0
        let currentText = String.localizedStringWithFormat(String(localized: "%@ms"), String(last))
        let minText = String.localizedStringWithFormat(String(localized: "%@ms"), String(min))
        let maxText = String.localizedStringWithFormat(String(localized: "%@ms"), String(max))
        return String.localizedStringWithFormat(
            String(localized: "%1$@ current, %2$@ min, %3$@ max"),
            currentText,
            minText,
            maxText
        )
    }
}
