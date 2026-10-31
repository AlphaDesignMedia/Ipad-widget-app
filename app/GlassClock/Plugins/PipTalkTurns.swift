import Foundation
import Observation

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

    // MARK: Manners · one shared talk budget (Bob, 30 Oct; the Pip's Manners card shows it)
    // When Pip starts talking on their own (an offer, a visit, a "Shot!"), the plugin calls `spend` instead of
    // `floorFree`. Every plugin shares one budget, so together they can't make Pip chatty. Replies to something
    // the person did (a tap, a button) don't spend. The budget follows Joy. "Shh for an hour", and a short quiet
    // after drawing or after Pip is flicked away hard, also count. With Pip's Manners switched off, `spend` is just
    // `floorFree`, as before.

    static let mannersID = "manners"
    /// The budget's window: ten minutes.
    static let window: Double = 600
    /// Quiet this long after the last bit of drawing.
    static let afterInk: Double = 20
    /// Quiet this long after Pip is flicked away hard.
    static let afterFlick: Double = 180

    /// Lines Pip may start on their own per ten minutes, at Joy 0 (still) to 5 (unhinged).
    static func allowance(joy: Int) -> Int { [0, 2, 3, 5, 8, 99][min(max(joy, 0), 5)] }

    /// What Pip has started saying this session, and the short quiet. Not saved.
    static let ledger = PipTalkLedger()

    /// Lines Pip started on their own in the last ten minutes.
    static func saidLately() -> Int {
        let since = Date.now.addingTimeInterval(-window)
        return ledger.said.filter { $0 > since }.count
    }

    /// When "Shh" ends, in seconds since 1970 (0 or past: not hushed). Saved, so it lasts a relaunch.
    static func hushUntil(_ host: PipHost) -> Double { (host.value("pip", "hushUntil") as Double?) ?? 0 }

    /// "Shh for an hour" (or any length). 0 lets Pip talk again.
    static func shh(_ host: PipHost, for seconds: Double) {
        let until: Double = seconds <= 0 ? 0 : Date.now.timeIntervalSince1970 + seconds
        host.setValue(until, "pip", "hushUntil")
    }

    /// A short quiet (drawing, a hard flick). Never shortens a longer one, and changes at most once a second.
    static func quiet(for seconds: Double) {
        let until = Date.now.addingTimeInterval(seconds)
        if until.timeIntervalSince(ledger.quietUntil) > 1 { ledger.quietUntil = until }
    }

    /// May Pip start talking on their own now? Checks only; spends nothing.
    static func mayChat(_ host: PipHost) -> Bool {
        guard floorFree(host) else { return false }
        guard host.isOn(mannersID) else { return true }             // Manners off: just the floor, as before
        guard host.pipHere, host.joy > 0 else { return false }
        return Date.now.timeIntervalSince1970 >= hushUntil(host)
            && Date.now >= ledger.quietUntil
            && saidLately() < allowance(joy: host.joy)
    }

    /// True, and counted, if Pip may start talking on their own now. Put it last in a guard, just before Pip
    /// starts, so a "no" from anything else spends nothing. One spend per conversation, not per line.
    @discardableResult
    static func spend(_ host: PipHost) -> Bool {
        guard mayChat(host) else { return false }
        let since = Date.now.addingTimeInterval(-window)
        ledger.said.removeAll { $0 <= since }
        ledger.said.append(.now)
        return true
    }
}

/// The talk budget's memory for this session. Pip's Manners card watches `said`.
@MainActor @Observable final class PipTalkLedger {
    var said: [Date] = []
    @ObservationIgnored var quietUntil: Date = .distantPast
}
