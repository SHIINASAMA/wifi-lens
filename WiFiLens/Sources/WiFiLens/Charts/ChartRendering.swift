import SwiftUI

/// Draw X and Y axis lines at the edges of the chart rect.
func drawAxes(context: inout GraphicsContext, chartRect: CGRect, color: Color = .secondary, lineWidth: CGFloat = 1) {
    var xAxis = Path()
    xAxis.move(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
    xAxis.addLine(to: CGPoint(x: chartRect.maxX, y: chartRect.maxY))
    context.stroke(xAxis, with: .color(color), lineWidth: lineWidth)

    var yAxis = Path()
    yAxis.move(to: CGPoint(x: chartRect.minX, y: chartRect.minY))
    yAxis.addLine(to: CGPoint(x: chartRect.minX, y: chartRect.maxY))
    context.stroke(yAxis, with: .color(color), lineWidth: lineWidth)
}

/// Draw horizontal grid lines with value labels, striding by `step` from yMin through yMax.
func drawYAxisGrid(
    context: inout GraphicsContext,
    chartRect: CGRect,
    yMin: Double,
    yMax: Double,
    scaleY: CGFloat,
    step: Int = 10,
    gridColor: Color = .gray.opacity(0.15),
    lineWidth: CGFloat = 1,
    labelColor: Color = .secondary
) {
    for val in stride(from: Int(yMin), through: Int(yMax), by: step) {
        let y = chartRect.maxY - (Double(val) - yMin) * scaleY
        var line = Path()
        line.move(to: CGPoint(x: chartRect.minX, y: y))
        line.addLine(to: CGPoint(x: chartRect.maxX, y: y))
        context.stroke(line, with: .color(gridColor), lineWidth: lineWidth)
        context.draw(
            Text("\(val)").font(.caption2).foregroundColor(labelColor),
            at: CGPoint(x: chartRect.minX - 14, y: y)
        )
    }
}

/// Fill area under a curve and stroke its upper edge.
func drawAreaAndLine(
    context: inout GraphicsContext,
    areaPath: Path,
    linePath: Path,
    fillColor: Color,
    strokeColor: Color,
    lineWidth: CGFloat = 1.5
) {
    context.fill(areaPath, with: .color(fillColor))
    context.stroke(linePath, with: .color(strokeColor), lineWidth: lineWidth)
}

/// Evenly spaced indices covering [0, count), always including first and last.
func evenlySpacedTickIndices(count: Int, targetCount: Int) -> [Int] {
    guard count > 0, targetCount > 0 else { return [] }
    let step = max(1, (count - 1) / max(1, targetCount - 1))
    var result: [Int] = []
    for i in stride(from: 0, to: count, by: step) {
        result.append(i)
    }
    if let last = result.last, last != count - 1 {
        result.append(count - 1)
    }
    return result
}
