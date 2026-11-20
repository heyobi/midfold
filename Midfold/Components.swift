import SwiftUI
import UIKit
import QuartzCore

enum Palette {
    static let blue = Color(red: 0.20, green: 0.52, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.16)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.20)
    static let night = Color(red: 0.07, green: 0.08, blue: 0.16)
    static func player(_ p: Player) -> Color { p == 0 ? blue : orange }
}

extension Player {
    var colorName: LocalizedStringKey { self == 0 ? "Blue" : "Orange" }
}

/// Frame clock for the games (CADisplayLink), with the elapsed seconds since the previous frame.
final class Ticker: NSObject, ObservableObject {
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    var onTick: ((Double, Double) -> Void)?   // (dt, now)
    @Published private(set) var frame = 0

    func start() {
        guard link == nil else { return }
        last = CACurrentMediaTime()
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() { link?.invalidate(); link = nil }

    static var now: Double { CACurrentMediaTime() }

    @objc private func tick(_ l: CADisplayLink) {
        let t = l.timestamp
        let dt = min(0.05, max(0, t - last))
        last = t
        onTick?(dt, t)
        frame &+= 1
    }

    deinit { link?.invalidate() }
}

enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }
    static func tap() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func thump() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

/// Keeps the screen awake while a game is on screen.
struct KeepAwake: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

/// Every touch that starts on this surface, with its location – several fingers at once, so two players can
/// tap at the same moment. SwiftUI gestures in sibling views do not reliably recognise simultaneous touches.
struct MultiTouchSurface: UIViewRepresentable {
    var onTouch: (CGPoint) -> Void

    func makeUIView(context: Context) -> TouchView {
        let v = TouchView()
        v.isMultipleTouchEnabled = true
        v.backgroundColor = .clear
        v.onTouch = onTouch
        return v
    }

    func updateUIView(_ v: TouchView, context: Context) { v.onTouch = onTouch }

    final class TouchView: UIView {
        var onTouch: ((CGPoint) -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            for t in touches { onTouch?(t.location(in: self)) }
        }
    }
}

/// Small round close button used on game screens.
struct CloseButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(Text("Close"))
    }
}

struct PaperBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.11, green: 0.13, blue: 0.27), Palette.night],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
