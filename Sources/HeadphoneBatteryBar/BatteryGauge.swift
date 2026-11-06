import CoreGraphics

/// Geometry shared by the menu-bar image and the colored overlay: ten 10% segments around a
/// rounded square, with a headphone glyph inside. Units are points in a 20×20 box, y up.
enum BatteryGauge {
    static let size: CGFloat = 20
    static let segments = 10
    static let lineWidth: CGFloat = 2.5
    static let headbandWidth: CGFloat = 1.35
    static let trackAlpha: CGFloat = 0.22
    /// The headphones fade to this when there is no reading.
    static let unavailableAlpha: CGFloat = 0.4

    private static let cornerRadius: CGFloat = 5
    private static let side = size - lineWidth
    private static let perimeter = 4 * (side - 2 * cornerRadius) + 2 * .pi * cornerRadius
    private static let gap = perimeter * 0.02

    /// G HUB reports the G522 in 10% steps; anything in between rounds to the nearest segment.
    static func litSegments(percent: Int) -> Int {
        min(max((percent + 5) / 10, 0), segments)
    }

    /// The rounded square, starting at the top center and running clockwise.
    static func framePath(in rect: CGRect) -> CGPath {
        let r = cornerRadius
        let box = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: box.midX, y: box.maxY))
        path.addArc(
            center: CGPoint(x: box.maxX - r, y: box.maxY - r), radius: r,
            startAngle: .pi / 2, endAngle: 0, clockwise: true)
        path.addArc(
            center: CGPoint(x: box.maxX - r, y: box.minY + r), radius: r,
            startAngle: 0, endAngle: -.pi / 2, clockwise: true)
        path.addArc(
            center: CGPoint(x: box.minX + r, y: box.minY + r), radius: r,
            startAngle: -.pi / 2, endAngle: -.pi, clockwise: true)
        path.addArc(
            center: CGPoint(x: box.minX + r, y: box.maxY - r), radius: r,
            startAngle: .pi, endAngle: .pi / 2, clockwise: true)
        path.closeSubpath()
        return path
    }

    /// A dash pattern that strokes only segment `index` of `framePath`.
    static func dash(forSegment index: Int) -> (phase: CGFloat, lengths: [CGFloat]) {
        let step = perimeter / CGFloat(segments)
        let length = step - gap
        let start = CGFloat(index) * step + gap / 2
        return (perimeter - start, [length, perimeter - length])
    }

    static func headbandPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: point(6.35, 8.5, in: rect))
        path.addLine(to: point(6.35, 10.4, in: rect))
        path.addArc(
            center: point(10, 10.4, in: rect), radius: 3.65,
            startAngle: .pi, endAngle: 0, clockwise: true)
        path.addLine(to: point(13.65, 8.5, in: rect))
        return path
    }

    static func earCupsPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        for x: CGFloat in [5.3, 12.2] {
            path.addRoundedRect(
                in: CGRect(x: rect.minX + x, y: rect.minY + 5.9, width: 2.5, height: 3.7),
                cornerWidth: 0.9, cornerHeight: 0.9)
        }
        return path
    }

    /// Draws the gauge in black for a template image. `litSegments == nil` means no reading.
    static func draw(in context: CGContext, rect: CGRect, litSegments lit: Int?) {
        context.saveGState()
        defer { context.restoreGState() }

        let frame = framePath(in: rect)
        context.setLineWidth(lineWidth)
        context.setLineCap(.butt)
        for index in 0..<segments {
            let dash = dash(forSegment: index)
            context.setLineDash(phase: dash.phase, lengths: dash.lengths)
            context.setStrokeColor(gray: 0, alpha: index < (lit ?? 0) ? 1 : trackAlpha)
            context.addPath(frame)
            context.strokePath()
        }

        // A transparency layer keeps the band and cups evenly faint where they overlap.
        context.setLineDash(phase: 0, lengths: [])
        context.setAlpha(lit == nil ? unavailableAlpha : 1)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setStrokeColor(gray: 0, alpha: 1)
        context.setFillColor(gray: 0, alpha: 1)
        context.setLineWidth(headbandWidth)
        context.setLineCap(.round)
        context.addPath(headbandPath(in: rect))
        context.strokePath()
        context.addPath(earCupsPath(in: rect))
        context.fillPath()
        context.endTransparencyLayer()
    }

    private static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x, y: rect.minY + y)
    }
}
