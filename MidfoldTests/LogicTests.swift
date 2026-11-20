import XCTest
@testable import Midfold

final class PumpDetectorTests: XCTestCase {
    /// Samples a hinge angle function at 60 Hz and returns the flaps it produced.
    private func run(_ seconds: Double, rate: Double = 60, sensitivity: Double = 1,
                     _ angle: (Double) -> Double) -> [Double] {
        var d = PumpDetector()
        d.sensitivity = sensitivity
        var out: [Double] = []
        let n = Int(seconds * rate)
        for i in 0...n {
            let t = Double(i) / rate
            if let s = d.feed(angle: angle(t), at: t) { out.append(s) }
        }
        return out
    }

    func testFastDeepPumpsAreStrongFlaps() {
        // 2 pumps per second, 80° deep, for 3 s.
        let flaps = run(3) { 120 + 40 * cos(2 * .pi * 2 * $0) }
        XCTAssertEqual(flaps.count, 6, accuracy: 1)
        for f in flaps { XCTAssertGreaterThan(f, 0.85) }
    }

    func testSlowShallowPumpsAreSmallHops() {
        let flaps = run(4) { 120 + 6 * cos(2 * .pi * 0.5 * $0) }
        XCTAssertEqual(flaps.count, 2, accuracy: 1)
        for f in flaps { XCTAssertLessThan(f, 0.3) }
    }

    func testStrengthGrowsWithDepthAndSpeed() {
        let shallow = run(2) { 120 + 8 * cos(2 * .pi * 1.5 * $0) }
        let deep = run(2) { 120 + 30 * cos(2 * .pi * 1.5 * $0) }
        let fast = run(2) { 120 + 8 * cos(2 * .pi * 3 * $0) }
        XCTAssertFalse(shallow.isEmpty); XCTAssertFalse(deep.isEmpty); XCTAssertFalse(fast.isEmpty)
        XCTAssertGreaterThan(deep.max()!, shallow.max()!)
        XCTAssertGreaterThan(fast.max()!, shallow.max()!)
    }

    func testJitterDoesNotFlap() {
        var rng = SeededRNG(seed: 4)
        let noise = (0...300).map { _ in rng.range(-2, 2) }
        let flaps = run(5) { noise[Int($0 * 60) % noise.count] + 120 }
        XCTAssertTrue(flaps.isEmpty)
    }

    func testHoldingStillAndOpeningOnlyDoNotFlap() {
        XCTAssertTrue(run(2) { _ in 110 }.isEmpty)
        XCTAssertTrue(run(2) { 60 + 50 * $0 }.isEmpty, "only opening is not a pump")
    }

    func testSensitivityScalesStrength() {
        let normal = run(2) { 120 + 15 * cos(2 * .pi * 1 * $0) }
        let high = run(2, sensitivity: 1.5) { 120 + 15 * cos(2 * .pi * 1 * $0) }
        XCTAssertGreaterThan(high.first!, normal.first!)
    }

    func testIrregularSampleTimesStillWork() {
        // Hinge events do not come at a fixed rate: 20–60 Hz with gaps.
        var d = PumpDetector()
        var rng = SeededRNG(seed: 9)
        var t = 0.0, flaps = 0
        while t < 3 {
            t += rng.range(1.0 / 60, 1.0 / 20)
            if d.feed(angle: 120 + 35 * cos(2 * .pi * 1.5 * t), at: t) != nil { flaps += 1 }
        }
        XCTAssertEqual(flaps, 4, accuracy: 1)
    }
}

final class FlightTests: XCTestCase {
    /// A simple pilot: flap when below the middle of the next gap.
    private func fly(_ spec: LevelSpec, seconds: Double = 200) -> FlightSim {
        var sim = FlightSim(spec: spec)
        sim.start()
        var lastFlap = -1.0
        let dt = 1.0 / 60
        for _ in 0..<Int(seconds / dt) {
            guard sim.phase == .flying else { break }
            let next = sim.obstacles.first { $0.x + $0.width / 2 > sim.x - FlightSim.radius }
            let target = next.map { $0.center(at: sim.t + max(0, $0.x - sim.x) / spec.speed) } ?? 0.5
            if sim.y > target + 0.02 && sim.vy > -0.15 && sim.t - lastFlap > 0.12 {
                sim.flap(min(1, 0.15 + (sim.y - target) * 2.5))
                lastFlap = sim.t
            }
            sim.step(dt: dt)
        }
        return sim
    }

    func testGravityPullsDownAndFlapLifts() {
        var sim = FlightSim(spec: .level(.meadow, 0))
        sim.start()
        for _ in 0..<60 { sim.step(dt: 1.0 / 60) }
        XCTAssertGreaterThan(sim.vy, 0)
        let y = sim.y
        sim.flap(1)
        for _ in 0..<10 { sim.step(dt: 1.0 / 60) }
        XCTAssertLessThan(sim.y, y)
    }

    func testStrongFlapClimbsHigherThanWeak() {
        func climb(_ s: Double) -> Double {
            var sim = FlightSim(spec: .level(.meadow, 0))
            sim.start(); sim.y = 0.6; sim.vy = 0
            sim.flap(s)
            var top = sim.y
            for _ in 0..<60 { sim.step(dt: 1.0 / 60); top = min(top, sim.y) }
            return 0.6 - top
        }
        XCTAssertGreaterThan(climb(1), climb(0.2) * 2)
    }

    func testEveryMeadowLevelIsBeatable() {
        for i in 0..<World.levelsPerWorld {
            let sim = fly(.level(.meadow, i))
            XCTAssertEqual(sim.phase, .won, "level 1-\(i + 1)")
            XCTAssertGreaterThan(sim.gatesPassed, 5)
        }
    }

    func testFirstLevelOfEachWorldIsBeatable() {
        for w in World.allCases {
            XCTAssertEqual(fly(.level(w, 0)).phase, .won, "world \(w)")
        }
    }

    func testStarsSitInGapsAndCanBeCollected() {
        let sim = fly(.level(.meadow, 0))
        XCTAssertEqual(sim.stars.count, 3)
        XCTAssertGreaterThanOrEqual(sim.starsTaken, 2)
    }

    func testNoFlappingLosesAllFeathers() {
        var sim = FlightSim(spec: .level(.meadow, 0))
        sim.start()
        for _ in 0..<(60 * 60) where sim.phase == .flying { sim.step(dt: 1.0 / 60) }
        XCTAssertEqual(sim.phase, .lost)
        XCTAssertEqual(sim.feathers, 0)
        let events = sim.drainEvents()
        XCTAssertTrue(events.contains(.lost))
    }

    func testHitsAreForgivenForAMoment() {
        var sim = FlightSim(spec: .level(.meadow, 0))
        sim.start()
        sim.y = 1
        sim.step(dt: 1.0 / 60)
        XCTAssertEqual(sim.feathers, FlightSim.feathersPerRun - 1)
        sim.y = 1
        sim.step(dt: 1.0 / 60)
        XCTAssertEqual(sim.feathers, FlightSim.feathersPerRun - 1, "invulnerable right after a hit")
    }

    func testCoursesStayInsideTheScreenAndReachable() {
        for spec in LevelSpec.all + [LevelSpec.endless(seed: 3), LevelSpec.daily(year: 2026, month: 11, day: 20)] {
            let sim = FlightSim(spec: spec)
            var last: Double?
            for o in sim.obstacles {
                XCTAssertGreaterThanOrEqual(o.center - o.gap / 2, 0.05, spec.id)
                XCTAssertLessThanOrEqual(o.center + o.gap / 2, 0.95, spec.id)
                if case .mover(let a, _, _) = o.kind {
                    XCTAssertGreaterThanOrEqual(o.center - a - o.gap / 2, 0.0, spec.id)
                    XCTAssertLessThanOrEqual(o.center + a + o.gap / 2, 1.0, spec.id)
                }
                if let l = last { XCTAssertLessThanOrEqual(abs(o.center - l), 0.36, spec.id) }
                last = o.center
            }
        }
    }

    func testEndlessKeepsGoingAndGetsHarder() {
        var sim = fly(.endless(seed: 1), seconds: 90)
        XCTAssertGreaterThan(sim.gatesPassed, 15)
        XCTAssertLessThan(sim.obstacles.count, 60, "old obstacles are dropped")
        _ = sim.drainEvents()
    }

    func testDailySeedIsStablePerDay() {
        XCTAssertEqual(LevelSpec.daily(year: 2026, month: 11, day: 20), LevelSpec.daily(year: 2026, month: 11, day: 20))
        XCTAssertNotEqual(LevelSpec.daily(year: 2026, month: 11, day: 20).seed, LevelSpec.daily(year: 2026, month: 11, day: 21).seed)
    }
}

final class ProgressTests: XCTestCase {
    func testLevelsOpenInOrderAndWorldsNeedTheUnlock() {
        var p = Progress()
        XCTAssertTrue(p.isOpen(.level(.meadow, 0), unlocked: false))
        XCTAssertFalse(p.isOpen(.level(.meadow, 1), unlocked: false))
        p.record(.level(.meadow, 0), stars: 2)
        XCTAssertTrue(p.isOpen(.level(.meadow, 1), unlocked: false))
        XCTAssertFalse(p.isOpen(.level(.cliffs, 0), unlocked: false))
        XCTAssertTrue(p.isOpen(.level(.cliffs, 0), unlocked: true))
    }

    func testBestStarsAndScoresAreKept() {
        var p = Progress()
        XCTAssertTrue(p.record(.level(.meadow, 0), stars: 1))
        XCTAssertTrue(p.record(.level(.meadow, 0), stars: 3))
        XCTAssertFalse(p.record(.level(.meadow, 0), stars: 2))
        XCTAssertEqual(p.stars(in: .meadow), 3)
        XCTAssertTrue(p.recordEndless(10, dailyKey: nil))
        XCTAssertFalse(p.recordEndless(5, dailyKey: nil))
        XCTAssertTrue(p.recordEndless(5, dailyKey: "2026-11-20"))
        XCTAssertEqual(p.bestEndless, 10)
        let data = try! JSONEncoder().encode(p)
        XCTAssertEqual(try! JSONDecoder().decode(Progress.self, from: data), p)
    }

    func testEighteenLevelsGetHarder() {
        XCTAssertEqual(LevelSpec.all.count, 18)
        for w in World.allCases {
            let a = LevelSpec.level(w, 0), b = LevelSpec.level(w, World.levelsPerWorld - 1)
            XCTAssertLessThan(b.gap, a.gap)
            XCTAssertGreaterThan(b.length, a.length)
        }
    }
}
