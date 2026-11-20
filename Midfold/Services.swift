import SwiftUI
import StoreKit
import GameKit

/// One-time unlock of worlds 2 and 3 and Endless (StoreKit 2). World 1 and the daily challenge are free.
@MainActor
final class Store: ObservableObject {
    static let productID = "com.heyobi.midfold.allworlds"

    @Published private(set) var unlocked = UserDefaults.standard.bool(forKey: "unlocked")
    @Published private(set) var product: Product?
    @Published var busy = false
    @Published var message: LocalizedStringKey?

    private var updates: Task<Void, Never>?

    init() {
        if ShotsTour.active { unlocked = true }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish(); await self?.refresh() }
            }
        }
        Task { await load(); await refresh() }
    }

    func load() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        if ShotsTour.active { owned = true }
        set(owned)
    }

    private func set(_ owned: Bool) {
        unlocked = owned
        UserDefaults.standard.set(owned, forKey: "unlocked")
    }

    func buy() async {
        if product == nil { await load() }
        guard let product else { message = "The store is not available right now. Try again later."; return }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let v):
                if case .verified(let t) = v { await t.finish(); set(true) }
            case .pending: message = "The purchase is waiting for approval."
            default: break
            }
        } catch {
            message = "The purchase did not go through. Nothing was charged."
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        try? await AppStore.sync()
        await refresh()
        message = unlocked ? "All worlds are unlocked." : "No earlier purchase was found for this Apple Account."
    }
}

/// Game Center: one leaderboard for Endless, one for total stars, and a handful of achievements. Everything is
/// optional; when the player is not signed in the game simply does not report.
@MainActor
final class GameCenter: ObservableObject {
    static let endlessBoard = "midfold.endless"
    static let starsBoard = "midfold.stars"

    enum Achievement: String {
        case firstFlight = "midfold.first_flight"
        case meadow = "midfold.world_meadow"
        case cliffs = "midfold.world_cliffs"
        case caves = "midfold.world_caves"
        case allStarsMeadow = "midfold.stars_meadow"
        case endless25 = "midfold.endless_25"
        case endless50 = "midfold.endless_50"
        case daily = "midfold.daily"
    }

    @Published private(set) var signedIn = false

    func authenticate() {
        guard !ShotsTour.active else { return }
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, _ in
            if let vc {
                UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                    .first?.present(vc, animated: true)
            }
            Task { @MainActor in self?.signedIn = GKLocalPlayer.local.isAuthenticated }
        }
    }

    func submit(_ score: Int, to board: String) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [board])
        }
    }

    func unlock(_ a: Achievement) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let ach = GKAchievement(identifier: a.rawValue)
        ach.percentComplete = 100
        ach.showsCompletionBanner = true
        GKAchievement.report([ach]) { _ in }
    }

    /// Reports what a finished run earned.
    func report(progress p: Progress, level: LevelSpec?, endlessScore: Int?, daily: Bool) {
        if let l = level, p.completed(l) {
            unlock(.firstFlight)
            let worldDone = (0..<World.levelsPerWorld).allSatisfy { p.completed(.level(l.world, $0)) }
            if worldDone { unlock([Achievement.meadow, .cliffs, .caves][l.world.rawValue]) }
            if p.stars(in: .meadow) == 3 * World.levelsPerWorld { unlock(.allStarsMeadow) }
            submit(p.totalStars, to: Self.starsBoard)
        }
        if let s = endlessScore {
            if daily { unlock(.daily) } else {
                submit(s, to: Self.endlessBoard)
                if s >= 25 { unlock(.endless25) }
                if s >= 50 { unlock(.endless50) }
            }
        }
    }

    func showDashboard() {
        guard GKLocalPlayer.local.isAuthenticated else { authenticate(); return }
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }
}
