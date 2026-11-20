import AVFoundation

/// Short sound effects (bundled WAVs drawn by scripts/sounds.py). Ambient session: mixes with music and follows
/// the silent switch.
final class Sound {
    static let shared = Sound()

    enum Effect: String, CaseIterable { case flap, star, gate, hit, win, lose }

    private var players: [Effect: [AVAudioPlayer]] = [:]
    private var next: [Effect: Int] = [:]

    var enabled: Bool { UserDefaults.standard.object(forKey: "sound") as? Bool ?? true }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for e in Effect.allCases {
            guard let url = Bundle.main.url(forResource: e.rawValue, withExtension: "wav") else { continue }
            // A few players per effect so quick flaps overlap instead of cutting each other off.
            players[e] = (0..<(e == .flap ? 4 : 2)).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.enableRate = true
                p?.prepareToPlay()
                return p
            }
        }
    }

    /// `strength` 0…1 sets loudness and pitch (a strong flap is a deeper, louder whoosh).
    func play(_ e: Effect, strength: Double = 1) {
        guard enabled, let list = players[e], !list.isEmpty else { return }
        let i = (next[e] ?? 0) % list.count
        next[e] = i + 1
        let p = list[i]
        p.currentTime = 0
        p.volume = Float(0.35 + 0.65 * strength)
        p.rate = e == .flap ? Float(1.25 - 0.4 * strength) : 1
        p.play()
    }
}
