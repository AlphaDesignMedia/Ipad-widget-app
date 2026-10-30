import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// PIP'S BOND · plugin v1 (Dream). Pip warms to you through play, like a pet. Taps and head rubs (a finger
// gently circling on Pip) build the bond; time together helps a little; ignoring Pip for days lets it fade.
// Once the bond is strong, Pip becomes your best mate: follows your finger or Pencil around, keeping just
// behind it, and settles nearby when you stop. Follow can also just be switched on.
// Following takes effort: Pip has energy, spends it moving and stops for a rest when tired (with a 😮‍💨 bubble
// if Pip's Emotes is on), then catches up once rested. Speed of earning is a setting (quick by default, for now). Watching touches never takes them from the app.
// Where: the heart button in the plugin bar.

struct PipBond: SandboxPlugin {
    let info = PluginInfo(id: "bond", name: "Pip's Bond", version: "v1", shelf: .dream,
                          icon: "heart", what: "Play with Pip and they warm to you. Best mates follow your finger and Pencil.")

    // MARK: Data

    enum Pace: String, CaseIterable {
        case quick, days, weeks
        var label: String { ["quick": "Quick", "days": "Days", "weeks": "Weeks"][rawValue] ?? rawValue }
        /// Multiplies every gain. Quick: about ten minutes of play to best mates.
        var rate: Double { ["quick": 1, "days": 0.15, "weeks": 0.04][rawValue] ?? 1 }
    }

    enum Gain {
        static let tap = 0.03, rub = 0.06, minuteTogether = 0.01
        static let fadePerDay = 0.12          // ignore Pip and Pip ignores you, slowly
        static let bestMates = 0.75           // following starts here
    }

    enum Lines {
        static let rub = ["Ooh, that's the spot.", "Mmm. Head rubs.", "Keep going. For science."]
        /// Said on reaching each stage of the ladder (BondStage).
        static let stage = ["", "I think I like you.", "We're pals now. Officially.",
                            "Best mates? Best mates. I'll stick with you.", "You're family now. Don't tell the others."]
        /// What each stage opens up, shown in the card.
        static let unlocks = ["Pip says hello", "Pip notices your changes", "Pip leans and wobbles, shares news",
                              "Pip follows your finger and Pencil", "Secrets. Shh."]
        static let follow = ["Wait for me!", "Where are we going?", "Right behind you."]
        static let settle = "I'll sit here. Near you."
        static let tired = ["Phew. Need a sit down.", "You're fast. I'm glass.", "Two minutes. Just two."]
        static let rested = "Right! Where were we?"
    }

    enum Energy {
        static let perMove = 0.035            // each hop after the finger
        static let restBelow = 0.15, readyAbove = 0.6
        static let recoverPerSecond = 0.02    // about 25 seconds from tired to ready
    }

    /// Shows an emoji bubble over Pip, if the Emotes plugin is on. A notification, so neither plugin needs the other.
    static func emote(_ emoji: String) {
        NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: emoji)
    }

    // MARK: Logic

    @MainActor final class Bond {
        var level = 0.0
        var follow = false
        var lastFollow = Date.distantPast
        var lastRub = Date.distantPast
        var rubStart: Date?
        var watcher: BondTouchWatch?
        var energy = 1.0
        var resting = false
        var energyAt = Date.now

        /// Energy recovers with time; call before reading it.
        func recover() {
            energy = min(1, energy + Date.now.timeIntervalSince(energyAt) * Energy.recoverPerSecond)
            energyAt = .now
        }
    }
    private let bond = Bond()

    static func pace(_ host: PipHost) -> Pace { Pace(rawValue: host.value("bond", "pace") ?? "") ?? .quick }

    func start(_ host: PipHost) throws {
        // Fade for days apart, then count time together once a minute.
        var level: Double = host.value("bond", "level") ?? 0
        if let last: Date = host.value("bond", "last") {
            level -= max(0, Date.now.timeIntervalSince(last) / 86_400 - 1) * Gain.fadePerDay
        }
        bond.level = min(max(level, 0), 1)
        bond.follow = host.value("bond", "follow") ?? false
        save(host)
        tickTogether(host)
        install(host)
    }

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .tap: grow(Gain.tap, host)
        case .custom(let name) where name.hasPrefix("bond.grow:"):
            grow(Double(name.dropFirst("bond.grow:".count)) ?? 0, host)
        default: break
        }
    }

    private func tickTogether(_ host: PipHost) {
        host.later(60) {
            if host.isOn("bond"), host.pipHere, !host.pipAsleep { grow(Gain.minuteTogether, host) }
            tickTogether(host)
        }
    }

    fileprivate func grow(_ amount: Double, _ host: PipHost) {
        let before = bond.level
        bond.level = min(1, bond.level + amount * Self.pace(host).rate)
        save(host)
        let stage = BondStage(bond.level)
        if stage > BondStage(before) {
            host.cheer()
            host.say(Lines.stage[stage.rawValue], for: 3)
            host.post(.custom("bond.stage"))
        }
    }

    private func save(_ host: PipHost) {
        host.setValue(bond.level, "bond", "level")
        host.setValue(Date.now, "bond", "last")
    }

    var follows: Bool { bond.follow || bond.level >= Gain.bestMates }

    /// Watches every touch on the window without taking it, to notice rubs and to follow.
    private func install(_ host: PipHost) {
        guard bond.watcher == nil else { return }
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow) else {
            host.later(1) { install(host) }
            return
        }
        let watch = BondTouchWatch()
        watch.onTouch = { phase, point, _ in
            let inset = window.safeAreaInsets
            touched(phase, CGPoint(x: point.x - inset.left, y: point.y - inset.top), host)
        }
        window.addGestureRecognizer(watch)
        bond.watcher = watch
    }

    private func touched(_ phase: UITouch.Phase, _ point: CGPoint, _ host: PipHost) {
        guard host.isOn("bond"), host.pipHere else { return }
        let pip = host.pipPosition
        let near = hypot(point.x - pip.x, point.y - pip.y) < 34
        switch phase {
        case .began:
            bond.rubStart = near ? .now : nil
        case .moved:
            // A rub: a finger moving on Pip for a moment (a grab would fling Pip away instead).
            if near, let start = bond.rubStart, Date.now.timeIntervalSince(start) > 0.5,
               Date.now.timeIntervalSince(bond.lastRub) > 1.2 {
                bond.lastRub = .now
                grow(Gain.rub, host)
                if Int.random(in: 0..<3) == 0, let line = Lines.rub.randomElement() { host.say(line, for: 1.4) }
            }
            // Best mates follow, keeping just behind and below the finger, never on it.
            bond.recover()
            if bond.resting, bond.energy >= Energy.readyAbove {
                bond.resting = false
                host.say(Lines.rested, for: 1.4)
            }
            if follows, !near, !bond.resting, Date.now.timeIntervalSince(bond.lastFollow) > 0.35, !host.pipAsleep {
                bond.lastFollow = .now
                bond.energy -= Energy.perMove
                if bond.energy < Energy.restBelow {
                    bond.resting = true
                    Self.emote("😮‍💨")
                    if let line = Lines.tired.randomElement() { host.say(line, for: 1.8) }
                    return
                }
                host.move(to: CGPoint(x: point.x - 46, y: point.y + 40))
                if Int.random(in: 0..<40) == 0, let line = Lines.follow.randomElement() { host.say(line, for: 1.2) }
            }
        default:
            bond.rubStart = nil
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { BondCard(plugin: self, host: host) }

    struct BondCard: View {
        let plugin: PipBond
        let host: PipHost
        @State private var level = 0.0
        @State private var pace = Pace.quick
        @State private var follow = false
        @State private var all = false

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(Color.primary.opacity(0.1), lineWidth: 6)
                        Circle().trim(from: 0, to: level)
                            .stroke(PipLook.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: level >= Gain.bestMates ? "heart.fill" : "heart")
                            .foregroundStyle(PipLook.accent)
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).bold()
                        Text("Taps and head rubs help. Days apart fade it a little.").foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue("\(Int(level * 100)) percent")

                ForEach(BondStage.allCases.dropFirst(), id: \.self) { stage in
                    let reached = BondStage(level) >= stage
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: reached ? "checkmark.circle.fill" : "lock")
                            .foregroundStyle(reached ? PipLook.accent : .secondary)
                        Text(stage.name).bold()
                        Text(Lines.unlocks[stage.rawValue]).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(reached ? "Unlocked" : "Locked")
                }
                Toggle("Unlock everything", isOn: $all)
                    .onChange(of: all) { _, v in host.setValue(v, "bond", "all") }

                Text("How fast Pip warms up").bold()
                HStack(spacing: 6) {
                    ForEach(Pace.allCases, id: \.self) { p in
                        Button(p.label) {
                            pace = p
                            host.setValue(p.rawValue, "bond", "pace")
                        }
                        .buttonStyle(PluginCardButton(on: pace == p))
                        .accessibilityAddTraits(pace == p ? .isSelected : [])
                    }
                }
                Toggle("Follow me anyway", isOn: $follow)
                    .onChange(of: follow) { _, v in
                        plugin.bond.follow = v
                        host.setValue(v, "bond", "follow")
                    }
                Button("Start over") {
                    plugin.bond.level = 0
                    host.setValue(0.0, "bond", "level")
                    level = 0
                }
                .buttonStyle(PluginCardButton())
            }
            .font(.system(size: 13.5))
            .onAppear {
                level = plugin.bond.level
                all = host.value("bond", "all") ?? false
                pace = PipBond.pace(host)
                follow = plugin.bond.follow
            }
        }

        private var title: String { BondStage(level).name }
    }
}

/// Hears every touch on the window and lets it through untouched. It never recognises, so it never
/// gets in the way of the app's own gestures.
final class BondTouchWatch: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onTouch: ((UITouch.Phase, CGPoint, UITouch.TouchType) -> Void)?

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    private func report(_ touches: Set<UITouch>, _ phase: UITouch.Phase) {
        guard let t = touches.first else { return }
        onTouch?(phase, t.location(in: view), t.type)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { report(touches, .began) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { report(touches, .moved) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches, .ended)
        state = .failed
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        report(touches, .cancelled)
        state = .failed
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
