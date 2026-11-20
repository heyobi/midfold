import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hinge: HingeModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    section("Fold games", subtitle: hinge.hasHinge
                            ? "The hinge is the controller. Open the phone halfway and play."
                            : "Made for the iPhone Duo hinge. Here you play by tilting or with a slider.",
                            games: [.flight, .lock])
                    section("Face-to-face duels", subtitle: hinge.hasHinge
                            ? "Lay the phone open flat between you. Each of you gets one half; the fold is the line."
                            : "Lay the phone between you. Each of you gets one half of the screen.",
                            games: [.quickDraw, .tug, .oddSpot])
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .background(PaperBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { state.showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(Text("Settings"))
                }
            }
            .sheet(isPresented: $state.showSettings) { SettingsView() }
            .fullScreenCover(item: $state.playing) { game in
                GameScreen(game: game)
                    .environmentObject(state)
                    .environmentObject(hinge)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("Logo")
                .resizable().frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Midfold").font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("Games you play with the fold").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func section(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, games: [Game]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                ForEach(games) { g in
                    Button { state.playing = g } label: { GameCard(game: g) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(g.rawValue)
                }
            }
        }
    }
}

struct GameCard: View {
    let game: Game
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: game.symbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(game.tint.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title).font(.headline)
                Text(game.blurb).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: game.isFoldGame ? "iphone.gen3" : "person.2.fill")
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.08)))
        .contentShape(Rectangle())
    }
}

struct SettingsView: View {
    @EnvironmentObject var hinge: HingeModel
    @AppStorage("haptics") private var haptics = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Haptics", isOn: $haptics)
                }
                Section {
                    if hinge.hasHinge {
                        Label("iPhone Duo hinge", systemImage: "iphone.gen3")
                    } else {
                        Picker("Fold games control", selection: $hinge.control) {
                            ForEach(HingeModel.Control.allCases) { c in Text(c.label).tag(c) }
                        }
                    }
                } header: {
                    Text("Controller")
                } footer: {
                    (hinge.hasHinge
                         ? Text("Fold games read the angle of your iPhone Duo's hinge.")
                         : Text("On iPhone Duo the fold games use the hinge. On this device, tilt it toward you or use the slider."))
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Text("No accounts, no ads, no tracking. Everything stays on this device.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("Source code and privacy", destination: URL(string: "https://github.com/heyobi/midfold")!)
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

/// Wraps every game: keeps the screen on, hides system overlays and offers a close button.
struct GameScreen: View {
    let game: Game
    @EnvironmentObject var state: AppState
    @EnvironmentObject var hinge: HingeModel

    var body: some View {
        Group {
            switch game {
            case .flight: FlightView()
            case .lock: AngleLockView()
            case .quickDraw: QuickDrawView()
            case .tug: TugView()
            case .oddSpot: OddSpotView()
            }
        }
        .modifier(KeepAwake())
        .modifier(HingeReader(model: hinge))
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .environment(\.closeGame) { state.playing = nil }
    }
}

private struct CloseGameKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var closeGame: () -> Void {
        get { self[CloseGameKey.self] }
        set { self[CloseGameKey.self] = newValue }
    }
}
