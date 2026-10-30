import Foundation

// PIP TALK TURNS · shared helpers, not a plugin (no line in Plugins.swift). One "floor" so no two plugins make Pip
// talk at once: a time in `plug.pip.askingUntil`. Before Pip asks or starts something on their own, a plugin checks
// `floorFree`; while Pip has the floor, it calls `takeFloor` for roughly how long Pip will be busy.
// Until the core has a proper "Pip is talking" flag, this file is it. Any plugin can use it; none depends on another.

@MainActor
enum PipTalkTurns {
    static let key = "plug.pip.askingUntil"

    /// True when no plugin is holding the floor.
    static func floorFree(_ host: PipHost) -> Bool {
        Date.now.timeIntervalSince1970 >= ((host.value("pip", "askingUntil") as Double?) ?? 0)
    }

    /// Hold the floor for this many seconds from now (0 gives it back). Never shortens a longer hold that's
    /// already there, so one plugin can't cut another off mid-sentence.
    static func takeFloor(_ host: PipHost, for seconds: Double) {
        let now = Date.now.timeIntervalSince1970
        let held = (host.value("pip", "askingUntil") as Double?) ?? 0
        host.setValue(seconds <= 0 ? now : max(held, now + seconds), "pip", "askingUntil")
    }

    /// Give the floor back straight away, for places that don't have the host to hand.
    static func giveBack() {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: key)
    }
}
