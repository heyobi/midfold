import Foundation

/// The three worlds. World 1 is free; the others (and Endless) come with the one-time unlock.
enum World: Int, CaseIterable, Codable, Identifiable {
    case meadow, cliffs, caves
    var id: Int { rawValue }
    static let levelsPerWorld = 6
}

/// Parameters of one level. Levels are generated from these numbers with a fixed seed, so each one is the same
/// every time you play it (and in the tests).
struct LevelSpec: Equatable, Identifiable {
    var world: World
    var index: Int              // 0-based inside the world
    var seed: UInt64
    var length: Double          // screen heights of flight; nil-like 0 for endless
    var speed: Double           // screen heights per second
    var gap: Double             // gap height of gates
    var spacing: Double         // distance between obstacles
    var moverChance: Double
    var windChance: Double
    var tunnels: Int
    var endless = false

    var id: String { endless ? "endless-\(seed)" : "\(world.rawValue)-\(index)" }
    var number: String { "\(world.rawValue + 1)-\(index + 1)" }

    static func level(_ world: World, _ index: Int) -> LevelSpec {
        let t = Double(index) / Double(World.levelsPerWorld - 1)      // 0 … 1 inside the world
        let w = Double(world.rawValue)
        return LevelSpec(
            world: world, index: index,
            seed: UInt64(1000 + world.rawValue * 100 + index),
            length: 14 + 3 * Double(index) + 4 * w,
            speed: 0.30 + 0.03 * t + 0.02 * w,
            gap: 0.40 - 0.06 * t - 0.03 * w,
            spacing: 0.80 - 0.10 * t,
            moverChance: world == .meadow ? (index >= 3 ? 0.25 : 0) : 0.30 + 0.1 * t,
            windChance: world == .meadow ? 0 : (world == .cliffs ? 0.35 + 0.15 * t : 0.2),
            tunnels: world == .caves ? 1 + index / 2 : (world == .cliffs && index >= 4 ? 1 : 0))
    }

    static func endless(seed: UInt64) -> LevelSpec {
        LevelSpec(world: .meadow, index: 0, seed: seed, length: 0, speed: 0.32, gap: 0.38, spacing: 0.78,
                  moverChance: 0.2, windChance: 0.15, tunnels: 0, endless: true)
    }

    /// The daily challenge: an endless run from a seed made of the date, the same for everybody that day.
    static func daily(year: Int, month: Int, day: Int) -> LevelSpec {
        endless(seed: UInt64(year * 10_000 + month * 100 + day))
    }

    static var all: [LevelSpec] {
        World.allCases.flatMap { w in (0..<World.levelsPerWorld).map { level(w, $0) } }
    }
}

/// Stars, bests and unlocks, saved as JSON in UserDefaults.
struct Progress: Codable, Equatable {
    var stars: [String: Int] = [:]          // level id → best stars (0…3); present = completed
    var bestEndless = 0
    var dailyBest: [String: Int] = [:]      // "yyyy-mm-dd" → best
    var seenTutorial = false

    func completed(_ l: LevelSpec) -> Bool { stars[l.id] != nil }

    /// A level is open when it is the first of its world or the previous one is completed, and its world is
    /// free or bought.
    func isOpen(_ l: LevelSpec, unlocked: Bool) -> Bool {
        guard l.world == .meadow || unlocked else { return false }
        if l.index == 0 { return true }
        return completed(.level(l.world, l.index - 1))
    }

    var totalStars: Int { stars.values.reduce(0, +) }

    func stars(in world: World) -> Int {
        (0..<World.levelsPerWorld).reduce(0) { $0 + (stars[LevelSpec.level(world, $1).id] ?? 0) }
    }

    /// Records a finished level. Returns true when it is a new best.
    @discardableResult
    mutating func record(_ l: LevelSpec, stars s: Int) -> Bool {
        let old = stars[l.id]
        if old == nil || s > old! { stars[l.id] = s; return true }
        return false
    }

    @discardableResult
    mutating func recordEndless(_ score: Int, dailyKey: String?) -> Bool {
        if let k = dailyKey {
            if score > (dailyBest[k] ?? -1) { dailyBest[k] = score; return true }
            return false
        }
        if score > bestEndless { bestEndless = score; return true }
        return false
    }
}
