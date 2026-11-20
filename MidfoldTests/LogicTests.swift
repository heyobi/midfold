import XCTest
@testable import Midfold

final class HingeAndFlightTests: XCTestCase {
    func testHingeScaleClampsAndMaps() {
        XCTAssertEqual(HingeScale.unit(0), 0)
        XCTAssertEqual(HingeScale.unit(180), 1)
        XCTAssertEqual(HingeScale.unit(HingeScale.low), 0)
        XCTAssertEqual(HingeScale.unit(105), 0.5, accuracy: 1e-9)
        XCTAssertEqual(HingeScale.angle(0.5), 105, accuracy: 1e-9)
    }

    func testOpeningWiderClimbs() {
        XCTAssertLessThan(FlightEngine.targetY(angle: 160), FlightEngine.targetY(angle: 60))
    }

    func testGliderEasesTowardHingeAltitude() {
        var e = FlightEngine(aspect: 1.5)
        for _ in 0..<120 { e.step(dt: 1.0 / 60, angle: 170) }
        XCTAssertEqual(e.y, FlightEngine.targetY(angle: 170), accuracy: 0.01)
        XCTAssertEqual(e.phase, .ready, "steering works before the flight starts, nothing moves")
        XCTAssertTrue(e.walls.isEmpty)
    }

    func testFollowingTheGapsScoresAndHittingAWallCrashes() {
        // Autopilot: set the hinge to the angle whose altitude is the next gap's centre.
        var e = FlightEngine(aspect: 1.5, seed: 42)
        e.start()
        for _ in 0..<(60 * 25) {
            let next = e.walls.first { $0.x + FlightEngine.wallWidth / 2 > FlightEngine.gliderX - 0.05 }
            let wantY = next?.gapCenter ?? 0.5
            let angle = HingeScale.angle((0.92 - wantY) / 0.84)
            e.step(dt: 1.0 / 60, angle: angle)
            if e.phase != .flying { break }
        }
        XCTAssertEqual(e.phase, .flying)
        XCTAssertGreaterThan(e.score, 5)

        // Closed shut (glider on the floor) it must hit a wall sooner or later.
        var c = FlightEngine(aspect: 1.5, seed: 42)
        c.start()
        for _ in 0..<(60 * 30) where c.phase == .flying { c.step(dt: 1.0 / 60, angle: 0) }
        XCTAssertEqual(c.phase, .crashed)
    }

    func testGapsStayReachableAndInsideTheScreen() {
        var e = FlightEngine(aspect: 2.0, seed: 9)
        e.start()
        var last: Double?
        for _ in 0..<(60 * 20) {
            e.step(dt: 1.0 / 60, angle: 105)
            if e.phase != .flying { e.start(); last = nil }
            for w in e.walls {
                XCTAssertGreaterThanOrEqual(w.gapCenter - w.gapHeight / 2, 0.1)
                XCTAssertLessThanOrEqual(w.gapCenter + w.gapHeight / 2, 0.9)
            }
            if let l = last, let f = e.walls.last { XCTAssertLessThanOrEqual(abs(f.gapCenter - l), 0.36) }
            last = e.walls.last?.gapCenter
        }
    }
}

final class AngleLockTests: XCTestCase {
    func testTargetsAreSpreadAndPlayable() {
        let t = AngleLockEngine.makeTargets(seed: 1)
        XCTAssertEqual(t.count, AngleLockEngine.count)
        for (a, b) in zip(t, t.dropFirst()) { XCTAssertGreaterThanOrEqual(abs(a - b), 25) }
        for x in t {
            XCTAssertGreaterThanOrEqual(x, HingeScale.low)
            XCTAssertLessThanOrEqual(x, HingeScale.high)
        }
    }

    func testHoldingOnTargetLocksAndFinishes() {
        var e = AngleLockEngine(seed: 2)
        e.start()
        var locks = 0
        while e.phase == .playing {
            if e.step(dt: 0.1, angle: e.target! + 3) { locks += 1 }
        }
        XCTAssertEqual(locks, AngleLockEngine.count)
        XCTAssertEqual(e.phase, .finished)
        XCTAssertEqual(e.elapsed, Double(AngleLockEngine.count) * 0.8, accuracy: 1.0)
    }

    func testDriftingOffDrainsTheHold() {
        var e = AngleLockEngine(seed: 2)
        e.start()
        let t = e.target!
        e.step(dt: 0.5, angle: t)
        XCTAssertEqual(e.holdProgress, 0.5 / 0.8, accuracy: 1e-9)
        e.step(dt: 0.1, angle: t + 30)
        XCTAssertEqual(e.hold, 0.3, accuracy: 1e-9)
        XCTAssertEqual(e.index, 0)
    }
}

final class DuelTests: XCTestCase {
    func testQuickDrawEarlyTapGivesTheRoundAway() {
        var e = QuickDrawEngine(seed: 1)
        e.startRound(now: 0)
        let phase = e.tap(0, now: 0.5)
        XCTAssertEqual(phase, .roundOver(winner: 1, early: true, reactionMs: nil))
        XCTAssertEqual(e.score, [0, 1])
    }

    func testQuickDrawFirstTapAfterSignalWinsAndMatchEnds() {
        var e = QuickDrawEngine(seed: 1, winsNeeded: 2)
        var now = 0.0
        for round in 0..<2 {
            e.startRound(now: now)
            guard case .waiting(let goAt) = e.phase else { return XCTFail("not waiting") }
            XCTAssertGreaterThanOrEqual(goAt - now, 1.6)
            now = goAt + 0.25
            let phase = e.tap(1, now: now)
            if round == 0 {
                XCTAssertEqual(phase, .roundOver(winner: 1, early: false, reactionMs: 250))
            } else {
                XCTAssertEqual(phase, .matchOver(winner: 1))
            }
            XCTAssertNil(e.tap(0, now: now + 0.01), "the slower tap changes nothing")
        }
        e.startRound(now: now)
        XCTAssertEqual(e.score, [0, 0], "a new match starts from zero")
    }

    func testTugPullsTowardTheTapperAndWins() {
        var e = TugEngine(winsNeeded: 1)
        e.tap(0); e.tap(0); e.tap(1)
        XCTAssertEqual(e.knot, -TugEngine.step, accuracy: 1e-9)
        var n = 0
        while e.playing && n < 1000 { e.tap(1); n += 1 }
        XCTAssertEqual(e.roundWinner, 1)
        XCTAssertEqual(e.matchWinner, 1)
        let knot = e.knot
        e.tap(0)
        XCTAssertEqual(e.knot, knot, "no pulling after the round is decided")
        e.nextRound()
        XCTAssertEqual(e.score, [0, 0])
        XCTAssertEqual(e.knot, 0)
    }

    func testOddSpotRoundsDifferPerPlayerAndPenaltyApplies() {
        var e = OddSpotEngine(seed: 8, winsNeeded: 2)
        for _ in 0..<30 {
            XCTAssertNotEqual(e.round.odd[0], e.round.odd[1])
            XCTAssertTrue((0..<OddSpotEngine.cells).contains(e.round.odd[0]))
            let prev = e.round.pair
            e.nextRound()
            XCTAssertNotEqual(prev, e.round.pair)
        }
        let wrong = (e.round.odd[0] + 1) % OddSpotEngine.cells
        XCTAssertEqual(e.tap(0, cell: wrong, now: 10), .wrong)
        XCTAssertEqual(e.tap(0, cell: e.round.odd[0], now: 10.5), .ignored, "frozen for a second")
        XCTAssertEqual(e.symbol(for: 1, cell: e.round.odd[1]), OddSpotEngine.pairs[e.round.pair].1)
        XCTAssertEqual(e.tap(1, cell: e.round.odd[1], now: 10.6), .found)
        XCTAssertEqual(e.tap(0, cell: e.round.odd[0], now: 12), .ignored, "round already decided")
        e.nextRound()
        XCTAssertEqual(e.tap(1, cell: e.round.odd[1], now: 13), .matchWon)
    }

    func testAllSymbolPairsAreDistinct() {
        for (a, b) in OddSpotEngine.pairs { XCTAssertNotEqual(a, b) }
    }
}

final class ArenaTests: XCTestCase {
    func testDuoFoldSplitsLeftAndRightFacingEachOther() {
        // iPhone Duo inner display, open flat in landscape: the fold runs top to bottom in the middle.
        let a = ArenaLayout(size: CGSize(width: 951, height: 669), division: CGRect(x: 470, y: 0, width: 11, height: 669))
        XCTAssertTrue(a.vertical)
        XCTAssertEqual(a.sides[0].rect, CGRect(x: 0, y: 0, width: 470, height: 669))
        XCTAssertEqual(a.sides[1].rect, CGRect(x: 481, y: 0, width: 470, height: 669))
        XCTAssertEqual(a.sides[0].rotation, 90)
        XCTAssertEqual(a.sides[1].rotation, -90)
        XCTAssertEqual(a.sides[0].localSize, CGSize(width: 669, height: 470))
        XCTAssertNil(a.locate(CGPoint(x: 475, y: 300)), "touches on the fold belong to nobody")
    }

    func testPortraitPhoneSplitsTopAndBottom() {
        let a = ArenaLayout(size: CGSize(width: 402, height: 874), division: nil)
        XCTAssertFalse(a.vertical)
        XCTAssertEqual(a.sides[0].rect.minY, 437)
        XCTAssertEqual(a.sides[1].rotation, 180)
        XCTAssertEqual(a.locate(CGPoint(x: 10, y: 800))?.player, 0)
        XCTAssertEqual(a.locate(CGPoint(x: 10, y: 100))?.player, 1)
    }

    func testDivisionOutsideTheViewIsIgnored() {
        let a = ArenaLayout(size: CGSize(width: 800, height: 600), division: CGRect(x: 2000, y: 0, width: 10, height: 600))
        XCTAssertEqual(a.fold.minX, 400)
    }

    func testLocalAndArenaCoordinatesRoundTrip() {
        let sizes = [CGSize(width: 951, height: 669), CGSize(width: 402, height: 874)]
        for size in sizes {
            let a = ArenaLayout(size: size, division: nil)
            for s in a.sides {
                let p = CGPoint(x: 13, y: 29)
                let back = ArenaLayout.toLocal(ArenaLayout.toArena(p, side: s), side: s)
                XCTAssertEqual(back.x, p.x, accuracy: 1e-9)
                XCTAssertEqual(back.y, p.y, accuracy: 1e-9)
                // The local origin (top-left of the player's canvas) maps inside that player's half.
                XCTAssertTrue(s.rect.insetBy(dx: -0.5, dy: -0.5).contains(ArenaLayout.toArena(.zero, side: s)))
            }
        }
    }

    func testTopOfEachCanvasFacesTheFold() {
        let a = ArenaLayout(size: CGSize(width: 1000, height: 600), division: nil)
        // A point near the top of the left player's canvas is near the fold (x close to 500).
        let nearTop = ArenaLayout.toArena(CGPoint(x: 300, y: 5), side: a.sides[0])
        XCTAssertEqual(nearTop.x, 495, accuracy: 1e-9)
        let nearTopRight = ArenaLayout.toArena(CGPoint(x: 300, y: 5), side: a.sides[1])
        XCTAssertEqual(nearTopRight.x, 505, accuracy: 1e-9)
    }

    func testGridHitTesting() {
        let g = GridLayout(canvas: CGSize(width: 669, height: 470), columns: 4)
        for i in 0..<16 {
            let r = g.cellRect(i)
            XCTAssertEqual(g.cell(at: CGPoint(x: r.midX, y: r.midY)), i)
        }
        XCTAssertNil(g.cell(at: CGPoint(x: 1, y: 1)))
    }
}
