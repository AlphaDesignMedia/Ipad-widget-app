import SwiftUI

// Pip's Playground: the plugin layer.
//
// The real app is the solid core. Everything in this folder is extra joy, added on top as
// plugins, and every one can be switched off without changing the app underneath.
// Nothing here is wired into the app's screens yet: the host app adds `PlaygroundPanel`
// wherever it wants it, and listens to `Playground.shared` for events.
//
// How this works (Swift idea: protocols): each plugin promises the same few facts
// (an id, a name, an icon, a shelf), so the playground can list, switch and save them all
// the same way without knowing what any of them do.

/// How finished a plugin is. Ideas climb these rungs one at a time (see WAY-OF-WORKING.md).
enum PlaygroundShelf: Int, CaseIterable, Comparable {
    case dream, trial, grounded, core

    var name: String {
        switch self {
        case .dream: "Dream"
        case .trial: "Trial"
        case .grounded: "Grounded"
        case .core: "Core"
        }
    }
    var emoji: String {
        switch self {
        case .dream: "☁️"
        case .trial: "🧪"
        case .grounded: "🌱"
        case .core: "🏛️"
        }
    }
    /// Plugins on these shelves start switched on; Dream and Trial wait to be tried.
    var onByDefault: Bool { self >= .grounded }

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// What every plugin promises. Data only: the plugin's behaviour lives in its own type.
struct PlaygroundPlugin: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let shelf: PlaygroundShelf
    /// One plain sentence: what it does.
    let blurb: String
}

/// Things that happen, which any plugin (or Pip) can react to.
enum PlaygroundEvent: Equatable {
    case joyChanged(JoyLevel)
    case idleStage(IdleStage)
    case idleAct(IdleAct)
    case welcomeBack(awaySeconds: Int)
    case touched
    case say(String)
}

/// Grounded: the app is exactly the real app, plus only the plugins promoted to Grounded.
/// Playground: everything being tried runs too.
enum PlaygroundMode: String, CaseIterable {
    case grounded, playground
}

/// The one place plugins register, get switched on and off, and send each other events.
@Observable @MainActor
final class Playground {
    static let shared = Playground()

    private(set) var plugins: [PlaygroundPlugin] = []
    private var switchedOn: Set<String>
    /// Shelves Aaron has moved plugins to, by id. Overrides the shelf each plugin ships with.
    private var movedTo: [String: Int]
    /// Grounded by default: the app opens as the real app, and the joy is one switch away.
    var mode: PlaygroundMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.keyPrefix + "mode") }
    }
    @ObservationIgnored private var listeners: [(PlaygroundEvent) -> Void] = []
    @ObservationIgnored private let defaults: UserDefaults

    /// Saved keys all start with this, so the playground never collides with the real app.
    static let keyPrefix = "playground."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        switchedOn = Set(defaults.stringArray(forKey: Self.keyPrefix + "on") ?? [])
        movedTo = defaults.dictionary(forKey: Self.keyPrefix + "shelves") as? [String: Int] ?? [:]
        mode = PlaygroundMode(rawValue: defaults.string(forKey: Self.keyPrefix + "mode") ?? "") ?? .grounded
        register(JoyLevel.plugin)
        register(IdleLife.plugin)
        register(PipVoice.plugin)
        register(IdleScene.plugin)
        if Pib.shared.state != .gone { register(Pib.plugin) }
    }

    /// Starts every plugin's brain. Called once, by `PlaygroundOverlay`.
    static func boot(reduceMotion: Bool) {
        IdleLife.shared.reduceMotion = reduceMotion
        IdleLife.shared.start()
        PipVoice.shared.start()
        IdleScenes.shared.start()
        Pib.shared.arrive()
    }

    func register(_ plugin: PlaygroundPlugin) {
        guard !plugins.contains(where: { $0.id == plugin.id }) else { return }
        plugins.append(plugin)
        let seenKey = Self.keyPrefix + "seen." + plugin.id
        if !defaults.bool(forKey: seenKey) {
            defaults.set(true, forKey: seenKey)
            if plugin.shelf.onByDefault { setOn(plugin.id, true) }
        }
    }

    /// Switched on *and* allowed to run in the current mode. Plugins check this, not `isOn`.
    func isOn(_ id: String) -> Bool {
        guard switchedOn.contains(id), let plugin = plugins.first(where: { $0.id == id }) else { return false }
        return mode == .playground || shelf(of: plugin) >= .grounded
    }

    /// The switch alone, as shown in the panel.
    func isSwitchedOn(_ id: String) -> Bool { switchedOn.contains(id) }

    func shelf(of plugin: PlaygroundPlugin) -> PlaygroundShelf {
        movedTo[plugin.id].flatMap(PlaygroundShelf.init(rawValue:)) ?? plugin.shelf
    }

    /// Moves a plugin up or down a shelf. Moving to Grounded is how a tried thing "moves over".
    func move(_ plugin: PlaygroundPlugin, to shelf: PlaygroundShelf) {
        movedTo[plugin.id] = shelf == plugin.shelf ? nil : shelf.rawValue
        defaults.set(movedTo, forKey: Self.keyPrefix + "shelves")
    }

    func unregister(_ id: String) { plugins.removeAll { $0.id == id } }

    func setOn(_ id: String, _ on: Bool) {
        if on { switchedOn.insert(id) } else { switchedOn.remove(id) }
        defaults.set(Array(switchedOn).sorted(), forKey: Self.keyPrefix + "on")
    }

    /// Plugins grouped by shelf, most finished first.
    var byShelf: [ShelfGroup] {
        PlaygroundShelf.allCases.reversed().compactMap { shelf in
            let list = plugins.filter { self.shelf(of: $0) == shelf }
            return list.isEmpty ? nil : ShelfGroup(shelf: shelf, plugins: list)
        }
    }

    struct ShelfGroup: Identifiable {
        let shelf: PlaygroundShelf
        let plugins: [PlaygroundPlugin]
        var id: Int { shelf.rawValue }
    }

    func listen(_ handler: @escaping (PlaygroundEvent) -> Void) { listeners.append(handler) }

    func emit(_ event: PlaygroundEvent) { listeners.forEach { $0(event) } }
}
