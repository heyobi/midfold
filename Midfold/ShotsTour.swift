import SwiftUI

/// App Store screenshot tour, only when launched with `-shots` (scripts/sim-shots.sh). Opens each screen in a
/// fixed state, writes its name to Documents/shots/ready and waits until the script answers in Documents/shots/next.
/// A name ending in "@<degrees>" asks the script to set the iPhone Duo simulator's hinge to that angle first.
@MainActor
struct ShotsTour {
    nonisolated static var active: Bool { ProcessInfo.processInfo.arguments.contains("-shots") }
    /// `-shotsOuter`: the folded iPhone Duo's outer display, where the fold games do not apply.
    nonisolated static var outer: Bool { ProcessInfo.processInfo.arguments.contains("-shotsOuter") }

    let state: AppState

    private var dir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("shots")
    }

    func run() async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("next"))
        var shots: [(String, Game?, Double?)] = [
            ("1-home", nil, nil),
            ("2-flight@100", .flight, 100),
            ("3-lock@135", .lock, 135),
            ("4-quickdraw", .quickDraw, nil),
            ("5-oddspot", .oddSpot, nil),
            ("6-tug", .tug, nil),
        ]
        if Self.outer { shots.removeAll { $0.1?.isFoldGame == true } }
        for (name, game, angle) in shots {
            state.playing = nil
            try? await Task.sleep(for: .seconds(1))
            state.hinge.shotAngle = angle
            if let angle { state.hinge.sliderAngle = angle }
            state.playing = game
            // The script sets the hinge after reading the name; give the game time to settle afterwards.
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
              "{\"hasHinge\":\(h.hasHinge),\"angle\":\(h.hingeAngle),\"status\":\"\(h.status)\"}")
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
