import AppKit
import BatteryCore
import QuartzCore

@MainActor
enum BatteryIconStyle {
    case charging, lowBattery

    init?(reading: BatteryReading?) {
        guard let reading else { return nil }
        if reading.isCharging {
            self = .charging
        } else if !reading.charging && reading.percent < 15 {
            self = .lowBattery
        } else {
            return nil
        }
    }

    var color: NSColor { self == .charging ? .systemGreen : .systemRed }
}

/// Colors the gauge and headphones while the percentage keeps native menu-bar tinting.
@MainActor
final class BatteryIconView: NSView {
    private let track = CAShapeLayer()
    private let charge = CAShapeLayer()
    /// Translucent extension that fills from the real level toward 100% while charging.
    private let fill = CAShapeLayer()
    private var fillLevel: CGFloat?
    private let headphones = CALayer()
    private let headphonesMask = CALayer()
    private var imageWidth: CGFloat = 0
    private var style: BatteryIconStyle?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
        for shape in [track, fill, charge] {
            shape.fillColor = nil
            shape.lineWidth = 2.5
            layer?.addSublayer(shape)
        }
        fill.opacity = 0
        let symbol = NSImage(systemSymbolName: "headphones", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 22, weight: .semibold))
        headphonesMask.contents = symbol?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        headphones.mask = headphonesMask
        layer?.addSublayer(headphones)
        updateColors()
        isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    // Let the status-bar button receive clicks anywhere, including on the ring.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(reading: BatteryReading?, imageWidth: CGFloat, reduceMotion: Bool) {
        self.imageWidth = imageWidth
        style = BatteryIconStyle(reading: reading)
        isHidden = style == nil
        guard let reading, let style else {
            stopFilling()
            return
        }
        let level = CGFloat(reading.percent) / 100
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        charge.strokeEnd = level
        updateColors()
        CATransaction.commit()
        needsLayout = true

        // Near full, a tiny extension would only twitch, so the ring stays steady.
        if style == .charging && !reduceMotion && reading.percent < 95 {
            startFilling(from: level)
        } else {
            stopFilling()
        }
    }

    /// Repeats a forward-only fill: fade in at the real level, grow to 100%,
    /// fade out at full, then restart invisibly. The solid arc never moves.
    private func startFilling(from level: CGFloat) {
        guard fillLevel != level || fill.animation(forKey: "chargingFill") == nil else { return }
        fillLevel = level
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.strokeStart = level
        fill.strokeEnd = level
        CATransaction.commit()

        let duration: CFTimeInterval = 3.5
        let grow = CAKeyframeAnimation(keyPath: "strokeEnd")
        grow.duration = duration
        grow.values = [level, 1, 1]
        grow.keyTimes = [0, 0.7, 1]
        grow.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .linear)]

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.duration = duration
        fade.values = [0, 0.45, 0.45, 0, 0]
        fade.keyTimes = [0, 0.15, 0.7, 0.95, 1]

        let group = CAAnimationGroup()
        group.animations = [grow, fade]
        group.duration = duration
        group.repeatCount = .infinity
        fill.add(group, forKey: "chargingFill")
    }

    private func stopFilling() {
        fill.removeAllAnimations()
        fillLevel = nil
    }

    override func layout() {
        super.layout()
        // NSStatusBarButton centers its image. Match the renderer's 20-point gauge
        // at the left of that image, including when the percentage changes width.
        let center = CGPoint(x: bounds.midX - imageWidth / 2 + 10, y: bounds.midY)
        let path = CGMutablePath()
        path.addArc(center: center, radius: 8.75, startAngle: .pi / 2, endAngle: -.pi * 1.5, clockwise: true)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for shape in [track, fill, charge] {
            shape.frame = bounds
            shape.path = path
            shape.contentsScale = window?.backingScaleFactor ?? 2
        }
        headphones.frame = CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)
        headphonesMask.frame = headphones.bounds
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color = style?.color ?? .systemGreen
            track.strokeColor = color.withAlphaComponent(0.22).cgColor
            charge.strokeColor = color.cgColor
            fill.strokeColor = color.cgColor
            headphones.backgroundColor = color.cgColor
        }
    }
}
