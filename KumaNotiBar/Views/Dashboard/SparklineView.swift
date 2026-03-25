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

            var path = Path()
            for (index, point) in dataPoints.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let y = size.height * (1 - CGFloat(Double(point) - minVal) / range)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}
