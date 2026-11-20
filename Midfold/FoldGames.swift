import SwiftUI

// MARK: - Fold Flight

final class FlightModel: ObservableObject {
    @Published var engine = FlightEngine()
    @Published var best = UserDefaults.standard.integer(forKey: "best.flight")
    @Published var newBest = false
    let ticker = Ticker()
    weak var hinge: HingeModel?
    private var frozen = false

    func attach(_ h: HingeModel) {
        hinge = h
        if ShotsTour.active { preset(angle: h.angle) }
        ticker.onTick = { [weak self] dt, _ in self?.tick(dt) }
        ticker.start()
    }

    /// Screenshot state: a flight in progress with the glider lined up in the next gap.
    private func preset(angle: Double) {
        frozen = true
        var e = FlightEngine(aspect: engine.aspect, seed: 21)
        e.start()
        for _ in 0..<(60 * 14) {
            let next = e.walls.first { $0.x + FlightEngine.wallWidth / 2 > FlightEngine.gliderX - 0.05 }
            e.step(dt: 1.0 / 60, angle: HingeScale.angle((0.92 - (next?.gapCenter ?? 0.5)) / 0.84))
        }
        let y = FlightEngine.targetY(angle: angle)
        if let i = e.walls.firstIndex(where: { $0.x > FlightEngine.gliderX + 0.1 }) {
            e.walls[i].gapCenter = min(0.88 - e.walls[i].gapHeight / 2, max(0.12 + e.walls[i].gapHeight / 2, y))
        }
        e.walls.removeAll { abs($0.x - FlightEngine.gliderX) < FlightEngine.wallWidth }
        e.y = y
        e.phase = .flying
        engine = e
        best = max(best, 24)
    }

    func tick(_ dt: Double) {
        guard let h = hinge else { return }
        if frozen { engine.steer(dt: dt, angle: h.angle); return }
        let was = engine.phase
        engine.step(dt: dt, angle: h.angle)
        if was == .flying {
            if engine.phase == .crashed {
                Haptics.thump()
                if engine.score > best {
                    best = engine.score; newBest = true
                    UserDefaults.standard.set(best, forKey: "best.flight")
                }
            }
        }
    }

    func tap() {
        guard engine.phase != .flying else { return }
        newBest = false
        engine.start()
        Haptics.tap()
    }

    func setAspect(_ a: Double) {
        guard engine.phase != .flying else { return }
        engine.aspect = a
        if ShotsTour.active, let h = hinge { preset(angle: h.angle) }
    }
}

struct FlightView: View {
    @EnvironmentObject var hinge: HingeModel
    @Environment(\.closeGame) private var close
    @StateObject private var model = FlightModel()

    var body: some View {
        GeometryReader { g in
            ZStack {
                FlightCanvas(engine: model.engine)
                    .contentShape(Rectangle())
                    .onTapGesture { model.tap() }
                    .onAppear { model.setAspect(g.size.width / max(1, g.size.height)) }
                    .onChange(of: g.size) { _, s in model.setAspect(s.width / max(1, s.height)) }
                hud
                if model.engine.phase != .flying { overlay.allowsHitTesting(false) }
            }
        }
        .ignoresSafeArea()
        .onAppear { model.attach(hinge); hinge.beginUse() }
        .onDisappear { model.ticker.stop(); hinge.endUse() }
    }

    private var hud: some View {
        VStack {
            HStack(alignment: .top) {
                CloseButton(action: close)
                Spacer()
                VStack(spacing: 0) {
                    Text("\(model.engine.score)")
                        .font(.system(size: 54, weight: .heavy, design: .rounded).monospacedDigit())
                    Text("Best \(model.best)").font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                HingeDial(angle: hinge.angle)
                    .frame(width: 120, height: 66)
            }
            .padding(.horizontal, 24).padding(.top, 20)
            Spacer()
            if hinge.usesSlider {
                HStack { Spacer(); AngleSlider(angle: $hinge.sliderAngle).frame(height: 260) }
                    .padding(.trailing, 24).padding(.bottom, 30)
            }
        }
        .foregroundStyle(.white)
    }

    private var overlay: some View {
        VStack(spacing: 10) {
            if model.engine.phase == .crashed {
                (model.newBest ? Text("New best!") : Text("Crashed!"))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
            } else {
                Text("Fold Flight").font(.system(size: 40, weight: .heavy, design: .rounded))
            }
            Text(hinge.hasHinge ? "Open wider to climb, close to dive." : instructions)
                .font(.title3.weight(.semibold))
            (model.engine.phase == .crashed ? Text("Tap to fly again") : Text("Tap to fly"))
                .font(.headline).padding(.horizontal, 22).padding(.vertical, 10)
                .background(.white.opacity(0.18), in: Capsule())
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(28)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var instructions: LocalizedStringKey {
        hinge.usesSlider ? "Slide up to climb, down to dive." : "Tilt toward you to climb, lay it back to dive."
    }
}

/// Draws the sky, the folded-paper walls and the glider. Units: 1 = screen height.
struct FlightCanvas: View {
    let engine: FlightEngine

    var body: some View {
        Canvas { ctx, size in
            let h = size.height
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.15, green: 0.22, blue: 0.48), Color(red: 0.42, green: 0.36, blue: 0.62),
                                  Color(red: 0.96, green: 0.62, blue: 0.48)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            // Distant paper hills.
            for (i, alpha) in [(0, 0.10), (1, 0.16)] {
                var hill = Path()
                hill.move(to: CGPoint(x: 0, y: h))
                let base = h * (0.80 + Double(i) * 0.08)
                stride(from: 0.0, through: size.width, by: 40).forEach { x in
                    let wave = sin((x / size.width + Double(i) * 0.3 + engine.elapsed * 0.02 * Double(i + 1)) * .pi * 3)
                    hill.addLine(to: CGPoint(x: x, y: base + wave * h * 0.03))
                }
                hill.addLine(to: CGPoint(x: size.width, y: h))
                ctx.fill(hill, with: .color(.white.opacity(alpha)))
            }
            let ww = FlightEngine.wallWidth * h
            for w in engine.walls {
                let x = w.x * h - ww / 2
                let top = (w.gapCenter - w.gapHeight / 2) * h
                let bottom = (w.gapCenter + w.gapHeight / 2) * h
                for r in [CGRect(x: x, y: -10, width: ww, height: top + 10),
                          CGRect(x: x, y: bottom, width: ww, height: h - bottom + 10)] {
                    let p = Path(roundedRect: r, cornerRadius: 6)
                    ctx.fill(p, with: .color(Palette.paper))
                    // The crease down the middle of each folded strip, and its shaded half.
                    ctx.fill(Path(CGRect(x: r.midX, y: r.minY, width: r.width / 2, height: r.height)),
                             with: .color(.black.opacity(0.10)))
                    var crease = Path(); crease.move(to: CGPoint(x: r.midX, y: r.minY)); crease.addLine(to: CGPoint(x: r.midX, y: r.maxY))
                    ctx.stroke(crease, with: .color(.black.opacity(0.22)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
            }
            // Paper glider.
            let gx = FlightEngine.gliderX * h, gy = engine.y * h, s = FlightEngine.gliderRadius * h * 1.6
            let tilt = engine.phase == .crashed ? 0.6 : 0
            var plane = Path()
            plane.move(to: CGPoint(x: s, y: 0))
            plane.addLine(to: CGPoint(x: -s, y: -s * 0.55))
            plane.addLine(to: CGPoint(x: -s * 0.55, y: 0))
            plane.addLine(to: CGPoint(x: -s, y: s * 0.45))
            plane.closeSubpath()
            var fold = Path(); fold.move(to: CGPoint(x: s, y: 0)); fold.addLine(to: CGPoint(x: -s * 0.55, y: 0))
            let t = CGAffineTransform(translationX: gx, y: gy).rotated(by: tilt)
            ctx.fill(plane.applying(t), with: .color(.white))
            ctx.stroke(fold.applying(t), with: .color(Palette.blue), lineWidth: 2)
        }
    }
}

// MARK: - Angle Lock

final class AngleLockModel: ObservableObject {
    @Published var engine = AngleLockEngine()
    @Published var best = UserDefaults.standard.double(forKey: "best.lock")
    @Published var newBest = false
    let ticker = Ticker()
    weak var hinge: HingeModel?

    func attach(_ h: HingeModel) {
        hinge = h
        if ShotsTour.active {
            // Screenshot state: four targets locked, the fifth almost held.
            engine.start(seed: 4)
            engine.targets[4] = (h.angle / 5).rounded() * 5 + 2
            engine.index = 4
            engine.hold = 0.55
            engine.elapsed = 9.6
            best = 18.4
            return
        }
        ticker.onTick = { [weak self] dt, _ in self?.tick(dt) }
        ticker.start()
    }

    func tick(_ dt: Double) {
        guard let h = hinge, engine.phase == .playing else { return }
        if engine.step(dt: dt, angle: h.angle) {
            Haptics.success()
            if engine.phase == .finished, best == 0 || engine.elapsed < best {
                best = engine.elapsed; newBest = true
                UserDefaults.standard.set(best, forKey: "best.lock")
            }
        }
    }

    func tap() {
        guard engine.phase != .playing else { return }
        newBest = false
        engine.start(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        Haptics.tap()
    }
}

struct AngleLockView: View {
    @EnvironmentObject var hinge: HingeModel
    @Environment(\.closeGame) private var close
    @StateObject private var model = AngleLockModel()

    var body: some View {
        ZStack {
            PaperBackground()
            GeometryReader { g in
                let wide = g.size.width > g.size.height
                let dialW = min(g.size.width * (wide ? 0.62 : 0.9), (g.size.height - 140) * 1.9)
                VStack(spacing: 18) {
                    Spacer(minLength: 70)
                    status
                    HingeDial(angle: hinge.angle, target: model.engine.target,
                              progress: model.engine.holdProgress,
                              tint: model.engine.isOnTarget(hinge.angle) ? Palette.orange : Palette.blue)
                        .frame(width: dialW, height: dialW / 1.8)
                    progressDots
                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.tap() }
            VStack {
                HStack {
                    CloseButton(action: close)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(String(format: "%.1f s", model.engine.elapsed))
                            .font(.system(.title, design: .rounded).weight(.heavy).monospacedDigit())
                        if model.best > 0 {
                            Text("Best \(String(format: "%.1f s", model.best))").font(.caption.bold()).opacity(0.7)
                        }
                    }
                }
                Spacer()
                if hinge.usesSlider {
                    HStack { Spacer(); AngleSlider(angle: $hinge.sliderAngle).frame(height: 240) }
                }
            }
            .padding(24)
        }
        .foregroundStyle(.white)
        .onAppear { model.attach(hinge); hinge.beginUse() }
        .onDisappear { model.ticker.stop(); hinge.endUse() }
    }

    @ViewBuilder private var status: some View {
        switch model.engine.phase {
        case .ready:
            VStack(spacing: 8) {
                Text("Angle Lock").font(.system(size: 38, weight: .heavy, design: .rounded))
                (hinge.hasHinge ? Text("Fold the phone to each target angle and hold it.") : Text("Set each target angle and hold it."))
                    .font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                Text("Tap to start").font(.headline).padding(.horizontal, 20).padding(.vertical, 9)
                    .background(.white.opacity(0.16), in: Capsule())
            }
        case .playing:
            if let t = model.engine.target {
                Text("Target \(Int(t))°").font(.system(size: 38, weight: .heavy, design: .rounded))
            }
        case .finished:
            VStack(spacing: 8) {
                (model.newBest ? Text("New best!") : Text("All locked!")).font(.system(size: 38, weight: .heavy, design: .rounded))
                Text("Tap to play again").font(.headline)
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<AngleLockEngine.count, id: \.self) { i in
                Circle()
                    .fill(i < model.engine.index ? Palette.orange : .white.opacity(0.2))
                    .frame(width: 14, height: 14)
            }
        }
    }
}
