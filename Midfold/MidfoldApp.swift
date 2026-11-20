import SwiftUI

enum Game: String, Identifiable, CaseIterable {
    case flight, lock, quickDraw, tug, oddSpot
    var id: String { rawValue }

    var isFoldGame: Bool { self == .flight || self == .lock }

    var title: LocalizedStringKey {
        switch self {
        case .flight: "Fold Flight"
        case .lock: "Angle Lock"
        case .quickDraw: "Quick Draw"
        case .tug: "Tug Line"
        case .oddSpot: "Odd Spot"
        }
    }

    var blurb: LocalizedStringKey {
        switch self {
        case .flight: "Steer a paper glider through the gaps by opening and closing the phone."
        case .lock: "Hit eight target angles and hold steady. Beat your best time."
        case .quickDraw: "Wait for the signal, then tap first. Too early and the point goes across."
        case .tug: "Tap like mad to pull the knot over the fold to your side."
        case .oddSpot: "Find the one symbol that is different before your rival does."
        }
    }

    var symbol: String {
        switch self {
        case .flight: "paperplane.fill"
        case .lock: "dial.medium.fill"
        case .quickDraw: "bolt.fill"
        case .tug: "arrow.left.and.right"
        case .oddSpot: "eye.fill"
        }
    }

    var tint: Color {
        switch self {
        case .flight: Color(red: 0.36, green: 0.62, blue: 1.0)
        case .lock: Color(red: 0.55, green: 0.42, blue: 1.0)
        case .quickDraw: Color(red: 1.0, green: 0.42, blue: 0.36)
        case .tug: Color(red: 1.0, green: 0.62, blue: 0.20)
        case .oddSpot: Color(red: 0.20, green: 0.78, blue: 0.62)
        }
    }
}

final class AppState: ObservableObject {
    @Published var playing: Game?
    @Published var showSettings = false
    let hinge = HingeModel()
}

@main
struct MidfoldApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(state)
                .environmentObject(state.hinge)
                .modifier(HingeReader(model: state.hinge))
                .preferredColorScheme(.dark)
                .task {
                    if ProcessInfo.processInfo.arguments.contains("-shots") {
                        await ShotsTour(state: state).run()
                    }
                }
        }
    }
}
