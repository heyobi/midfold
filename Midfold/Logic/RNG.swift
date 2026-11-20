import Foundation

/// Small deterministic generator (SplitMix64) so rounds can be replayed in tests and screenshots.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * unit() }
    mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(n, 1))) }
}

/// Maps a hinge angle (0° closed … 180° flat) to the playable 0…1 range used by the fold games.
enum HingeScale {
    static let low = 40.0   // below this the inner display is hard to see
    static let high = 170.0
    static func unit(_ angle: Double) -> Double {
        min(1, max(0, (angle - low) / (high - low)))
    }
    static func angle(_ unit: Double) -> Double { low + (high - low) * min(1, max(0, unit)) }
}
