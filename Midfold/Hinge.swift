import SwiftUI
import CoreMotion

/// The fold games' controller. On iPhone Duo it is the hinge itself (0° closed … 180° flat); on other iPhones
/// and iPads it is tilting the device toward you, or a slider.
final class HingeModel: ObservableObject {
    enum Control: String, CaseIterable, Identifiable {
        case tilt, slider
        var id: String { rawValue }
        var label: LocalizedStringKey { self == .tilt ? "Tilt" : "Slider" }
    }

    enum Status: Equatable { case unknown, closed, partiallyOpen, fullyOpen }

    /// True once the system has reported a real hinge (iPhone Duo).
    @Published private(set) var hasHinge = false
    @Published private(set) var status: Status = .unknown
    @Published private(set) var hingeAngle = 0.0
    @Published var sliderAngle = 105.0
    @Published private(set) var tiltAngle = 105.0
    @Published var control: Control {
        didSet { UserDefaults.standard.set(control.rawValue, forKey: "control"); updateMotion() }
    }
    /// Screenshot tour only: a fixed angle when the simulator reports no hinge.
    @Published var shotAngle: Double?

    private let motion = CMMotionManager()
    private var users = 0

    init() {
        let saved = UserDefaults.standard.string(forKey: "control").flatMap(Control.init(rawValue:))
        control = saved ?? (CMMotionManager().isDeviceMotionAvailable ? .tilt : .slider)
    }

    var motionAvailable: Bool { motion.isDeviceMotionAvailable }

    /// The angle the games read.
    var angle: Double {
        if hasHinge { return hingeAngle }
        if let s = shotAngle { return s }
        switch control {
        case .tilt where motionAvailable: return tiltAngle
        default: return sliderAngle
        }
    }

    var usesSlider: Bool { !hasHinge && shotAngle == nil && (control == .slider || !motionAvailable) }

    func update(status: Status, angle: Double) {
        if status != .unknown { hasHinge = true }
        self.status = status
        hingeAngle = min(180, max(0, angle))
    }

    /// Games call these so the motion sensor only runs while a fold game is on screen.
    func beginUse() { users += 1; updateMotion() }
    func endUse() { users = max(0, users - 1); updateMotion() }

    private func updateMotion() {
        let want = users > 0 && !hasHinge && control == .tilt && motion.isDeviceMotionAvailable
        if want && !motion.isDeviceMotionActive {
            motion.deviceMotionUpdateInterval = 1.0 / 60
            motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
                guard let self, let g = m?.gravity else { return }
                // Flat on its back = 40°, upright facing you = 170°. Uses gravity so it works in any orientation.
                let lean = sqrt(g.x * g.x + g.y * g.y)
                let u = min(1, max(0, atan2(lean, -g.z) / (.pi / 2)))
                self.tiltAngle = HingeScale.angle(u)
            }
        } else if !want && motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
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

/// Half-circle dial showing an angle (and optionally a target band), drawn like the phone's hinge seen from the side.
struct HingeDial: View {
    var angle: Double
    var target: Double?
    var tolerance: Double = AngleLockEngine.tolerance
    var progress: Double = 0
    var tint: Color = Palette.blue

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width / 2, size.height) - 8
            let c = CGPoint(x: size.width / 2, y: size.height - 4)
            func pt(_ deg: Double, _ rad: Double) -> CGPoint {
                // 0° = closed (pointing left along the base), 180° = flat (pointing right).
                let a = Double.pi - deg * .pi / 180
                return CGPoint(x: c.x + cos(a) * rad, y: c.y - sin(a) * rad)
            }
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            ctx.stroke(arc, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            if let t = target {
                var band = Path()
                band.addArc(center: c, radius: r, startAngle: .degrees(180 + t - tolerance),
                            endAngle: .degrees(180 + t + tolerance), clockwise: false)
                ctx.stroke(band, with: .color(Palette.orange), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                if progress > 0 {
                    var ring = Path()
                    ring.addArc(center: pt(t, r), radius: 14, startAngle: .degrees(-90),
                                endAngle: .degrees(-90 + 360 * progress), clockwise: false)
                    ctx.stroke(ring, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
            }
            // Fixed half (base) and moving half (lid), like the two halves of the phone.
            var base = Path(); base.move(to: c); base.addLine(to: pt(0, r * 0.82))
            ctx.stroke(base, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            var lid = Path(); lid.move(to: c); lid.addLine(to: pt(angle, r * 0.82))
            ctx.stroke(lid, with: .color(tint), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.white))
        }
        .overlay(alignment: .bottom) {
            Text("\(Int(angle.rounded()))°")
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.bottom, 18)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Angle \(Int(angle.rounded())) degrees"))
    }
}

/// Vertical slider used as the controller on devices without a hinge (and when the person picks it).
struct AngleSlider: View {
    @Binding var angle: Double
    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            let u = HingeScale.unit(angle)
            ZStack(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.14))
                Capsule().fill(Palette.blue.opacity(0.85)).frame(height: max(44, h * u))
                Circle().fill(.white).frame(width: 40, height: 40)
                    .offset(y: -(h - 44) * u - 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let unit = 1 - min(1, max(0, (v.location.y - 22) / max(1, h - 44)))
                angle = HingeScale.angle(unit)
            })
        }
        .frame(width: 48)
        .accessibilityElement()
        .accessibilityLabel(Text("Angle"))
        .accessibilityValue(Text("\(Int(angle)) degrees"))
        .accessibilityAdjustableAction { dir in
            angle = min(HingeScale.high, max(HingeScale.low, angle + (dir == .increment ? 5 : -5)))
        }
    }
}
