import Foundation

/// The flight itself. Units: y in screen heights (0 = top, 1 = bottom), x in screen heights along the course.
/// Kip (the paper bird) sinks under gravity; every flap (a hinge pump, or a tap off-Duo) kicks it upward with a
/// strength 0…1. Obstacles: paper gates, moving gates, wind zones and narrow tunnels. Three feathers per run.
struct FlightSim {
    enum Phase: Equatable { case ready, flying, won, lost }

    enum Kind: Equatable {
        case gate
        case mover(amplitude: Double, rate: Double, phase: Double)
        case tunnel             // one slice of a tunnel; slices sit side by side
    }

    struct Obstacle: Equatable {
        var x: Double
        var width: Double
        var center: Double
        var gap: Double
        var kind: Kind
        var passed = false

        func center(at t: Double) -> Double {
            if case .mover(let a, let r, let p) = kind { return center + a * sin(r * t + p) }
            return center
        }
    }

    struct Wind: Equatable {
        var x: Double
        var width: Double
        var force: Double       // vertical acceleration; negative lifts
    }

    struct Star: Equatable {
        var x: Double
        var y: Double
        var taken = false
    }

    // Tuning
    static let birdX = 0.32           // where Kip sits on screen
    static let radius = 0.034
    static let gravity = 1.45
    static let maxFall = 1.0
    static let feathersPerRun = 3
    static let invulnerable = 1.2

    static func flapVelocity(_ strength: Double) -> Double { -(0.30 + 0.58 * min(1, max(0, strength))) }

    let spec: LevelSpec
    var phase: Phase = .ready
    var x = 0.0                 // distance flown
    var y = 0.45
    var vy = 0.0
    var t = 0.0
    var feathers = feathersPerRun
    var hurtUntil = -1.0
    var obstacles: [Obstacle] = []
    var winds: [Wind] = []
    var stars: [Star] = []
    var gatesPassed = 0
    var lastFlap: (t: Double, strength: Double)?
    /// Events since the last `drainEvents()`, for sound, haptics and particles.
    var events: [Event] = []

    enum Event: Equatable { case flap(Double), gate, star, hit, floor, won, lost }

    private var rng: SeededRNG
    private var cursor: Double
    private var tunnelsLeft: Int

    init(spec: LevelSpec) {
        self.spec = spec
        rng = SeededRNG(seed: spec.seed)
        cursor = 1.6
        tunnelsLeft = spec.tunnels
        if spec.endless {
            generate(until: 4)
        } else {
            generate(until: spec.length - 0.6)
            placeStars()
        }
    }

    var starsTaken: Int { stars.filter(\.taken).count }
    var progress: Double { spec.endless ? 0 : min(1, x / spec.length) }
    var score: Int { gatesPassed + starsTaken * 3 }
    var isHurt: Bool { t < hurtUntil }

    /// Difficulty in endless mode grows with distance.
    private var endlessLevel: Double { min(1, x / 120) }
    private var speed: Double { spec.endless ? spec.speed + 0.14 * endlessLevel : spec.speed }
    private var gap: Double { spec.endless ? max(0.25, spec.gap - 0.12 * endlessLevel) : spec.gap }

    // MARK: Course generation

    private mutating func generate(until end: Double) {
        while cursor < end {
            let last = obstacles.last?.center ?? 0.5
            if tunnelsLeft > 0 && cursor > 4 && rng.chance(0.25) {
                tunnelsLeft -= 1
                addTunnel(from: last)
                continue
            }
            if rng.chance(spec.windChance) {
                let up = rng.chance(0.6)
                winds.append(Wind(x: cursor - 0.15, width: spec.spacing * 0.8, force: up ? -1.1 : 0.7))
            }
            let g = gap
            let maxStep = 0.30 * spec.spacing / 0.8
            let lo = max(0.10 + g / 2, last - maxStep), hi = min(0.90 - g / 2, last + maxStep)
            let c = rng.range(lo, max(lo, hi))
            var kind = Kind.gate
            if rng.chance(spec.moverChance + (spec.endless ? 0.3 * endlessLevel : 0)) {
                let room = min(c - (0.10 + g / 2), (0.90 - g / 2) - c)
                let amp = max(0.03, min(0.12, room))
                kind = .mover(amplitude: amp, rate: rng.range(1.2, 2.2), phase: rng.range(0, 6.28))
            }
            obstacles.append(Obstacle(x: cursor, width: 0.10, center: c, gap: g, kind: kind))
            cursor += spec.spacing * rng.range(0.9, 1.15)
        }
    }

    private mutating func addTunnel(from start: Double) {
        let slices = 14
        let w = 0.09
        let g = max(0.26, gap - 0.06)
        var c = min(0.85 - g / 2, max(0.15 + g / 2, start))
        let drift = rng.range(-0.012, 0.012)
        for _ in 0..<slices {
            obstacles.append(Obstacle(x: cursor, width: w, center: c, gap: g, kind: .tunnel))
            c = min(0.86 - g / 2, max(0.14 + g / 2, c + drift + rng.range(-0.008, 0.008)))
            cursor += w
        }
        cursor += spec.spacing
    }

    /// Three stars per level, in the middle of the gap of the gates nearest 25 %, 55 % and 85 % of the course.
    private mutating func placeStars() {
        for f in [0.25, 0.55, 0.85] {
            let target = spec.length * f
            guard let o = obstacles.filter({ $0.kind != .tunnel }).min(by: { abs($0.x - target) < abs($1.x - target) }) else { continue }
            stars.append(Star(x: o.x, y: o.center))
        }
    }

    // MARK: Play

    mutating func start() {
        guard phase == .ready else { return }
        phase = .flying
        vy = Self.flapVelocity(0.5)
    }

    mutating func flap(_ strength: Double) {
        if phase == .ready { start() }
        guard phase == .flying else { return }
        let v = Self.flapVelocity(strength)
        // A flap never slows a climb that is already faster, and cancels most of a fall.
        vy = min(vy * 0.25, v)
        lastFlap = (t, strength)
        events.append(.flap(strength))
    }

    mutating func drainEvents() -> [Event] {
        defer { events.removeAll() }
        return events
    }

    mutating func step(dt: Double) {
        guard phase == .flying else { return }
        t += dt
        x += speed * dt
        var accel = Self.gravity
        for w in winds where x >= w.x && x <= w.x + w.width { accel += w.force }
        vy = min(Self.maxFall, vy + accel * dt)
        y += vy * dt
        if y < Self.radius { y = Self.radius; vy = max(0, vy) }
        if y > 1 - Self.radius {
            y = 1 - Self.radius
            vy = Self.flapVelocity(0.6)
            hurt(event: .floor)
            if phase != .flying { return }
        }
        if spec.endless {
            generate(until: x + 4)
            obstacles.removeAll { $0.x < x - 2 }
            winds.removeAll { $0.x + $0.width < x - 2 }
        }
        for i in obstacles.indices {
            let o = obstacles[i]
            if abs(o.x - x) < o.width / 2 + Self.radius * 0.7 {
                let c = o.center(at: t)
                if y - Self.radius < c - o.gap / 2 || y + Self.radius > c + o.gap / 2 {
                    hurt(event: .hit)
                    if phase != .flying { return }
                }
            }
            if !o.passed && o.x + o.width / 2 < x - Self.radius {
                obstacles[i].passed = true
                if o.kind != .tunnel || i + 1 == obstacles.count || obstacles[i + 1].kind != .tunnel {
                    gatesPassed += 1
                    events.append(.gate)
                }
            }
        }
        for i in stars.indices where !stars[i].taken {
            let dx = stars[i].x - x, dy = stars[i].y - y
            if dx * dx + dy * dy < 0.07 * 0.07 {
                stars[i].taken = true
                events.append(.star)
            }
        }
        if !spec.endless && x >= spec.length {
            phase = .won
            events.append(.won)
        }
    }

    private mutating func hurt(event: Event) {
        guard !isHurt else { return }
        feathers -= 1
        hurtUntil = t + Self.invulnerable
        events.append(event)
        if feathers <= 0 {
            phase = .lost
            events.append(.lost)
        }
    }
}
