import SwiftUI

/// App Store screenshot tour, only when launched with `-shots` (scripts/sim-shots.sh). Opens each screen in a
/// fixed state, writes its name to Documents/shots/ready and waits until the script answers in Documents/shots/next.
/// A name ending in "@<degrees>" asks the script to set the iPhone Duo simulator's hinge to that angle first.
@MainActor
struct ShotsTour {
    nonisolated static var active: Bool { ProcessInfo.processInfo.arguments.contains("-shots") }
    /// `-shotsOuter`: the folded iPhone Duo's outer display.
    nonisolated static var outer: Bool { ProcessInfo.processInfo.arguments.contains("-shotsOuter") }

    let state: AppState

    private var dir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("shots")
    }

    func run() async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("next"))
        // (name, level, preset, hinge angle shown when the simulator has no hinge, flap strength)
        let shots: [(String, LevelSpec?, ShotPreset, Double?)] = [
            ("1-meadow@150", .level(.meadow, 2), .flying(seconds: 7.5, flap: 0.9), 150),
            ("2-cliffs@105", .level(.cliffs, 3), .flying(seconds: 9, flap: 0.5), 105),
            ("3-caves@70", .level(.caves, 2), .flying(seconds: 14, flap: 0.25), 70),
            ("4-won", .level(.meadow, 4), .won, nil),
            ("5-home", nil, .none, nil),
        ]
        for (name, level, preset, angle) in shots {
            state.playing = nil
            try? await Task.sleep(for: .seconds(1))
            state.shotPreset = preset
            if let level { state.playing = PlayRequest(spec: level, dailyKey: nil) }
            if let angle, !state.hinge.hasHinge, !Self.outer { state.hinge.showAngle(angle, flap: 0.8) }
            try? await Task.sleep(for: .seconds(2.5))
            await announce(name)
            await waitForNext(name)
        }
        state.playing = nil
        write("ready", "done")
    }

    private func announce(_ name: String) async {
        write("ready", name)
        let h = state.hinge
        write("hinge-\(name.split(separator: "@")[0]).json",
              "{\"hasHinge\":\(h.hasHinge),\"angle\":\(h.angle),\"status\":\"\(h.status)\"}")
    }

    private func waitForNext(_ name: String) async {
        for _ in 0..<600 {
            if let s = try? String(contentsOf: dir.appendingPathComponent("next"), encoding: .utf8), s == name { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func write(_ file: String, _ text: String) {
        try? text.write(to: dir.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }
}
