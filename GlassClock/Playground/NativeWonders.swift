import SwiftUI
import CoreMotion

// Native Wonders: things the iPad can do now that Glass Clock runs natively, which the web
// sandbox couldn't. One big wow (Liquid Time) and a handful of fun extras. Each one has a
// "How it works" note naming the Apple framework behind it, so it doubles as a lesson.

enum Wonder: String, CaseIterable, Identifiable {
    case liquidTime, pipLook, pencil, speakingClock, battery, postcard

    var id: String { rawValue }

    var name: String {
        switch self {
        case .liquidTime: "Liquid Time"
        case .pipLook: "Pip in 3D"
        case .pencil: "Pip Sees Your Pencil"
        case .speakingClock: "The Speaking Clock"
        case .battery: "Pip Feels the Battery"
        case .postcard: "Pip Postcard"
        }
    }
    var icon: String {
        switch self {
        case .liquidTime: "🌊"
        case .pipLook: "👀"
        case .pencil: "✏️"
        case .speakingClock: "📞"
        case .battery: "🔋"
        case .postcard: "💌"
        }
    }
    var blurb: String {
        switch self {
        case .liquidTime: "The clock fills with water. Tilt your iPad and it sloshes. Pip floats."
        case .pipLook: "Pip looks around: eyes first, head after. A detail dial goes from flat to full 3D."
        case .pencil: "Hover your Pencil and Pip watches it. Squeeze it and Pip jumps."
        case .speakingClock: "Pip reads the time out loud, then the six pips."
        case .battery: "Pip knows how much charge you've got, and whether it's plugged in."
        case .postcard: "Turn the clock and Pip into a picture and send it to anyone."
        }
    }
    /// The lesson: which native framework does this, in one plain sentence.
    var howItWorks: String {
        switch self {
        case .liquidTime: "CoreMotion reads the iPad's gravity 60 times a second. A tiny spring makes the water lag and overshoot, and Canvas draws it each frame. Browsers block motion; native apps don't."
        case .pipLook: "Layers at different depths slide by different amounts (parallax), and rotation3DEffect turns the head. Two springs, a fast one for the eyes and a slow one for the head, make the look feel alive. It's the video-game trick: the cheapest thing that reads as 3D."
        case .pencil: "SwiftUI's onContinuousHover tracks a Pencil hovering above the screen, and onPencilSqueeze hears a squeeze on Pencil Pro."
        case .speakingClock: "AVSpeechSynthesizer speaks in a British voice, and AVAudioEngine makes the pips from a pure sine wave. There are no sound files."
        case .battery: "UIDevice reports the battery level and charging state. It's private, on-device and needs no permission."
        case .postcard: "ImageRenderer turns any SwiftUI view into a picture, and ShareLink opens the system share sheet: AirDrop, Messages, anything."
        }
    }
    var isTheWow: Bool { self == .liquidTime }

    static let plugin = PlaygroundPlugin(
        id: "wonders", name: "Native Wonders", icon: "✨", shelf: .dream,
        blurb: "Things the iPad can do now the app is native. Start with Liquid Time.")
}

/// The list of wonders. The big one sits at the top.
struct NativeWondersView: View {
    @State private var open: Wonder?

    var body: some View {
        List {
            Section {
                WonderCard(wonder: .liquidTime, big: true) { open = .liquidTime }
            } footer: {
                Text("Best on a real iPad. In the Simulator, drag to tilt.")
            }
            Section("Little wonders") {
                ForEach(Wonder.allCases.filter { !$0.isTheWow }) { wonder in
                    WonderCard(wonder: wonder, big: false) { open = wonder }
                }
            }
        }
        .navigationTitle("✨ Native Wonders")
        .fullScreenCover(item: $open) { wonder in
            WonderScreen(wonder: wonder) { open = nil }
        }
    }
}

private struct WonderCard: View {
    let wonder: Wonder
    let big: Bool
    let action: () -> Void
    @State private var showsHow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: action) {
                HStack(spacing: 14) {
                    Text(wonder.icon).font(.system(size: big ? 54 : 32)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wonder.name).font(big ? .title2.bold() : .headline)
                        Text(wonder.blurb).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens it full screen.")
            DisclosureGroup("How it works", isExpanded: $showsHow) {
                Text(wonder.howItWorks).font(.footnote).foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
        .padding(.vertical, big ? 8 : 2)
    }
}

/// Full screen, with a close button that's always there.
private struct WonderScreen: View {
    let wonder: Wonder
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch wonder {
            case .liquidTime: LiquidTimeView()
            case .pipLook: PipLookWonder()
            case .pencil: PencilWonder()
            case .speakingClock: SpeakingClockWonder()
            case .battery: BatteryWonder()
            case .postcard: PostcardWonder()
            }
            Button(action: close) {
                Image(systemName: "xmark").font(.title3.bold()).frame(width: 48, height: 48)
            }
            .buttonStyle(.glass)
            .padding(20)
            .accessibilityLabel("Close")
        }
    }
}

/// Gravity, in screen directions (x right, y down), from CoreMotion. Not observed: views
/// read it each frame. Falls back to a gentle sway where there's no motion sensor.
final class MotionSource {
    private let manager = CMMotionManager()
    private var raw = CMAcceleration(x: 0, y: -1, z: 0)
    /// Set by the view, which can see the window's orientation.
    var orientation: UIInterfaceOrientation = .portrait
    /// Set while dragging to tilt by hand (Simulator, or anyone without a sensor).
    var manual: CGVector?
    var hasSensor: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            if let g = motion?.gravity { self?.raw = g }
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }

    /// Which way is down on screen, as a vector (roughly unit length when upright).
    func gravity(at time: Double) -> CGVector {
        if let manual { return manual }
        guard hasSensor else {
            return CGVector(dx: sin(time * 0.5) * 0.35, dy: 1)
        }
        let g = raw
        switch orientation {
        case .portraitUpsideDown: return CGVector(dx: -g.x, dy: g.y)
        case .landscapeLeft: return CGVector(dx: g.y, dy: g.x)
        case .landscapeRight: return CGVector(dx: -g.y, dy: -g.x)
        default: return CGVector(dx: g.x, dy: -g.y)
        }
    }

    @MainActor static func currentOrientation() -> UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.effectiveGeometry.interfaceOrientation ?? .portrait
    }
}
