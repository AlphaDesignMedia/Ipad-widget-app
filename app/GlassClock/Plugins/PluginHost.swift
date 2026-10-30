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
    /// The plugin whose card is open in the plugin bar.
    var openCard: String?
    /// Pip's own switch (Settings > Accessibility > Pip), kept up to date by PipLayer.
    var pipOn = true
    /// Where the open panel is, in window space, so an overlay that takes touches (Sketch) can leave it
    /// alone. Only its edge while it's tucked aside; null when no panel is open.
    @ObservationIgnored var panelFrame = CGRect.null
    /// How lively plugins should be: 0 still, 1 calm (the default), 2 cosy, 3 playful, 4 giddy, 5 unhinged.
    /// One setting for every plugin; the Joy Slider sets it. Read `joy`, which respects simpler motion.
    var joySetting = UserDefaults.standard.object(forKey: "pipJoy") as? Int ?? 1 {
        didSet { store.set(joySetting, forKey: "pipJoy") }
    }

    @ObservationIgnored private let store = UserDefaults.standard
    @ObservationIgnored private var launched = false

    private init() {
        off = Set(UserDefaults.standard.stringArray(forKey: "plugsOff") ?? [])
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

    func isOn(_ id: String) -> Bool { !off.contains(id) && broken[id] == nil }

    func setOn(_ id: String, _ on: Bool) {
        if on {
            off.remove(id)
            if let p = plugins.first(where: { $0.info.id == id }), broken[id] == nil { begin(p) }
        } else {
            off.insert(id)
            if openCard == id { openCard = nil }
        }
        store.set(Array(off), forKey: "plugsOff")
    }

    private func begin(_ p: any SandboxPlugin) {
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
