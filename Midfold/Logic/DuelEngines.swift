import Foundation

/// Player 0 sits at the left (or bottom) half, player 1 at the right (or top) half.
typealias Player = Int

extension Player {
    var other: Player { self == 0 ? 1 : 0 }
}

// MARK: - Quick Draw

/// Wait for the signal, then tap first. Tapping before the signal hands the round to the other player.
/// First to `winsNeeded` round wins takes the match.
struct QuickDrawEngine {
    enum Phase: Equatable {
        case idle
        case waiting(goAt: Double)
        case go(since: Double)
        case roundOver(winner: Player, early: Bool, reactionMs: Int?)
        case matchOver(winner: Player)
    }

    var winsNeeded = 3
    var phase: Phase = .idle
    var score = [0, 0]
    private var rng: SeededRNG

    init(seed: UInt64 = 3, winsNeeded: Int = 3) {
        rng = SeededRNG(seed: seed)
        self.winsNeeded = winsNeeded
    }

    mutating func startRound(now: Double) {
        if case .matchOver = phase { score = [0, 0] }
        phase = .waiting(goAt: now + rng.range(1.6, 4.2))
    }

    mutating func tick(now: Double) {
        if case .waiting(let goAt) = phase, now >= goAt { phase = .go(since: goAt) }
    }

    /// Returns the new phase if the tap changed anything.
    @discardableResult
    mutating func tap(_ p: Player, now: Double) -> Phase? {
        tick(now: now)
        switch phase {
        case .waiting:
            award(p.other, early: true, ms: nil)
        case .go(let since):
            award(p, early: false, ms: Int(((now - since) * 1000).rounded()))
        default:
            return nil
        }
        return phase
    }

    private mutating func award(_ w: Player, early: Bool, ms: Int?) {
        score[w] += 1
        phase = score[w] >= winsNeeded ? .matchOver(winner: w) : .roundOver(winner: w, early: early, reactionMs: ms)
    }
}

// MARK: - Tug Line

/// Both players tap as fast as they can; every tap pulls the knot one step toward the tapper's side.
/// The knot starts on the fold. Pull it all the way to your edge to win the round; first to `winsNeeded`.
struct TugEngine {
    static let step = 0.045
    var winsNeeded = 2
    /// -1 … 1. Negative is player 0's side, positive player 1's side.
    var knot = 0.0
    var score = [0, 0]
    var roundWinner: Player?
    var matchWinner: Player?
    var taps = [0, 0]

    init(winsNeeded: Int = 2) { self.winsNeeded = winsNeeded }

    var playing: Bool { roundWinner == nil }

    mutating func tap(_ p: Player) {
        guard roundWinner == nil else { return }
        taps[p] += 1
        knot += p == 0 ? -Self.step : Self.step
        knot = min(1, max(-1, knot))
        if abs(knot) >= 1 - 1e-9 {
            let w: Player = knot < 0 ? 0 : 1
            roundWinner = w
            score[w] += 1
            if score[w] >= winsNeeded { matchWinner = w }
        }
    }

    mutating func nextRound() {
        if matchWinner != nil { score = [0, 0]; matchWinner = nil }
        knot = 0; roundWinner = nil; taps = [0, 0]
    }
}

// MARK: - Odd Spot

/// Each player gets their own 4×4 grid of near-identical symbols with one odd one out, in a different place on
/// each side so nobody can copy. First to find it scores; a wrong tap freezes you for a second.
struct OddSpotEngine {
    struct Round: Equatable {
        var pair: Int          // index into `pairs`
        var odd: [Int]         // odd cell per player
    }

    static let columns = 4
    static let cells = columns * columns
    static let penalty = 1.0
    /// SF Symbol pairs: (common, odd). Close enough to need a second look.
    static let pairs: [(String, String)] = [
        ("moon.fill", "moon"),
        ("star.fill", "star.leadinghalf.filled"),
        ("circle.fill", "circle.bottomhalf.filled"),
        ("triangle.fill", "triangle"),
        ("heart.fill", "suit.heart.fill"),
        ("square.fill", "app.fill"),
        ("cloud.fill", "cloud"),
        ("leaf.fill", "leaf"),
        ("bolt.fill", "bolt"),
        ("drop.fill", "drop"),
        ("flame.fill", "flame"),
        ("diamond.fill", "suit.diamond.fill"),
        ("hexagon.fill", "seal.fill"),
        ("bell.fill", "bell"),
    ]

    var winsNeeded = 5
    var score = [0, 0]
    var round: Round
    var lockedUntil = [0.0, 0.0]
    var lastWinner: Player?
    var matchWinner: Player?
    private var rng: SeededRNG

    init(seed: UInt64 = 5, winsNeeded: Int = 5) {
        rng = SeededRNG(seed: seed)
        self.winsNeeded = winsNeeded
        round = Round(pair: 0, odd: [0, 0])
        round = makeRound(previous: nil)
    }

    private mutating func makeRound(previous: Round?) -> Round {
        var pair = rng.int(Self.pairs.count)
        if let p = previous, pair == p.pair { pair = (pair + 1) % Self.pairs.count }
        let a = rng.int(Self.cells)
        var b = rng.int(Self.cells)
        if b == a { b = (b + 5) % Self.cells }
        return Round(pair: pair, odd: [a, b])
    }

    func symbol(for p: Player, cell: Int) -> String {
        let pair = Self.pairs[round.pair]
        return cell == round.odd[p] ? pair.1 : pair.0
    }

    func isLocked(_ p: Player, now: Double) -> Bool { now < lockedUntil[p] }

    enum TapResult: Equatable { case ignored, wrong, found, matchWon }

    @discardableResult
    mutating func tap(_ p: Player, cell: Int, now: Double) -> TapResult {
        guard matchWinner == nil, lastWinner == nil, !isLocked(p, now: now) else { return .ignored }
        if cell == round.odd[p] {
            score[p] += 1
            lastWinner = p
            if score[p] >= winsNeeded { matchWinner = p; return .matchWon }
            return .found
        }
        lockedUntil[p] = now + Self.penalty
        return .wrong
    }

    mutating func nextRound() {
        if matchWinner != nil { score = [0, 0]; matchWinner = nil }
        lastWinner = nil
        lockedUntil = [0, 0]
        round = makeRound(previous: round)
    }
}
