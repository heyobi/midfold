import SwiftUI

/// Splits the screen at the iPhone Duo fold (or the middle elsewhere) and turns each half toward its player.
/// All touches go through one multi-touch surface and are mapped into the player's own canvas.
struct DuelArena<Half: View>: View {
    var onTouch: (Player, CGPoint, ArenaLayout.Side) -> Void
    @ViewBuilder var half: (Player, CGSize) -> Half
    @Environment(\.closeGame) private var close

    var body: some View {
        GeometryReader { g in
            let layout = ArenaLayout(size: g.size, division: foldFrame(g))
            ZStack(alignment: .topLeading) {
                Palette.night
                ForEach(0..<2, id: \.self) { p in
                    let s = layout.sides[p]
                    let local = s.localSize
                    half(p, local)
                        .frame(width: local.width, height: local.height)
                        .rotationEffect(.degrees(s.rotation))
                        .frame(width: s.rect.width, height: s.rect.height)
                        .clipped()
                        .offset(x: s.rect.minX, y: s.rect.minY)
                }
                FoldLine(layout: layout)
                MultiTouchSurface { pt in
                    if let hit = layout.locate(pt) { onTouch(hit.player, hit.local, layout.sides[hit.player]) }
                }
                CloseButton(action: close)
                    .position(x: layout.fold.midX, y: layout.vertical ? 30 : layout.fold.midY)
                    .offset(x: layout.vertical ? 0 : g.size.width / 2 - 40)
            }
        }
        .ignoresSafeArea()
    }
}

/// The centre line of the arena, drawn on the fold.
struct FoldLine: View {
    let layout: ArenaLayout
    var body: some View {
        Canvas { ctx, _ in
            let f = layout.fold
            var p = Path()
            if layout.vertical {
                p.move(to: CGPoint(x: f.midX, y: 0)); p.addLine(to: CGPoint(x: f.midX, y: f.maxY))
            } else {
                p.move(to: CGPoint(x: 0, y: f.midY)); p.addLine(to: CGPoint(x: f.maxX, y: f.midY))
            }
            if f.width > 1 && f.height > 1 {
                ctx.fill(Path(f), with: .color(.black.opacity(0.5)))
            }
            ctx.stroke(p, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 8))
            ctx.stroke(p, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 2.5, dash: [12, 9]))
        }
        .allowsHitTesting(false)
    }
}

/// Score strip at the top of each player's half (next to the fold).
struct DuelHeader: View {
    let player: Player
    let score: [Int]
    let target: Int
    var body: some View {
        HStack {
            Text(player.colorName).font(.headline.weight(.heavy)).foregroundStyle(Palette.player(player))
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<target, id: \.self) { i in
                    Circle().fill(i < score[player] ? Palette.player(player) : .white.opacity(0.18))
                        .frame(width: 12, height: 12)
                }
            }
            Spacer()
            Text("\(score[player]) – \(score[player.other])")
                .font(.headline.monospacedDigit()).foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 22)
        .frame(height: 56)
    }
}

/// Big centred message in a player's half.
struct DuelMessage: View {
    let title: Text
    var subtitle: Text? = nil
    var color: Color = .white
    var body: some View {
        VStack(spacing: 6) {
            title.font(.system(size: 44, weight: .heavy, design: .rounded)).foregroundStyle(color)
                .minimumScaleFactor(0.5).lineLimit(1)
            if let subtitle { subtitle.font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.85)) }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
    }
}

// MARK: - Quick Draw

final class QuickDrawModel: ObservableObject {
    @Published var engine = QuickDrawEngine(seed: UInt64(Date().timeIntervalSince1970))
    @Published var ready = [false, false]
    let ticker = Ticker()
    private var nextRoundAt: Double?

    func attach() {
        if ShotsTour.active {
            engine.score = [2, 1]
            engine.phase = .roundOver(winner: 0, early: false, reactionMs: 212)
            return
        }
        ticker.onTick = { [weak self] _, now in self?.tick(now) }
        ticker.start()
    }

    func tick(_ now: Double) {
        let before = engine.phase
        engine.tick(now: now)
        if case .waiting = before, case .go = engine.phase { Haptics.thump() }
        if let t = nextRoundAt, now >= t {
            nextRoundAt = nil
            engine.startRound(now: now)
        }
    }

    func touch(_ p: Player) {
        let now = Ticker.now
        switch engine.phase {
        case .idle, .matchOver:
            // Both players tap once to say they are ready; the first round starts right after.
            guard nextRoundAt == nil else { return }
            ready[p] = true
            Haptics.tap()
            if ready == [true, true] {
                ready = [false, false]
                engine.startRound(now: now)
            }
        case .waiting, .go:
            if let phase = engine.tap(p, now: now) {
                if case .roundOver(_, let early, _) = phase, early { Haptics.error() } else { Haptics.success() }
                if case .roundOver = phase { nextRoundAt = now + 2.2 }
            }
        case .roundOver:
            break
        }
    }
}

struct QuickDrawView: View {
    @StateObject private var model = QuickDrawModel()

    var body: some View {
        DuelArena(onTouch: { p, _, _ in model.touch(p) }) { p, size in
            half(p)
        }
        .onAppear { model.attach() }
        .onDisappear { model.ticker.stop() }
    }

    @ViewBuilder private func half(_ p: Player) -> some View {
        let phase = model.engine.phase
        ZStack {
            background(p, phase)
            VStack(spacing: 0) {
                DuelHeader(player: p, score: model.engine.score, target: model.engine.winsNeeded)
                Spacer()
                message(p, phase)
                Spacer()
                Spacer().frame(height: 40)
            }
        }
    }

    private func background(_ p: Player, _ phase: QuickDrawEngine.Phase) -> Color {
        switch phase {
        case .go: return Color(red: 0.10, green: 0.72, blue: 0.38)
        case .roundOver(let w, _, _), .matchOver(let w): return w == p ? Palette.player(p).opacity(0.55) : Palette.night
        default: return Palette.night
        }
    }

    @ViewBuilder private func message(_ p: Player, _ phase: QuickDrawEngine.Phase) -> some View {
        switch phase {
        case .idle:
            DuelMessage(title: Text("Quick Draw"),
                        subtitle: (model.ready[p] ? Text("Waiting for the other player…") : Text("Tap when you are ready")))
        case .waiting:
            DuelMessage(title: Text("Wait…"), subtitle: Text("Tap the moment it turns green"))
        case .go:
            DuelMessage(title: Text("TAP!"))
        case .roundOver(let w, let early, let ms):
            if w == p {
                DuelMessage(title: Text("Point!"), subtitle: early ? Text("They tapped too early") as Text? : ms.map { Text("\($0) ms") },
                            color: .white)
            } else {
                DuelMessage(title: early ? Text("Too early!") : Text("Too slow"), color: .white.opacity(0.7))
            }
        case .matchOver(let w):
            DuelMessage(title: (w == p ? Text("You win!") : Text("You lose")),
                        subtitle: (model.ready[p] ? Text("Waiting for the other player…") : Text("Tap to play again")),
                        color: w == p ? .white : .white.opacity(0.7))
        }
    }
}

// MARK: - Tug Line

final class TugModel: ObservableObject {
    @Published var engine = TugEngine()
    @Published var started = false
    @Published var ready = [false, false]
    @Published var countdown: Int?
    private var resumeAt: Double?
    let ticker = Ticker()

    func attach() {
        if ShotsTour.active {
            engine.score = [1, 0]
            engine.knot = -0.4
            started = true
            return
        }
        ticker.onTick = { [weak self] _, now in self?.tick(now) }
        ticker.start()
    }

    func tick(_ now: Double) {
        guard let t = resumeAt else { return }
        let left = Int(ceil(t - now))
        if left <= 0 {
            resumeAt = nil; countdown = nil; started = true
        } else if countdown != left {
            countdown = left
            Haptics.tap()
        }
    }

    func touch(_ p: Player) {
        if started && engine.playing {
            engine.tap(p)
            if !engine.playing {
                Haptics.success()
                started = false
            }
            return
        }
        guard countdown == nil else { return }
        ready[p] = true
        if ready == [true, true] {
            ready = [false, false]
            if engine.roundWinner != nil { engine.nextRound() }
            resumeAt = Ticker.now + 3
        }
    }
}

struct TugView: View {
    @StateObject private var model = TugModel()

    var body: some View {
        DuelArena(onTouch: { p, _, _ in model.touch(p) }) { p, size in
            half(p, size)
        }
        .onAppear { model.attach() }
        .onDisappear { model.ticker.stop() }
    }

    private func half(_ p: Player, _ size: CGSize) -> some View {
        // In each half the fold is at the top. The knot's distance from the fold: 0 at the fold, 1 at your edge.
        let mine = p == 0 ? -model.engine.knot : model.engine.knot
        let e = model.engine
        return ZStack(alignment: .top) {
            Palette.night
            // Rope from the fold to the player's edge; the knot moves along it.
            let ropeTop: CGFloat = 0, ropeBottom = size.height
            Rectangle().fill(Color(red: 0.86, green: 0.74, blue: 0.52))
                .frame(width: 10, height: ropeBottom - ropeTop)
            if mine > 0 {
                Rectangle().fill(Palette.player(p).opacity(0.35))
                    .frame(width: size.width, height: size.height * mine)
            }
            Circle().fill(.white)
                .overlay(Circle().stroke(Palette.player(mine >= 0 ? p : p.other), lineWidth: 8))
                .frame(width: 64, height: 64)
                .offset(y: max(0, mine) * size.height - 32)
                .opacity(mine >= 0 ? 1 : 0.0)
            VStack(spacing: 0) {
                DuelHeader(player: p, score: e.score, target: e.winsNeeded)
                Spacer()
                Group {
                    if let c = model.countdown {
                        DuelMessage(title: Text("\(c)"))
                    } else if model.started {
                        DuelMessage(title: (mine >= 0 ? Text("Pull!") : Text("Pull harder!")), subtitle: Text("Tap tap tap"))
                    } else if let m = e.matchWinner {
                        DuelMessage(title: (m == p ? Text("You win!") : Text("You lose")),
                                    subtitle: (model.ready[p] ? Text("Waiting for the other player…") : Text("Tap to play again")))
                    } else if let w = e.roundWinner {
                        DuelMessage(title: (w == p ? Text("Round to you!") : Text("Round lost")),
                                    subtitle: (model.ready[p] ? Text("Waiting for the other player…") : Text("Tap for the next round")))
                    } else {
                        DuelMessage(title: Text("Tug Line"),
                                    subtitle: (model.ready[p] ? Text("Waiting for the other player…") : Text("Tap when you are ready")))
                    }
                }
                .padding(.vertical, 12)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Spacer()
            }
        }
    }
}

// MARK: - Odd Spot

final class OddSpotModel: ObservableObject {
    @Published var engine = OddSpotEngine(seed: UInt64(Date().timeIntervalSince1970))
    @Published var started = false
    @Published var ready = [false, false]
    @Published var wrongCell: [Int?] = [nil, nil]
    @Published var now = 0.0
    private var nextAt: Double?
    let ticker = Ticker()

    func attach() {
        if ShotsTour.active {
            engine = OddSpotEngine(seed: 12)
            engine.score = [3, 2]
            engine.lockedUntil[1] = .greatestFiniteMagnitude
            wrongCell = [nil, (engine.round.odd[1] + 6) % OddSpotEngine.cells]
            now = Ticker.now
            started = true
            return
        }
        ticker.onTick = { [weak self] _, now in self?.tick(now) }
        ticker.start()
    }

    func tick(_ t: Double) {
        // Only publish time while someone is frozen, so the grid does not redraw every frame.
        if engine.isLocked(0, now: t) || engine.isLocked(1, now: t) || wrongCell != [nil, nil] {
            now = t
            for p in 0..<2 where !engine.isLocked(p, now: t) && wrongCell[p] != nil { wrongCell[p] = nil }
        }
        if let n = nextAt, t >= n {
            nextAt = nil
            if engine.matchWinner == nil { engine.nextRound() }
        }
    }

    func touch(_ p: Player, local: CGPoint, canvas: CGSize) {
        let t = Ticker.now
        guard started, engine.matchWinner == nil else {
            guard nextAt == nil else { return }
            ready[p] = true
            Haptics.tap()
            if ready == [true, true] {
                ready = [false, false]
                if engine.matchWinner != nil { engine.nextRound() }
                started = true
            }
            return
        }
        guard let cell = GridLayout(canvas: canvas, columns: OddSpotEngine.columns).cell(at: local) else { return }
        switch engine.tap(p, cell: cell, now: t) {
        case .wrong: wrongCell[p] = cell; now = t; Haptics.error()
        case .found: Haptics.success(); nextAt = t + 1.4
        case .matchWon: Haptics.success(); nextAt = t + 1.4; started = false
        case .ignored: break
        }
    }
}

struct OddSpotView: View {
    @StateObject private var model = OddSpotModel()

    var body: some View {
        DuelArena(onTouch: { p, local, side in model.touch(p, local: local, canvas: side.localSize) }) { p, size in
            half(p, size)
        }
        .onAppear { model.attach() }
        .onDisappear { model.ticker.stop() }
    }

    private func half(_ p: Player, _ size: CGSize) -> some View {
        let e = model.engine
        let grid = GridLayout(canvas: size, columns: OddSpotEngine.columns)
        let locked = e.isLocked(p, now: model.now)
        return ZStack(alignment: .topLeading) {
            Palette.night
            VStack(spacing: 0) {
                DuelHeader(player: p, score: e.score, target: e.winsNeeded)
                Spacer()
            }
            if model.started || e.lastWinner != nil {
                ForEach(0..<OddSpotEngine.cells, id: \.self) { i in
                    let r = grid.cellRect(i)
                    let reveal = e.lastWinner != nil && i == e.round.odd[p]
                    Image(systemName: e.symbol(for: p, cell: i))
                        .font(.system(size: r.width * 0.5, weight: .semibold))
                        .foregroundStyle(reveal ? Palette.player(e.lastWinner ?? p) : .white)
                        .frame(width: r.width - 8, height: r.height - 8)
                        .background(model.wrongCell[p] == i ? Color.red.opacity(0.45)
                                    : (reveal ? .white.opacity(0.22) : .white.opacity(0.07)),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .position(x: r.midX, y: r.midY)
                }
                .opacity(locked ? 0.35 : 1)
            }
            Group {
                if locked {
                    DuelMessage(title: Text("Frozen!"), subtitle: Text("Wrong one"))
                } else if let m = e.matchWinner, !model.started {
                    DuelMessage(title: (m == p ? Text("You win!") : Text("You lose")),
                                subtitle: (model.ready[p] ? Text("Waiting for the other player…") : Text("Tap to play again")))
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if let w = e.lastWinner {
                    DuelMessage(title: (w == p ? Text("Found it!") : Text("Too slow")))
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if !model.started {
                    DuelMessage(title: Text("Odd Spot"),
                                subtitle: (model.ready[p] ? Text("Waiting for the other player…") : Text("Find the odd one out. Tap when you are ready")))
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
    }
}
