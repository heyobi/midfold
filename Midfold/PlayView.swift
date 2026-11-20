import SwiftUI
import QuartzCore

struct PlayRequest: Identifiable, Equatable {
    let id = UUID()
    var spec: LevelSpec
    var dailyKey: String?
}

/// Runs one flight: the simulation, particles, screen shake, and the sound and haptics for every event.
@MainActor
final class GameModel: ObservableObject {
    @Published private(set) var sim: FlightSim
    @Published private(set) var particles: [Particle] = []
    @Published private(set) var shake: CGSize = .zero
    @Published private(set) var clock = 0.0
    @Published var paused = false
    @Published private(set) var newBest = false
    @Published private(set) var endedAt: Double?

    let request: PlayRequest
    private let ticker = Ticker()
    private var shakeAmount = 0.0
    private var rng = SeededRNG(seed: UInt64(Date().timeIntervalSince1970))
    var onFinish: ((FlightSim) -> Bool)?    // returns "new best"

    init(request: PlayRequest) {
        self.request = request
        sim = FlightSim(spec: request.spec)
    }

    func start() {
        ticker.onTick = { [weak self] dt in self?.tick(dt) }
        ticker.start()
    }

    func stop() { ticker.stop() }

    func restart() {
        sim = FlightSim(spec: request.spec)
        particles = []
        newBest = false
        endedAt = nil
        paused = false
    }

    /// A flap from the hinge pump or a tap.
    func flap(_ strength: Double) {
        guard !paused else { return }
        if sim.phase == .won || sim.phase == .lost {
            // Pumping again after a short pause restarts: instant retry without touching the screen.
            if let e = endedAt, clock - e > 0.9, sim.phase == .lost { restart() } else { return }
        }
        sim.flap(strength)
        handle(sim.drainEvents())
    }

    private func tick(_ dt: Double) {
        clock += dt
        if !paused {
            sim.step(dt: dt)
            handle(sim.drainEvents())
        }
        // Particles and shake keep animating while paused or finished.
        for i in particles.indices {
            particles[i].life -= dt
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            particles[i].vy += (particles[i].kind == .sparkle ? 0.2 : 0.9) * dt
            particles[i].angle += particles[i].spin * dt
        }
        particles.removeAll { $0.life <= 0 }
        shakeAmount = max(0, shakeAmount - dt * 40)
        shake = shakeAmount > 0.1
            ? CGSize(width: rng.range(-shakeAmount, shakeAmount), height: rng.range(-shakeAmount, shakeAmount)) : .zero
    }

    private func handle(_ events: [FlightSim.Event]) {
        for e in events {
            switch e {
            case .flap(let s):
                Sound.shared.play(.flap, strength: s)
                Haptics.flap(s)
                burst(.paper, count: 2 + Int(s * 4), speed: 0.25 + 0.3 * s)
            case .gate:
                Sound.shared.play(.gate, strength: 0.6)
                Haptics.gate()
            case .star:
                Sound.shared.play(.star)
                Haptics.star()
                burst(.sparkle, count: 12, speed: 0.5)
            case .hit, .floor:
                Sound.shared.play(.hit)
                Haptics.hit()
                shakeAmount = 14
                burst(.feather, count: 8, speed: 0.6)
            case .won:
                Sound.shared.play(.win)
                Haptics.star()
                burst(.sparkle, count: 24, speed: 0.8)
                finish()
            case .lost:
                Sound.shared.play(.lose)
                Haptics.lose()
                finish()
            }
        }
    }

    private func finish() {
        endedAt = clock
        newBest = onFinish?(sim) ?? false
    }

    private func burst(_ kind: Particle.Kind, count: Int, speed: Double) {
        for _ in 0..<count {
            let a = rng.range(0, 2 * .pi)
            let v = speed * rng.range(0.4, 1)
            particles.append(Particle(x: sim.x - 0.02, y: sim.y + 0.01, vx: cos(a) * v - 0.1, vy: sin(a) * v,
                                      life: rng.range(0.4, 0.9), maxLife: 0.9, spin: rng.range(-8, 8), angle: a,
                                      size: kind == .sparkle ? 0.012 : 0.010, kind: kind, hue: Int(rng.range(0, 4))))
        }
    }

    /// Screenshot tour: fly a few seconds with a simple pilot, then hold the picture mid-flap.
    func preset(seconds: Double, flap: Double) {
        sim = FlightSim(spec: request.spec)
        sim.start()
        let dt = 1.0 / 60
        var last = -1.0
        for _ in 0..<Int(seconds / dt) where sim.phase == .flying {
            let next = sim.obstacles.first { $0.x + $0.width / 2 > sim.x - FlightSim.radius }
            let target = next.map { $0.center(at: sim.t + max(0, $0.x - sim.x) / request.spec.speed) } ?? 0.5
            if sim.y > target + 0.02 && sim.vy > -0.15 && sim.t - last > 0.12 {
                sim.flap(min(1, 0.15 + (sim.y - target) * 2.5)); last = sim.t
            }
            sim.step(dt: dt)
        }
        sim.flap(flap)
        for _ in 0..<5 { sim.step(dt: dt) }
        _ = sim.drainEvents()
        burst(.paper, count: 6, speed: 0.5)
        paused = true
    }

    func presetWon() {
        preset(seconds: 2, flap: 0.6)
        while sim.phase == .flying { sim.step(dt: 1.0 / 60); if sim.y > 0.7 { sim.flap(0.7) } }
        for i in sim.stars.indices { sim.stars[i].taken = true }
        sim.phase = .won
        _ = sim.drainEvents()
        endedAt = clock
        newBest = true
        paused = false
    }
}

struct PlayView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var hinge: HingeModel
    @StateObject private var model: GameModel
    @State private var tutorial = false

    init(request: PlayRequest) {
        _model = StateObject(wrappedValue: GameModel(request: request))
    }

    private var spec: LevelSpec { model.request.spec }

    var body: some View {
        GeometryReader { g in
            ZStack {
                Canvas { ctx, size in
                    Renderer.draw(&ctx, size: size, frame: .init(sim: model.sim, particles: model.particles,
                                                                 shake: model.shake, clock: model.clock))
                }
                .contentShape(Rectangle())
                .onTapGesture { model.flap(0.6) }
                .accessibilityElement()
                .accessibilityLabel(Text("Flight"))
                .accessibilityHint((hinge.hasHinge ? Text("Pump the hinge or tap to flap") : Text("Tap to flap")))
                .accessibilityAddTraits(.allowsDirectInteraction)

                hud(portrait: g.size.height > g.size.width)
                overlay
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .modifier(KeepAwake())
        .modifier(HingeReader(model: hinge))
        .onAppear {
            hinge.onFlap = { [weak m = model] s in m?.flap(s) }
            let request = model.request
            model.onFinish = { [weak a = app] sim in a?.finished(sim, request: request) ?? false }
            tutorial = !app.progress.seenTutorial && !ShotsTour.active
            if ShotsTour.active { applyShotPreset() }
            Orientation.landscape(true, hasHinge: hinge.hasHinge)
            model.start()
        }
        .onDisappear {
            hinge.onFlap = nil
            model.stop()
            Orientation.landscape(false, hasHinge: hinge.hasHinge)
        }
    }

    private func applyShotPreset() {
        switch app.shotPreset {
        case .flying(let seconds, let flap): model.preset(seconds: seconds, flap: flap)
        case .won: model.presetWon()
        case .none: break
        }
    }

    // MARK: HUD

    private func hud(portrait: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                RoundButton(symbol: "pause.fill", label: "Pause") { model.paused = true }
                    .opacity(model.sim.phase == .flying ? 1 : 0)
                Text(title).font(.headline.weight(.heavy)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                Spacer()
                if spec.endless {
                    Text("\(model.sim.score)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white).shadow(color: .black.opacity(0.3), radius: 3)
                } else {
                    ProgressStrip(progress: model.sim.progress, stars: model.sim.stars.map { $0.x / spec.length },
                                  taken: model.sim.stars.map(\.taken))
                        .frame(maxWidth: 360)
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<FlightSim.feathersPerRun, id: \.self) { i in
                        Image(systemName: "leaf.fill")
                            .rotationEffect(.degrees(-45))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(i < model.sim.feathers ? Color.white : Color.white.opacity(0.25))
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("\(model.sim.feathers) feathers left"))
            }
            .padding(.horizontal, 22).padding(.top, 18)
            Spacer()
            HStack(alignment: .bottom) {
                if hinge.hasHinge && hinge.status != .closed {
                    TimelineView(.animation) { tl in
                        let since = tl.date.timeIntervalSinceNow + CACurrentMediaTime() - (hinge.lastFlap?.at ?? -9)
                        HingeGauge(angle: hinge.angle, flap: (hinge.lastFlap?.strength ?? 0) * max(0, 1 - since / 0.6))
                    }
                    .frame(width: 96, height: 56)
                }
                Spacer()
                if portrait && model.sim.phase == .ready {
                    Label("Best played sideways", systemImage: "rotate.right")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 16)
        }
    }

    private var title: String {
        if let _ = model.request.dailyKey { return String(localized: "Daily") }
        if spec.endless { return String(localized: "Endless") }
        return spec.number
    }

    // MARK: Overlays

    @ViewBuilder private var overlay: some View {
        if tutorial && model.sim.phase == .ready {
            TutorialCard(hasHinge: hinge.hasHinge) {
                tutorial = false
                app.markTutorialSeen()
            }
        } else if model.paused && model.sim.phase == .flying && !ShotsTour.active {
            Card {
                Text("Paused").font(.system(size: 34, weight: .heavy, design: .rounded))
                HStack(spacing: 12) {
                    Button("Resume") { model.paused = false }.buttonStyle(PrimaryButtonStyle())
                    Button("Restart") { model.restart() }.buttonStyle(SecondaryButtonStyle())
                    Button("Menu") { app.closeGame() }.buttonStyle(SecondaryButtonStyle())
                }
            }
        } else if model.sim.phase == .ready && !tutorial {
            (hinge.hasHinge ? Text("Pump the hinge to fly") : Text("Tap to fly"))
                .font(.title2.weight(.heavy)).foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(.black.opacity(0.3), in: Capsule())
                .allowsHitTesting(false)
        } else if model.sim.phase == .won {
            Card {
                (model.request.spec.endless ? Text("Run over") : Text("Level complete!")).font(.system(size: 34, weight: .heavy, design: .rounded))
                StarRow(count: model.sim.starsTaken, size: 34)
                if model.newBest { Text("New best!").font(.headline).foregroundStyle(Palette.sun) }
                HStack(spacing: 12) {
                    if let next = app.nextLevel(after: spec) {
                        Button("Next level") { app.play(next) }.buttonStyle(PrimaryButtonStyle())
                    }
                    Button("Retry") { model.restart() }.buttonStyle(SecondaryButtonStyle())
                    Button("Menu") { app.closeGame() }.buttonStyle(SecondaryButtonStyle())
                }
            }
        } else if model.sim.phase == .lost {
            Card {
                if spec.endless {
                    Text("\(model.sim.score)").font(.system(size: 56, weight: .heavy, design: .rounded).monospacedDigit())
                    (model.newBest ? Text("New best!") : Text("Best \(app.best(for: model.request))"))
                        .font(.headline).foregroundStyle(model.newBest ? Palette.sun : .white.opacity(0.8))
                } else {
                    Text("Out of feathers").font(.system(size: 32, weight: .heavy, design: .rounded))
                    Text("\(Int(model.sim.progress * 100))% of the way").font(.headline).foregroundStyle(.white.opacity(0.8))
                }
                HStack(spacing: 12) {
                    Button("Retry") { model.restart() }.buttonStyle(PrimaryButtonStyle())
                    Button("Menu") { app.closeGame() }.buttonStyle(SecondaryButtonStyle())
                }
                if hinge.hasHinge {
                    Text("Or pump the hinge to fly again").font(.footnote).foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

/// Course progress with the stars marked; collected stars turn gold.
struct ProgressStrip: View {
    var progress: Double
    var stars: [Double]
    var taken: [Bool]
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.25))
                Capsule().fill(.white.opacity(0.9)).frame(width: max(10, g.size.width * progress))
                ForEach(stars.indices, id: \.self) { i in
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(taken[i] ? Palette.sun : .white.opacity(0.5))
                        .shadow(color: .black.opacity(0.3), radius: 1)
                        .position(x: g.size.width * stars[i], y: g.size.height / 2)
                }
            }
        }
        .frame(height: 12)
        .accessibilityElement()
        .accessibilityLabel(Text("Progress \(Int(progress * 100)) percent"))
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 14) { content }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30).padding(.vertical, 24)
            .background(.ultraThinMaterial.opacity(0.95), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .environment(\.colorScheme, .dark)
            .padding(20)
    }
}

/// First-run "pump to flap" lesson: an animated hinge pumping next to the explanation.
struct TutorialCard: View {
    var hasHinge: Bool
    var done: () -> Void
    var body: some View {
        Card {
            (hasHinge ? Text("Pump to flap") : Text("Tap to flap")).font(.system(size: 32, weight: .heavy, design: .rounded))
            if hasHinge {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let a = 125 + 35 * cos(t * 2 * .pi * 0.9)
                    HingeGauge(angle: a, flap: max(0, sin(t * 2 * .pi * 0.9)))
                }
                .frame(width: 150, height: 86)
                Text("Hold the phone sideways, half open. Close it a little and open it again: every pump is a wing flap.")
                Text("Quick, deep pumps flap hard. Small pumps make small hops, perfect for tunnels.")
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("Tap anywhere to flap. Kip sinks between flaps, so find a rhythm.")
                Text("On iPhone Duo you pump the hinge instead.").foregroundStyle(.white.opacity(0.8))
            }
            Button("Got it") { done() }.buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: 560)
    }
}
