import SwiftUI

extension World {
    var title: LocalizedStringKey {
        switch self {
        case .meadow: "Paper Meadow"
        case .cliffs: "Gusty Cliffs"
        case .caves: "Ink Caves"
        }
    }
    var blurb: LocalizedStringKey {
        switch self {
        case .meadow: "Rolling hills and paper gates. Learn the rhythm."
        case .cliffs: "Up- and downdrafts and gates that slide."
        case .caves: "Narrow tunnels that need gentle pumps."
        }
    }
    var symbol: String {
        switch self {
        case .meadow: "leaf.fill"
        case .cliffs: "wind"
        case .caves: "moon.stars.fill"
        }
    }
}

enum ShotPreset: Equatable { case none, flying(seconds: Double, flap: Double), won }

/// Everything that outlives one flight: progress, the store, Game Center and which flight is on screen.
@MainActor
final class AppState: ObservableObject {
    @Published var playing: PlayRequest?
    @Published var showSettings = false
    @Published var showPaywall = false
    @Published private(set) var progress: Progress
    @Published var shotPreset: ShotPreset = .none

    let hinge = HingeModel()
    let store = Store()
    let gameCenter = GameCenter()

    init() {
        if let d = UserDefaults.standard.data(forKey: "progress"), let p = try? JSONDecoder().decode(Progress.self, from: d),
           !ShotsTour.active {
            progress = p
        } else {
            progress = Progress()
        }
        if ShotsTour.active { progress = Self.demoProgress }
    }

    private static var demoProgress: Progress {
        var p = Progress()
        p.seenTutorial = true
        for i in 0..<6 { p.record(.level(.meadow, i), stars: i == 4 ? 2 : 3) }
        for i in 0..<3 { p.record(.level(.cliffs, i), stars: [3, 2, 3][i]) }
        p.record(.level(.caves, 0), stars: 1)
        p.bestEndless = 47
        return p
    }

    private func save() {
        guard !ShotsTour.active, let d = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(d, forKey: "progress")
    }

    static var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static var todaySpec: LevelSpec {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return .daily(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
    }

    func isOpen(_ l: LevelSpec) -> Bool { progress.isOpen(l, unlocked: store.unlocked) }

    /// The next level to play: the first open level without stars.
    var continueLevel: LevelSpec {
        LevelSpec.all.first { isOpen($0) && !progress.completed($0) } ?? .level(.meadow, 0)
    }

    func nextLevel(after l: LevelSpec) -> LevelSpec? {
        guard !l.endless else { return nil }
        let all = LevelSpec.all
        guard let i = all.firstIndex(of: l), i + 1 < all.count else { return nil }
        let n = all[i + 1]
        return isOpen(n) ? n : nil
    }

    func play(_ l: LevelSpec, dailyKey: String? = nil) {
        if !l.endless && !isOpen(l) && l.world != .meadow { showPaywall = true; return }
        if l.endless && dailyKey == nil && !store.unlocked { showPaywall = true; return }
        let req = PlayRequest(spec: l, dailyKey: dailyKey)
        if playing != nil {
            playing = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.playing = req }
        } else {
            playing = req
        }
    }

    func playDaily() { play(Self.todaySpec, dailyKey: Self.todayKey) }

    func closeGame() { playing = nil }

    func markTutorialSeen() {
        progress.seenTutorial = true
        save()
    }

    func best(for r: PlayRequest) -> Int {
        if let k = r.dailyKey { return progress.dailyBest[k] ?? 0 }
        return progress.bestEndless
    }

    /// Records a finished flight. Returns true for a new best.
    func finished(_ sim: FlightSim, request r: PlayRequest) -> Bool {
        guard !ShotsTour.active else { return false }
        var best = false
        if r.spec.endless {
            best = progress.recordEndless(sim.score, dailyKey: r.dailyKey)
            gameCenter.report(progress: progress, level: nil, endlessScore: sim.score, daily: r.dailyKey != nil)
        } else if sim.phase == .won {
            best = progress.record(r.spec, stars: sim.starsTaken)
            gameCenter.report(progress: progress, level: r.spec, endlessScore: nil, daily: false)
        }
        save()
        return best
    }
}

/// Lets the flight screen turn a regular iPhone sideways (the game is played in landscape, like the Duo held
/// half open). The iPhone Duo and iPad keep whatever orientation they are in.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var lock: UIInterfaceOrientationMask = .all
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.lock
    }
}

@MainActor
enum Orientation {
    static func landscape(_ on: Bool, hasHinge: Bool) {
        guard UIDevice.current.userInterfaceIdiom == .phone, !hasHinge else { return }
        AppDelegate.lock = on ? .landscape : .all
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for w in scene.windows { w.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: on ? .landscapeRight : .all)) { _ in }
        }
    }
}

@main
struct MidfoldApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(state)
                .environmentObject(state.hinge)
                .environmentObject(state.store)
                .modifier(HingeReader(model: state.hinge))
                .preferredColorScheme(.dark)
                .task {
                    state.gameCenter.authenticate()
                    if ShotsTour.active { await ShotsTour(state: state).run() }
                }
        }
    }
}
