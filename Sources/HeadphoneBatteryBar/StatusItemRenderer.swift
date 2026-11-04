import AppKit
import BatteryCore

@MainActor
enum StatusItemRenderer {
    static func image(for snapshot: HeadsetSnapshot) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
        let text = snapshot.percentText as NSString
        let textSize = text.size(withAttributes: attributes)
        let gaugeSize: CGFloat = 20
        let gap: CGFloat = 4
        let height: CGFloat = 22
        let colored = BatteryIconStyle(reading: snapshot.reading) != nil
        let width = ceil(gaugeSize + gap + textSize.width)
        let headphones = NSImage(systemSymbolName: "headphones", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let rect = NSRect(x: 0, y: 1, width: gaugeSize, height: gaugeSize)
            // Colored states use a separate overlay; only the percentage is templated.
            if !colored {
                drawGauge(percent: snapshot.reading?.percent, in: rect)
                headphones?.draw(in: NSRect(x: 4, y: 5, width: 12, height: 12))
            }
            text.draw(
                at: NSPoint(x: gaugeSize + gap, y: (height - textSize.height) / 2 + 0.5),
                withAttributes: attributes
            )
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawGauge(percent: Int?, in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.22).cgColor)
        context.setLineWidth(2.5)
        context.strokeEllipse(in: rect.insetBy(dx: 1.25, dy: 1.25))
        guard let percent, percent > 0 else { return }
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineCap(.butt)
        context.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2 - 1.25,
            startAngle: .pi / 2,
            endAngle: .pi / 2 - 2 * .pi * CGFloat(percent) / 100,
            clockwise: true
        )
        context.strokePath()
    }
}
