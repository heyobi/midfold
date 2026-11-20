import SwiftUI
import UIKit
import QuartzCore

enum Palette {
    static let sun = Color(red: 1.0, green: 0.78, blue: 0.30)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let ink = Color(red: 0.10, green: 0.11, blue: 0.20)
    static let night = Color(red: 0.07, green: 0.08, blue: 0.16)
    static let blue = Color(red: 0.25, green: 0.55, blue: 1.0)
}

/// Frame clock for the game (CADisplayLink), with the seconds since the previous frame.
@MainActor
final class Ticker: NSObject {
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    var onTick: ((Double) -> Void)?

    func start() {
        guard link == nil else { return }
        last = CACurrentMediaTime()
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() { link?.invalidate(); link = nil }

    @objc private func tick(_ l: CADisplayLink) {
        let t = l.timestamp
        let dt = min(1.0 / 30, max(0, t - last))
        last = t
        onTick?(dt)
    }
}

enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let note = UINotificationFeedbackGenerator()

    /// One flap: a soft tap for a hop, a firm one for a strong flap.
    static func flap(_ strength: Double) {
        guard enabled else { return }
        (strength > 0.6 ? rigid : soft).impactOccurred(intensity: 0.35 + 0.65 * strength)
    }
    static func star() { guard enabled else { return }; note.notificationOccurred(.success) }
    static func gate() { guard enabled else { return }; soft.impactOccurred(intensity: 0.25) }
    static func hit() { guard enabled else { return }; heavy.impactOccurred(intensity: 1) }
    static func lose() { guard enabled else { return }; note.notificationOccurred(.error) }
}

/// Keeps the screen awake while playing.
struct KeepAwake: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

struct RoundButton: View {
    var symbol: String
    var label: LocalizedStringKey
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(Text(label))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.sun
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 26).padding(.vertical, 13)
            .background(tint, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22).padding(.vertical, 13)
            .background(.white.opacity(0.16), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

/// Three star outlines, filled up to `count`.
struct StarRow: View {
    var count: Int
    var size: CGFloat = 16
    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < count ? Palette.sun : .white.opacity(0.35))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(count) of 3 stars"))
    }
}
