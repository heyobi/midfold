import SwiftUI
import QuartzCore

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var hinge: HingeModel
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            GeometryReader { g in
                let wide = g.size.width > 700
                ScrollView {
                    VStack(alignment: .leading, spacing: wide ? 30 : 22) {
                        hero(wide: wide)
                        modes(wide: wide)
                        ForEach(World.allCases) { w in WorldSection(world: w, wide: wide) }
                        footer
                    }
                    .padding(.horizontal, wide ? 36 : 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 1180)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(HomeBackground())
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { app.gameCenter.showDashboard() } label: { Image(systemName: "trophy") }
                        .accessibilityLabel(Text("Leaderboards"))
                    Button { app.showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(Text("Settings"))
                }
            }
            .sheet(isPresented: $app.showSettings) {
                SettingsView().environmentObject(app).environmentObject(hinge).environmentObject(store)
            }
            .sheet(isPresented: $app.showPaywall) { PaywallView().environmentObject(store) }
            .fullScreenCover(item: $app.playing) { req in
                PlayView(request: req)
                    .id(req.id)
                    .environmentObject(app)
                    .environmentObject(hinge)
            }
        }
    }

    private func hero(wide: Bool) -> some View {
        HStack(alignment: .center, spacing: wide ? 28 : 16) {
            Image("Logo")
                .resizable().frame(width: wide ? 110 : 72, height: wide ? 110 : 72)
                .clipShape(RoundedRectangle(cornerRadius: wide ? 26 : 18, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text("Midfold").font(.system(size: wide ? 58 : 38, weight: .heavy, design: .rounded))
                (hinge.hasHinge ? Text("Pump the hinge to fly") : Text("A paper bird, one flap at a time"))
                    .font(wide ? .title2.weight(.semibold) : .headline).foregroundStyle(.white.opacity(0.8))
                Button {
                    app.play(app.continueLevel)
                } label: {
                    Label {
                        app.progress.stars.isEmpty ? Text("Play") : Text("Continue \(app.continueLevel.number)")
                    } icon: {
                        Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
                .accessibilityIdentifier("play")
            }
        }
        .padding(.top, 8)
    }

    private var dailyDetail: LocalizedStringKey? {
        if let b = app.progress.dailyBest[AppState.todayKey] { return "Today's best \(b)" }
        return nil
    }

    private var endlessDetail: LocalizedStringKey? {
        app.progress.bestEndless > 0 ? "Best \(app.progress.bestEndless)" : nil
    }

    private func modes(wide: Bool) -> some View {
        let cols = [GridItem(.adaptive(minimum: wide ? 320 : 260), spacing: 14)]
        return LazyVGrid(columns: cols, spacing: 14) {
            ModeCard(title: "Daily flight", subtitle: "A new course every day, the same for everyone.",
                     symbol: "calendar", tint: Color(red: 0.3, green: 0.75, blue: 0.6),
                     detail: dailyDetail) { app.playDaily() }
            ModeCard(title: "Endless", subtitle: "How far can Kip go? It only gets harder.",
                     symbol: "infinity", tint: Color(red: 0.55, green: 0.42, blue: 1.0),
                     detail: endlessDetail, locked: !store.unlocked) {
                app.play(.endless(seed: UInt64(Date().timeIntervalSince1970)))
            }
        }
    }

    private var footer: some View {
        (hinge.hasHinge
            ? Text("Made for iPhone Duo: hold it sideways, half open, and pump the hinge.")
            : Text("Made for iPhone Duo, where you fly by pumping the hinge. Here, tap to flap."))
            .font(.footnote).foregroundStyle(.white.opacity(0.6))
            .padding(.top, 4)
    }
}

struct HomeBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.16, green: 0.24, blue: 0.48), Color(red: 0.36, green: 0.30, blue: 0.56),
                                Color(red: 0.62, green: 0.42, blue: 0.50)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct ModeCard: View {
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var symbol: String
    var tint: Color
    var detail: LocalizedStringKey?
    var locked = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title).font(.headline)
                        if locked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.white.opacity(0.6)) }
                    }
                    Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail { Text(detail).font(.caption.bold()).foregroundStyle(Palette.sun) }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

struct WorldSection: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: Store
    let world: World
    var wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(world.title, systemImage: world.symbol).font(wide ? .title.bold() : .title2.bold())
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Palette.sun)
                    Text("\(app.progress.stars(in: world))/\(3 * World.levelsPerWorld)").monospacedDigit()
                }
                .font(.subheadline.bold())
            }
            HStack {
                Text(world.blurb).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                if world != .meadow && !store.unlocked {
                    Button { app.showPaywall = true } label: { Label("Unlock", systemImage: "lock.open.fill") }
                        .font(.subheadline.bold()).buttonStyle(.borderless).tint(Palette.sun)
                }
            }
            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: wide ? 6 : 3)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<World.levelsPerWorld, id: \.self) { i in
                    LevelTile(spec: .level(world, i), wide: wide)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(wide ? 22 : 16)
        .background(Theme.of(world).skyTop.opacity(0.35), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct LevelTile: View {
    @EnvironmentObject var app: AppState
    let spec: LevelSpec
    var wide: Bool

    var body: some View {
        let open = app.isOpen(spec)
        let stars = app.progress.stars[spec.id]
        Button { app.play(spec) } label: {
            VStack(spacing: 6) {
                Text(spec.number).font(.system(size: wide ? 26 : 20, weight: .heavy, design: .rounded))
                if open {
                    StarRow(count: stars ?? 0, size: wide ? 14 : 11)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: wide ? 14 : 11)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, minHeight: wide ? 92 : 70)
            .background(open ? Color.white.opacity(0.16) : Color.black.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(open ? 1 : 0.65)
        }
        .buttonStyle(.plain)
        .disabled(!open && spec.world == .meadow)
        .accessibilityLabel(Text("Level \(spec.number)"))
        .accessibilityValue(open ? Text("\(stars ?? 0) of 3 stars") : Text("Locked"))
    }
}

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var hinge: HingeModel
    @EnvironmentObject var store: Store
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Sound", isOn: $sound)
                    Toggle("Haptics", isOn: $haptics)
                }
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Pump sensitivity")
                            Spacer()
                            Text("\(Int((hinge.sensitivity * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: $hinge.sensitivity, in: 0.5...1.5, step: 0.05)
                    }
                    if hinge.hasHinge {
                        HStack {
                            Text("Try it")
                            Spacer()
                            TimelineView(.animation) { tl in
                                let since = tl.date.timeIntervalSinceNow + CACurrentMediaTime() - (hinge.lastFlap?.at ?? -9)
                                HingeGauge(angle: hinge.angle, flap: (hinge.lastFlap?.strength ?? 0) * max(0, 1 - since / 0.8))
                            }
                            .frame(width: 96, height: 56)
                        }
                    }
                } header: {
                    Text("iPhone Duo hinge")
                } footer: {
                    Text("Higher sensitivity makes small pumps flap harder. Without a hinge, tap to flap.")
                }
                Section {
                    if store.unlocked {
                        Label("All worlds unlocked", systemImage: "checkmark.seal.fill")
                    } else {
                        Button("Unlock all worlds") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { app.showPaywall = true }
                        }
                    }
                    Button("Restore purchases") { Task { await store.restore() } }
                    Button("Leaderboards and achievements") { app.gameCenter.showDashboard() }
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    Text("No accounts, no ads, no tracking. Your progress stays on this device; Game Center is optional.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("Source code and privacy", destination: URL(string: "https://github.com/heyobi/midfold")!)
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert(store.message ?? "", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
        .modifier(HingeReader(model: hinge))
    }
}

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image("Logo").resizable().frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 30)
            Text("Unlock all worlds").font(.system(size: 30, weight: .heavy, design: .rounded))
            VStack(alignment: .leading, spacing: 12) {
                Label("Gusty Cliffs: drafts and sliding gates", systemImage: "wind")
                Label("Ink Caves: tunnels that need gentle pumps", systemImage: "moon.stars.fill")
                Label("Endless mode with a leaderboard", systemImage: "infinity")
                Label("One purchase, no subscription, no ads", systemImage: "checkmark.seal.fill")
            }
            .font(.headline)
            Spacer()
            if store.unlocked {
                Label("Unlocked. Have fun!", systemImage: "checkmark.circle.fill").font(.title3.bold()).foregroundStyle(Palette.sun)
                Button("Done") { dismiss() }.buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    Task { await store.buy() }
                } label: {
                    if store.busy {
                        ProgressView().tint(Palette.ink)
                    } else {
                        store.product.map { Text("Unlock for \($0.displayPrice)") } ?? Text("Unlock")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(store.busy)
                Button("Restore purchases") { Task { await store.restore() } }
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                Button("Not now") { dismiss() }.font(.subheadline).foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background(HomeBackground())
        .alert(store.message ?? "", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}
