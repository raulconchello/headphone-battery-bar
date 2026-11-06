import AppKit
import BatteryCore

@MainActor
enum StatusItemRenderer {
    /// The gauge as a template image, so macOS tints it to match the menu bar.
    /// Colored states get a blank image of the same size; BatteryIconView draws them on top.
    static func image(for snapshot: HeadsetSnapshot) -> NSImage {
        let colored = BatteryIconStyle(reading: snapshot.reading) != nil
        let lit = snapshot.reading.map { BatteryGauge.litSegments(percent: $0.percent) }
        let size = BatteryGauge.size
        let image = NSImage(size: NSSize(width: size, height: 22), flipped: false) { _ in
            guard !colored, let context = NSGraphicsContext.current?.cgContext else { return true }
            BatteryGauge.draw(
                in: context, rect: CGRect(x: 0, y: 1, width: size, height: size), litSegments: lit)
            return true
        }
        image.isTemplate = true
        return image
    }
}
