import AppKit
import BatteryCore
import QuartzCore

@MainActor
enum BatteryIconStyle {
    case charging, low, veryLow

    init?(reading: BatteryReading?) {
        guard let reading else { return nil }
        if reading.isCharging {
            self = .charging
        } else if reading.charging {
            return nil  // Plugged in, but full or reporting a charging problem.
        } else if reading.percent < 15 {
            self = .veryLow
        } else if reading.percent < 25 {
            self = .low
        } else {
            return nil
        }
    }

    var color: NSColor {
        switch self {
        case .charging: .systemGreen
        case .low: .systemOrange
        case .veryLow: .systemRed
        }
    }
}

/// Draws the colored states over the status button. While charging, the next segment pulses.
@MainActor
final class BatteryIconView: NSView {
    private let segmentLayers = (0..<BatteryGauge.segments).map { _ in CAShapeLayer() }
    private let headband = CAShapeLayer()
    private let earCups = CAShapeLayer()
    private var imageWidth: CGFloat = 0
    private var style: BatteryIconStyle?
    private var pulsing: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
        for (index, segment) in segmentLayers.enumerated() {
            let dash = BatteryGauge.dash(forSegment: index)
            segment.fillColor = nil
            segment.lineWidth = BatteryGauge.lineWidth
            segment.lineCap = .butt
            segment.lineDashPhase = dash.phase
            segment.lineDashPattern = dash.lengths.map { NSNumber(value: Double($0)) }
            layer?.addSublayer(segment)
        }
        headband.fillColor = nil
        headband.lineWidth = BatteryGauge.headbandWidth
        headband.lineCap = .round
        earCups.strokeColor = nil
        layer?.addSublayer(headband)
        layer?.addSublayer(earCups)
        updateColors()
        isHidden = true
    }

    required init?(coder: NSCoder) { nil }

    // Let the status-bar button receive clicks anywhere, including on the gauge.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(reading: BatteryReading?, imageWidth: CGFloat, animateCharging: Bool) {
        self.imageWidth = imageWidth
        style = BatteryIconStyle(reading: reading)
        isHidden = style == nil
        let lit = reading.map { BatteryGauge.litSegments(percent: $0.percent) } ?? 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, segment) in segmentLayers.enumerated() {
            segment.opacity = index < lit ? 1 : Float(BatteryGauge.trackAlpha)
        }
        updateColors()
        CATransaction.commit()
        needsLayout = true

        let charging = style == .charging && animateCharging
        setPulse(charging && lit < BatteryGauge.segments ? lit : nil)
    }

    /// Breathes one segment between the track and full color.
    /// Refreshes at the same battery level do not restart the cycle.
    private func setPulse(_ index: Int?) {
        let running = pulsing.map { segmentLayers[$0].animation(forKey: "pulse") != nil } ?? false
        if index == pulsing && (index == nil || running) { return }
        segmentLayers.forEach { $0.removeAnimation(forKey: "pulse") }
        pulsing = index
        guard let index else { return }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = Float(BatteryGauge.trackAlpha)
        pulse.toValue = Float(0.95)
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        segmentLayers[index].add(pulse, forKey: "pulse")
    }

    override func layout() {
        super.layout()
        // NSStatusBarButton centers its image. Match the renderer's 20-point gauge.
        let size = BatteryGauge.size
        let rect = CGRect(
            x: bounds.midX - imageWidth / 2, y: bounds.midY - size / 2, width: size, height: size)
        let frame = BatteryGauge.framePath(in: rect)
        let scale = window?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for shape in segmentLayers + [headband, earCups] {
            shape.frame = bounds
            shape.contentsScale = scale
        }
        segmentLayers.forEach { $0.path = frame }
        headband.path = BatteryGauge.headbandPath(in: rect)
        earCups.path = BatteryGauge.earCupsPath(in: rect)
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color = (style?.color ?? .systemGreen).cgColor
            segmentLayers.forEach { $0.strokeColor = color }
            headband.strokeColor = color
            earCups.fillColor = color
        }
    }
}
