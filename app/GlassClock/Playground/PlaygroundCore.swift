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
}

/// The one place plugins register, get switched on and off, and send each other events.
@Observable @MainActor
final class Playground {
    static let shared = Playground()

    private(set) var plugins: [PlaygroundPlugin] = []
    private var switchedOn: Set<String>
    @ObservationIgnored private var listeners: [(PlaygroundEvent) -> Void] = []
    @ObservationIgnored private let defaults: UserDefaults

    /// Saved keys all start with this, so the playground never collides with the real app.
    nonisolated static let keyPrefix = "playground."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        switchedOn = Set(defaults.stringArray(forKey: Self.keyPrefix + "on") ?? [])
        register(JoyLevel.plugin)
        register(IdleLife.plugin)
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

    func isOn(_ id: String) -> Bool { switchedOn.contains(id) }

    func setOn(_ id: String, _ on: Bool) {
        if on { switchedOn.insert(id) } else { switchedOn.remove(id) }
        defaults.set(Array(switchedOn).sorted(), forKey: Self.keyPrefix + "on")
    }

    /// Plugins grouped by shelf, most finished first.
    var byShelf: [ShelfGroup] {
        PlaygroundShelf.allCases.reversed().compactMap { shelf in
            let list = plugins.filter { $0.shelf == shelf }
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
