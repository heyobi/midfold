import Foundation

/// Fold Flight: a paper glider flies through gaps in folded paper walls. The hinge angle is the altitude:
/// open the phone wider to climb, close it to dive. Coordinates are in screen units: y 0 = top, 1 = bottom,
/// x 0…`aspect` across the screen (aspect = width / height).
struct FlightEngine {
    enum Phase: Equatable { case ready, flying, crashed }

    struct Wall: Equatable {
        var x: Double
        var gapCenter: Double
        var gapHeight: Double
        var passed = false
    }

    static let gliderX = 0.30
    static let gliderRadius = 0.035
    static let wallWidth = 0.09
    static let spacing = 0.62

    var aspect: Double
    var phase: Phase = .ready
    var y = 0.5
    var walls: [Wall] = []
    var score = 0
    var speed = 0.28      // screen heights per second
    var elapsed = 0.0
    private var rng: SeededRNG
    private var nextX: Double

    init(aspect: Double = 1.6, seed: UInt64 = 7) {
        self.aspect = max(0.4, aspect)
        rng = SeededRNG(seed: seed)
        nextX = self.aspect + 0.15
    }

    /// Altitude the glider steers toward for a hinge angle: open wide → top of the screen.
    static func targetY(angle: Double) -> Double {
        0.92 - 0.84 * HingeScale.unit(angle)
    }

    var gapHeight: Double { max(0.24, 0.40 - Double(score) * 0.008) }

    mutating func start() {
        phase = .flying
        score = 0
        elapsed = 0
        speed = 0.28
        walls = []
        nextX = aspect + 0.15
    }

    /// Only steers (screenshots: the walls stand still, the glider still follows the hinge).
    mutating func steer(dt: Double, angle: Double) {
        y += (Self.targetY(angle: angle) - y) * min(1, dt * 6)
    }

    mutating func step(dt: Double, angle: Double) {
        let target = Self.targetY(angle: angle)
        // Ease toward the target so the hinge feels like steering, not teleporting.
        y += (target - y) * min(1, dt * 6)
        guard phase == .flying else { return }
        elapsed += dt
        speed = min(0.55, 0.28 + elapsed * 0.006)
        let dx = speed * dt
        nextX -= dx
        for i in walls.indices { walls[i].x -= dx }
        walls.removeAll { $0.x < -Self.wallWidth }
        while nextX < aspect + 0.2 {
            let h = gapHeight
            let lastCenter = walls.last?.gapCenter ?? 0.5
            // Keep consecutive gaps reachable: at most 0.35 screen heights apart.
            let lo = max(0.12 + h / 2, lastCenter - 0.35)
            let hi = min(0.88 - h / 2, lastCenter + 0.35)
            walls.append(Wall(x: nextX, gapCenter: rng.range(lo, max(lo, hi)), gapHeight: h))
            nextX += Self.spacing
        }
        for i in walls.indices {
            let w = walls[i]
            if abs(w.x - Self.gliderX) < Self.wallWidth / 2 + Self.gliderRadius * 0.6 {
                let top = w.gapCenter - w.gapHeight / 2
                let bottom = w.gapCenter + w.gapHeight / 2
                if y - Self.gliderRadius < top || y + Self.gliderRadius > bottom {
                    phase = .crashed
                    return
                }
            }
            if !w.passed && w.x + Self.wallWidth / 2 < Self.gliderX - Self.gliderRadius {
                walls[i].passed = true
                score += 1
            }
        }
    }
}
