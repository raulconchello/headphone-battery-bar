import AppKit
import QuartzCore

/// A non-interactive overlay that colors only the gauge; the button image stays a template.
@MainActor
final class ChargingRingView: NSView {
    private let track = CAShapeLayer()
    private let charge = CAShapeLayer()
    private var imageWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
        for shape in [track, charge] {
            shape.fillColor = nil
            shape.lineWidth = 2.5
            layer?.addSublayer(shape)
        }
        updateColors()
        isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    // Let the status-bar button receive clicks anywhere, including on the ring.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(percent: Int?, imageWidth: CGFloat, reduceMotion: Bool) {
        self.imageWidth = imageWidth
        isHidden = percent == nil
        guard let percent else {
            charge.removeAllAnimations()
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        charge.strokeEnd = CGFloat(percent) / 100
        CATransaction.commit()
        needsLayout = true

        if reduceMotion {
            charge.removeAnimation(forKey: "chargingPulse")
        } else if charge.animation(forKey: "chargingPulse") == nil {
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.55
            pulse.toValue = 1.0
            pulse.duration = 1.2
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            charge.add(pulse, forKey: "chargingPulse")
        }
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
        for shape in [track, charge] {
            shape.frame = bounds
            shape.path = path
        }
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            track.strokeColor = NSColor.systemGreen.withAlphaComponent(0.22).cgColor
            charge.strokeColor = NSColor.systemGreen.cgColor
        }
    }
}
