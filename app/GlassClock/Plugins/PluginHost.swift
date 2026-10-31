import SwiftUI

// The plugin host for the Pip Sandbox app: the native twin of the web sandbox's host.js (window.PipHost).
// Plugins are Swift files in this folder, listed in Plugins.swift. How to write one: app/PLUGIN-SPEC.md.

// MARK: Data

struct PluginInfo {
    let id: String          // short and unique, e.g. "remembers"; also its storage prefix, "plug.remembers."
    let name: String
    let version: String     // "v1"
    let shelf: PluginShelf
    let icon: String        // an SF Symbol name, e.g. "book.closed"
    let what: String        // one line, shown in Settings
    var panel = false       // true: its card opens as a panel at the side, like the app's settings (PluginPanel)
}

enum PluginShelf: String, CaseIterable, Identifiable {
    case dream, grounded, trial
    var id: Self { self }
    var label: String {
        switch self {
        case .dream: "Dream"
        case .grounded: "Grounded"
        case .trial: "On trial"
        }
    }
}

/// What Pip tells plugins. The web sandbox's events (pip:tap and so on) that the app has so far.
enum PipEvent: Equatable {
    case appear                 // Pip is on screen: at launch, or after the first meeting
    case wake                   // woken from sleep
    case tap                    // tapped while awake
    case flick(speed: Double)   // let go with a flick, in points per second
    case bump(speed: Double)    // hit an edge of the screen
    case rest                   // came to rest after a glide
    case ink(InkEvent)          // something happened in the drawing (Sketch posts these; Wonders answers them)
    case custom(String)         // a plugin's own message, e.g. "desk.reviewed", for trying things out;
                                // anything that sticks gets its own case here
}

/// What the drawing tells other plugins. Points are in Pip's space.
enum InkEvent: Equatable {
    case pencil(CGPoint)        // where the Apple Pencil is, hovering or drawing (not over a panel or Pip)
    case drew(InkMark)          // a stroke was finished
    case erased                 // the eraser took something away
    case cleared                // a fresh page
}

/// A finished stroke, described for plugins that answer drawings.
struct InkMark: Equatable {
    var box: CGRect
    var length: Double          // points along the line
    var seconds: Double         // how long it took to draw
    var closed: Bool            // it ends near where it began: a loop
    var onPip: Bool             // drawn over Pip
    var ringsPip: Bool          // a loop around Pip
}

/// A plugin's restyle of the plugin bar: the gap between buttons, the bar around them, and each button
/// around its icon (given whether its card is open). With `wholeApp`, the app's own buttons (the settings rail)
/// become drops too, `gap` apart, running together when nearer than `merge`.
struct BarLook {
    let owner: String
    var gap: CGFloat
    var merge: CGFloat = 6
    var wholeApp = false
    var bar: @MainActor (AnyView) -> AnyView
    var button: @MainActor (AnyView, Bool) -> AnyView
}

/// How close you and Pip are, as a ladder over one number, 0...1 (like an old game's friendship byte).
/// Pip's Bond keeps the number; plugins read `host.stage` or ask `host.unlocked(.pal)` to open up as you go.
enum BondStage: Int, CaseIterable, Comparable {
    case stranger, friendly, pal, bestMate, family
    static let starts = [0, 0.25, 0.5, 0.75, 0.95]
    init(_ level: Double) { self = Self.allCases.last { Self.starts[$0.rawValue] <= level } ?? .stranger }
    var name: String { ["Stranger", "Friendly", "Pal", "Best mate", "Family"][rawValue] }
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

// MARK: The plugin shape

/// Everything is optional except `info`. Data first, logic second, views last: they port to
/// Glass Clock (and the web) more easily that way.
@MainActor protocol SandboxPlugin {
    associatedtype Overlay: View = EmptyView
    associatedtype Card: View = EmptyView
    associatedtype AddOn: View = EmptyView
    var info: PluginInfo { get }
    /// Runs at launch and whenever the plugin is switched on. Throw to be switched off, with your error shown in Settings.
    func start(_ host: PipHost) throws
    /// Pip's events, while the plugin is on.
    func on(_ event: PipEvent, _ host: PipHost)
    /// Drawn over the whole app, under Pip. Only what you draw takes touches: keep it small, or use .allowsHitTesting(false).
    @ViewBuilder func overlay(_ host: PipHost) -> Overlay
    /// The card that opens from the plugin's button in the plugin bar. Leave it out for no button.
    @ViewBuilder func card(_ host: PipHost) -> Card
    /// The id of a plugin whose panel gets a section from this one (Wonders adds to "sketch"), or nil.
    var addsTo: String? { get }
    /// That section's rows. It shows under the panel's own cards, titled with this plugin's name and icon.
    @ViewBuilder func addOn(_ host: PipHost) -> AddOn
}

extension SandboxPlugin {
    func start(_ host: PipHost) throws {}
    func on(_ event: PipEvent, _ host: PipHost) {}
    var addsTo: String? { nil }
    var hasCard: Bool { ObjectIdentifier(Card.self) != ObjectIdentifier(EmptyView.self) }
    var hasAddOn: Bool { ObjectIdentifier(AddOn.self) != ObjectIdentifier(EmptyView.self) }
    // For the host, which holds plugins of every type in one list.
    func anyOverlay(_ host: PipHost) -> AnyView { AnyView(overlay(host)) }
    func anyCard(_ host: PipHost) -> AnyView { AnyView(card(host)) }
    func anyAddOn(_ host: PipHost) -> AnyView { AnyView(addOn(host)) }
}

extension SandboxPlugin where Overlay == EmptyView {
    func overlay(_ host: PipHost) -> EmptyView { EmptyView() }
}

extension SandboxPlugin where Card == EmptyView {
    func card(_ host: PipHost) -> EmptyView { EmptyView() }
}

extension SandboxPlugin where AddOn == EmptyView {
    func addOn(_ host: PipHost) -> EmptyView { EmptyView() }
}

// MARK: The host

@MainActor @Observable
final class PipHost {
    static let shared = PipHost()

    let pip = PipModel()
    let plugins: [any SandboxPlugin] = Plugins.all
    /// Ids switched off in Settings, kept under "plugsOff" (the web keeps gs2-pluginsOff).
    private(set) var off: Set<String>
    /// Plugins the host switched off itself, with the reason, shown in Settings.
    private(set) var broken: [String: String] = [:]
    /// Every plugin paused at once, with each one's own switch kept: the one-tap fix when something misbehaves
    /// (Aaron, 31 Oct 2026). Kept under "plugsPaused".
    private(set) var paused: Bool
    /// True when the app stopped last time while it was open (a crash, or a freeze iPadOS ended), so this
    /// launch started with every plugin paused. Settings and the bar say so.
    private(set) var safeMode = false
    /// The plugin whose card is open in the plugin bar.
    var openCard: String?
    /// Pip's own switch (Settings > Accessibility > Pip), kept up to date by PipLayer.
    var pipOn = true
    /// Where the open panel is, in window space, so an overlay that takes touches (Sketch) can leave it
    /// alone. Only its edge while it's tucked aside; null when no panel is open.
    @ObservationIgnored var panelFrame = CGRect.null
    /// Where the plugin bar and its open pop-up card are, in window space; null when hidden.
    @ObservationIgnored var barFrame = CGRect.null
    @ObservationIgnored var cardFrame = CGRect.null
    /// True where the panel, the bar or an open card is: those always get taps first, so an overlay that
    /// draws (Sketch) never starts there.
    func keepsTaps(_ window: CGPoint) -> Bool {
        [panelFrame, barFrame, cardFrame].contains { !$0.isNull && $0.insetBy(dx: -12, dy: -12).contains(window) }
    }
    /// A plugin's own look for the plugin bar (Liquid Icons sets one in `start`). Used only while its owner is on;
    /// nil: the shared glass bar.
    var barLook: BarLook?
    /// The bar look, while its owner is on.
    /// (Its owner's own switch, not whether it's running, so the look holds steady while plugins are paused.)
    var activeBarLook: BarLook? { barLook.flatMap { chosen($0.owner) ? $0 : nil } }
    /// How lively plugins should be: 0 still, 1 calm (the default), 2 cosy, 3 playful, 4 giddy, 5 unhinged.
    /// One setting for every plugin; the Joy Slider sets it. Read `joy`, which respects simpler motion.
    var joySetting = UserDefaults.standard.object(forKey: "pipJoy") as? Int ?? 1 {
        didSet { store.set(joySetting, forKey: "pipJoy") }
    }

    @ObservationIgnored private let store = UserDefaults.standard
    @ObservationIgnored private var launched = false
    /// Plugins whose `start` has run this launch, so un-pausing starts only the ones that haven't.
    @ObservationIgnored private var started = Set<String>()
    /// True while the app is open; cleared when it goes to the background. Still true at launch means the app
    /// stopped while it was open.
    nonisolated private static let openKey = "plugsOpen"

    private init() {
        off = Set(UserDefaults.standard.stringArray(forKey: "plugsOff") ?? [])
        paused = UserDefaults.standard.bool(forKey: "plugsPaused")
        // Stopped while open last time: start calm, with every plugin paused, rather than straight back into it.
        if store.bool(forKey: Self.openKey) {
            paused = true
            safeMode = true
            store.set(true, forKey: "plugsPaused")
        }
        store.set(true, forKey: Self.openKey)
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            UserDefaults.standard.set(false, forKey: PipHost.openKey)
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            UserDefaults.standard.set(true, forKey: PipHost.openKey)
        }
        // One that stopped the app while starting last time stays off.
        if let id = store.string(forKey: "plugStarting") {
            store.removeObject(forKey: "plugStarting")
            switchOff(id, because: "It stopped the app while starting, so it was switched off.")
        }
        var seen = Set<String>()
        for p in plugins where !seen.insert(p.info.id).inserted {
            broken[p.info.id] = "Two plugins use the id \"\(p.info.id)\". Give one of them a new id."
        }
        pip.onEvent = { [weak self] event in self?.send(event) }
    }

    /// Starts the plugins that are on. PipLayer calls this once, when the app appears.
    func launch() {
        guard !launched else { return }
        launched = true
        for p in plugins where isOn(p.info.id) { begin(p) }
    }

    func isOn(_ id: String) -> Bool { !paused && chosen(id) }
    /// The plugin's own switch (on, and not switched off by the host), whether or not everything is paused.
    func chosen(_ id: String) -> Bool { !off.contains(id) && broken[id] == nil }

    /// Pauses every plugin, or brings back the ones that are switched on. Each plugin's own switch is kept.
    func setPaused(_ on: Bool) {
        paused = on
        safeMode = false
        store.set(on, forKey: "plugsPaused")
        if on {
            openCard = nil
        } else if launched {
            for p in plugins where isOn(p.info.id) && !started.contains(p.info.id) { begin(p) }
        }
    }

    func setOn(_ id: String, _ on: Bool) {
        if on {
            off.remove(id)
            if !paused, let p = plugins.first(where: { $0.info.id == id }), broken[id] == nil { begin(p) }
        } else {
            off.insert(id)
            if openCard == id { openCard = nil }
        }
        store.set(Array(off), forKey: "plugsOff")
    }

    private func begin(_ p: any SandboxPlugin) {
        started.insert(p.info.id)
        store.set(p.info.id, forKey: "plugStarting")
        do { try p.start(self) } catch {
            switchOff(p.info.id, because: "It couldn't start: \(error.localizedDescription)")
        }
        store.removeObject(forKey: "plugStarting")
    }

    private func switchOff(_ id: String, because reason: String) {
        off.insert(id)
        broken[id] = reason
        store.set(Array(off), forKey: "plugsOff")
    }

    private func send(_ event: PipEvent) {
        for p in plugins where isOn(p.info.id) { p.on(event, self) }
    }

    // MARK: Pip, for plugins

    var simpler: Bool { pip.simpler }       // reduced motion: fade, don't move
    var pipHere: Bool { pipOn && pip.shown }
    var pipAsleep: Bool { pip.asleep }
    var pipPosition: CGPoint { pip.pos }    // in the app's full-screen space (inside the safe area)
    /// The Joy level to use, 0...5: the setting, never above cosy (2) when motion is simpler.
    var joy: Int { min(max(simpler ? min(joySetting, 2) : joySetting, 0), 5) }

    /// Pip says a line. Returns false, and shows nothing, when Pip is switched off or not on screen yet.
    @discardableResult func say(_ line: String, for seconds: Double = 2.4) -> Bool {
        guard pipHere else { return false }
        pip.say(line, for: seconds)
        return true
    }

    func wake() { if pipHere, pip.asleep { pip.wake() } }
    /// Happy eyes and a little hop (just the eyes when motion is simpler).
    func cheer() { if pipHere { pip.cheer() } }
    /// Pip glides to a point; under simpler motion it fades there instead.
    func move(to point: CGPoint) { if pipHere { pip.go(to: point) } }
    /// Pip trails just above and to the left of a point, and settles a moment after the point stops
    /// coming. Call it as the point moves. Nothing while Pip is asleep or held, or when motion is simpler.
    func follow(_ point: CGPoint) { if pipHere { pip.follow(point) } }
    /// Pip pulls a face for a moment: .surprised, .curious, .shy or .sleepy (any PipFace works).
    func react(_ face: PipFace, for seconds: Double = 1.2) { if pipHere, !pipAsleep { pip.react(face, for: seconds) } }
    /// Pip's eyes turn towards a point (in Pip's space), then drift back to the middle.
    func lookAt(_ point: CGPoint) { if pipHere, !pipAsleep { pip.lookAt(point) } }
    /// Pip's halo takes a colour for a moment, then fades back to Pip's own.
    func blush(_ color: Color, for seconds: Double = 3) {
        guard pipHere else { return }
        withAnimation(.easeInOut(duration: 0.6)) { pip.halo = color }
        later(seconds) { [pip] in withAnimation(.easeInOut(duration: 1.2)) { pip.halo = nil } }
    }

    // MARK: The bond, for plugins

    var bond: Double { value("bond", "level") ?? 0 }
    var stage: BondStage { BondStage(bond) }
    /// True once you and Pip are this close. Always true with Pip's Bond off, or "Unlock everything" on,
    /// so nothing is ever kept from you.
    func unlocked(_ needs: BondStage) -> Bool {
        !isOn("bond") || value("bond", "all") == true || stage >= needs
    }
    /// A small gift to the bond, for something you did together (a tutorial step, a change Pip noticed).
    /// Pip's Bond counts it, at its own pace.
    func befriend(_ amount: Double = 0.02) { send(.custom("bond.grow:\(amount)")) }

    // MARK: Plugins, for plugins

    /// Tells every plugin that's on, the same way Pip's own events arrive in `on(_:_:)`.
    func post(_ event: PipEvent) { send(event) }

    // MARK: Storage, for plugins

    /// Plugin settings live under "plug.<id>.<key>". In views, @AppStorage("plug.<id>.<key>") reads the same value.
    func value<T>(_ plugin: String, _ key: String) -> T? { store.object(forKey: "plug.\(plugin).\(key)") as? T }
    func setValue(_ value: Any?, _ plugin: String, _ key: String) { store.set(value, forKey: "plug.\(plugin).\(key)") }
    /// Wipes everything a plugin has kept.
    func forget(_ plugin: String) {
        for key in store.dictionaryRepresentation().keys where key.hasPrefix("plug.\(plugin).") { store.removeObject(forKey: key) }
    }

    // MARK: Time

    /// Runs `work` after a pause. Fine for a line or two; keep anything longer in your own Task.
    func later(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            work()
        }
    }
}
