import SwiftUI
import QuartzCore

/// The iPhone Duo hinge as a controller: every angle sample goes through the pump detector, and each completed
/// pump calls `onFlap` with its strength. Without a hinge (other iPhones, iPad) the game uses taps instead.
final class HingeModel: ObservableObject {
    enum Status: Equatable { case unknown, closed, partiallyOpen, fullyOpen }

    /// True once the system has reported a real hinge (iPhone Duo).
    @Published private(set) var hasHinge = false
    @Published private(set) var status: Status = .unknown
    @Published private(set) var angle = 0.0
    /// Last flap strength, for the gauge (fades in the view).
    @Published private(set) var lastFlap: (strength: Double, at: Double)?
    @Published var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "sensitivity"); detector.sensitivity = sensitivity }
    }

    var onFlap: ((Double) -> Void)?
    private var detector = PumpDetector()

    init() {
        let s = UserDefaults.standard.object(forKey: "sensitivity") as? Double ?? 1.0
        sensitivity = s
        detector.sensitivity = s
    }

    func update(status: Status, angle: Double) {
        if status != .unknown { hasHinge = true }
        self.status = status
        self.angle = min(180, max(0, angle))
        let now = CACurrentMediaTime()
        if let strength = detector.feed(angle: self.angle, at: now) {
            lastFlap = (strength, now)
            onFlap?(strength)
        }
    }

    /// Screenshot tour only: show a hinge angle when the simulator has no hinge.
    func showAngle(_ a: Double, flap: Double?) {
        angle = a
        if let f = flap { lastFlap = (f, CACurrentMediaTime()) }
    }
}

/// Reads the iPhone Duo hinge (iOS 27.1) into the model. Elsewhere it does nothing.
struct HingeReader: ViewModifier {
    @ObservedObject var model: HingeModel

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, ctx in
                let h: DeviceHinge? = ctx.hinge
                guard let h else { return }
                let s: HingeModel.Status
                switch h.status {
                case .closed: s = .closed
                case .partiallyOpen: s = .partiallyOpen
                case .fullyOpen: s = .fullyOpen
                default: s = .unknown
                }
                model.update(status: s, angle: h.angle.degrees)
            }
        } else {
            content
        }
    }
}

/// The division (fold) reserved region of an iPhone Duo in this geometry's coordinates, if any.
func foldFrame(_ proxy: GeometryProxy) -> CGRect? {
    if #available(iOS 27.1, *) {
        if let d = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first {
            return d.frame
        }
    }
    return nil
}

/// Small side view of the hinge: the fixed half, the moving half at the current angle, and a strength ring that
/// flashes with each flap.
struct HingeGauge: View {
    var angle: Double
    var flap: Double        // 0 … 1, fading
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height - 6)
            let r = min(size.width / 2, size.height) - 8
            func pt(_ deg: Double, _ rad: Double) -> CGPoint {
                let a = Double.pi - deg * .pi / 180
                return CGPoint(x: c.x + cos(a) * rad, y: c.y - sin(a) * rad)
            }
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(arc, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            if flap > 0.01 {
                var glow = Path()
                glow.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * flap), clockwise: false)
                ctx.stroke(glow, with: .color(Palette.sun.opacity(0.9)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            var base = Path(); base.move(to: c); base.addLine(to: pt(0, r * 0.8))
            ctx.stroke(base, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            var lid = Path(); lid.move(to: c); lid.addLine(to: pt(angle, r * 0.8))
            ctx.stroke(lid, with: .color(.white), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
        .overlay(alignment: .bottom) {
            Text("\(Int(angle.rounded()))°")
                .font(.system(.caption, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.bottom, 10)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Hinge angle \(Int(angle.rounded())) degrees"))
    }
}
