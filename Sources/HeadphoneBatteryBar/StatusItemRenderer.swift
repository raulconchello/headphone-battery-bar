import AppKit
import BatteryCore

@MainActor
enum StatusItemRenderer {
    /// The gauge and percentage. Plain states are a template image, so macOS tints them to
    /// match the menu bar. Colored states draw only the colored text here; BatteryIconView
    /// draws the colored gauge on top.
    static func image(for snapshot: HeadsetSnapshot) -> NSImage {
        let style = BatteryIconStyle(reading: snapshot.reading)
        let lit = snapshot.reading.map { BatteryGauge.litSegments(percent: $0.percent) }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: style?.color ?? NSColor.black,
        ]
        let text = snapshot.percentText as NSString
        let textSize = text.size(withAttributes: attributes)
        let gauge = BatteryGauge.size
        let gap: CGFloat = 4
        let height: CGFloat = 22
        let image = NSImage(size: NSSize(width: ceil(gauge + gap + textSize.width), height: height), flipped: false) { _ in
            if style == nil, let context = NSGraphicsContext.current?.cgContext {
                BatteryGauge.draw(
                    in: context, rect: CGRect(x: 0, y: 1, width: gauge, height: gauge), litSegments: lit)
            }
            text.draw(
                at: NSPoint(x: gauge + gap, y: (height - textSize.height) / 2 + 0.5),
                withAttributes: attributes)
            return true
        }
        image.isTemplate = style == nil
        return image
    }
}
