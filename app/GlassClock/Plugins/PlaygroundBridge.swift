import SwiftUI
import UIKit

// PIP'S PLAYGROUND · bridge plugin v1 (On trial). Connects the plugin agent's Playground
// (app/GlassClock/Playground/: Joy Slider and Idle Life, first written on the pip-plugins branch) to Pip
// and the plugin bar. Idle Life notices touches anywhere; Pip acts out its idle acts with a line or a move.
// Where: the slider button in the plugin bar. A bridge for now: the aim is one plugin system (see AGENT-NOTES.md).

struct PlaygroundBridge: SandboxPlugin {
    let info = PluginInfo(id: "playground", name: "Pip's Playground", version: "v1", shelf: .trial,
                          icon: "slider.horizontal.3", what: "The plugin agent's Joy Slider and Idle Life, acted out by Pip.")

    // MARK: Data

    /// Pip's line for each idle act. Placeholders until the plugin agent writes Pip's voice for them.
    static func line(_ act: IdleAct) -> String? {
        switch act {
        case .yawn: "Yaaawn."
        case .hum: "Hm hm hmm."
        case .tap, .knock: "Tap tap. Anyone there?"
        case .minute: "Ooh, the minute changed."
        case .sleepTalk: "…five more minutes…"
        case .look, .blink, .spin, .lap, .peek, .doze: nil
        }
    }
    static let welcome = "Oh! You're back."

    @MainActor final class Session { var listening = false }
    private let session = Session()

    // MARK: Logic

    func start(_ host: PipHost) throws {
        IdleLife.shared.reduceMotion = host.simpler
        IdleLife.shared.start()
        guard !session.listening else { return }
        session.listening = true
        Playground.shared.listen { event in
            guard host.isOn("playground") else { return }
            switch event {
            case .idleAct(let act): Self.act(act, host)
            case .welcomeBack: host.say(Self.welcome, for: 1.8)
            default: break
            }
        }
    }

    /// Spins are a cheer; laps and peeks are a short trip and back (skipped under simpler motion); the rest are lines.
    static func act(_ act: IdleAct, _ host: PipHost) {
        guard host.pipHere, !host.pipAsleep else { return }
        switch act {
        case .spin: host.cheer()
        case .lap, .peek:
            guard !host.simpler else { return }
            let home = host.pipPosition
            host.move(to: CGPoint(x: home.x + .random(in: -160...160), y: home.y + .random(in: -100...100)))
            host.later(3) { host.move(to: home) }
        default:
            if let line = line(act) { host.say(line, for: 2) }
        }
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { TouchWatcher().frame(width: 0, height: 0).allowsHitTesting(false) }
    func card(_ host: PipHost) -> some View { Panel() }

    /// The Playground's controls in the plugin card: the Joy Slider, its plugins' switches and the idle test buttons.
    struct Panel: View {
        @State private var playground = Playground.shared
        @State private var idle = IdleLife.shared

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                JoySliderView()
                ForEach(playground.plugins) { p in
                    Toggle(isOn: Binding(get: { playground.isOn(p.id) }, set: { playground.setOn(p.id, $0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).bold()
                            Text(p.blurb).foregroundStyle(.secondary)
                        }
                    }
                }
                if playground.isOn(IdleLife.plugin.id) {
                    Text("Idle: \(idle.stage.name). Last: \(idle.lastAct?.caption ?? "nothing yet")")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach([1, 3, 15], id: \.self) { minutes in
                            Button("\(minutes) min") { idle.pretend(idleFor: Double(minutes * 60)) }
                                .buttonStyle(PluginCardButton())
                                .accessibilityLabel("Pretend nobody touched the screen for \(minutes) minutes")
                        }
                    }
                }
            }
            .font(.system(size: 13.5))
        }
    }

    /// Tells Idle Life about every touch in the window. It never takes a touch: it gives up the moment one starts.
    struct TouchWatcher: UIViewRepresentable {
        func makeUIView(context: Context) -> WatcherView { WatcherView() }
        func updateUIView(_ v: WatcherView, context: Context) {}
    }

    final class WatcherView: UIView {
        private let watcher = Toucher()
        override func didMoveToWindow() {
            super.didMoveToWindow()
            watcher.view?.removeGestureRecognizer(watcher)
            window?.addGestureRecognizer(watcher)
        }
    }

    final class Toucher: UIGestureRecognizer {
        init() {
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesEnded = false
            requiresExclusiveTouchType = false
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            IdleLife.shared.touched()
            state = .failed
        }
        override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }
    }
}
