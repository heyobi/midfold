import Foundation

/// Angle Lock: a target angle appears on a dial; set the hinge to it and hold steady until it locks.
/// Eight targets, as fast as you can. Off-device the same dial is driven by tilt or a slider.
struct AngleLockEngine {
    enum Phase: Equatable { case ready, playing, finished }

    static let count = 8
    static let tolerance = 6.0
    static let holdTime = 0.8

    var phase: Phase = .ready
    var targets: [Double] = []
    var index = 0
    var hold = 0.0
    var elapsed = 0.0
    private let seed: UInt64

    init(seed: UInt64 = 11) {
        self.seed = seed
        targets = Self.makeTargets(seed: seed)
    }

    static func makeTargets(seed: UInt64) -> [Double] {
        var rng = SeededRNG(seed: seed)
        var out: [Double] = []
        var last = 110.0
        while out.count < count {
            let t = (rng.range(HingeScale.low + 10, HingeScale.high - 5) / 5).rounded() * 5
            if abs(t - last) >= 25 { out.append(t); last = t }
        }
        return out
    }

    var target: Double? { index < targets.count ? targets[index] : nil }
    var holdProgress: Double { min(1, hold / Self.holdTime) }

    func isOnTarget(_ angle: Double) -> Bool {
        guard let t = target else { return false }
        return abs(angle - t) <= Self.tolerance
    }

    mutating func start(seed newSeed: UInt64? = nil) {
        targets = Self.makeTargets(seed: newSeed ?? seed)
        index = 0; hold = 0; elapsed = 0
        phase = .playing
    }

    /// Returns true when a target locked during this step.
    @discardableResult
    mutating func step(dt: Double, angle: Double) -> Bool {
        guard phase == .playing else { return false }
        elapsed += dt
        if isOnTarget(angle) {
            hold += dt
        } else {
            hold = max(0, hold - dt * 2)
        }
        if hold >= Self.holdTime {
            index += 1
            hold = 0
            if index >= targets.count { phase = .finished }
            return true
        }
        return false
    }
}
