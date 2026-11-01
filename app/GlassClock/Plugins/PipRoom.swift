import SwiftUI

// PIP ROOM · shared helper, not a plugin (no line in Plugins.swift). Aaron, 1 Nov: "pip can be a bit too much but its
// ok, maybe he should start to not get so close when you flick him away". Pip gives you room after a flick:
// - each flick away, Pip keeps a step further back from your finger and Pencil (more flicks, more room, to a limit);
// - a hard flick (same line as Pip's Manners' quiet) and Pip doesn't follow or come over for 3 minutes;
// - it eases back by itself, gone 5 minutes after the last flick; a tap or a head rub brings Pip a step closer.
// Pip's Manners hears the flicks and taps, so it's all behind that switch: Manners off and nothing changes.
// The plugins that bring Pip close ask here: Pip's Bond (follows your finger), Pencil Wonders (follows the Pencil),
// Doodle Duet (flies to your lines). Not saved: a relaunch starts friends again. Pip off: no flicks, no room.
// Simpler motion: Pip doesn't follow anyway, so nothing here moves.

@MainActor
enum PipRoom {
    // MARK: Data

    /// Extra room per flick, in points (a fingertip and a bit). Hard flicks count twice.
    static let step: CGFloat = 50
    /// The most room Pip gives.
    static let most: CGFloat = 250
    /// Seconds after the last flick until Pip is back to normal (it eases off evenly).
    static let easesBack: Double = 300
    /// A flick this fast means "away" (the core's first-flick line); slower is just moving Pip.
    static let flickCounts: Double = 500
    /// After a hard flick, no following at all for this long (as long as Manners' quiet after a hard flick).
    static let keepAwayFor: Double = 180    // = PipTalkTurns.afterFlick

    // MARK: Logic

    private static var stored: CGFloat = 0
    private static var since = Date.distantPast
    private static var awayUntil = Date.distantPast

    /// The room right now, easing off evenly from the last change.
    private static var current: CGFloat {
        let left = 1 - Date.now.timeIntervalSince(since) / easesBack
        return stored * CGFloat(min(1, max(0, left)))
    }

    /// Extra points Pip keeps back right now (0 with Pip's Manners off).
    static func room(_ host: PipHost) -> CGFloat {
        host.isOn(PipTalkTurns.mannersID) ? current : 0
    }

    /// True for a while after a hard flick: Pip doesn't follow you or come over.
    static func keepsAway(_ host: PipHost) -> Bool {
        host.isOn(PipTalkTurns.mannersID) && Date.now < awayUntil
    }

    /// When Pip is back to normal, for the Manners card (nil: not giving room now).
    static func normalAgain(_ host: PipHost) -> Date? {
        guard room(host) > 0.5 || keepsAway(host) else { return nil }
        return max(since.addingTimeInterval(easesBack), awayUntil)
    }

    /// Pip's Manners calls this on every flick.
    static func flicked(speed: Double) {
        guard speed >= flickCounts else { return }
        let hard = speed > PipManners.hardFlick
        stored = min(most, current + step * (hard ? 2 : 1))
        since = .now
        if hard { awayUntil = Date.now.addingTimeInterval(keepAwayFor) }
    }

    /// A tap or a head rub: Pip comes a step closer and stops keeping away.
    static func closer() {
        stored = max(0, current - step)
        since = .now
        awayUntil = .distantPast
    }

    /// `target` (where a plugin would put Pip near your finger or Pencil at `from`) pushed back by the room,
    /// in the same direction, so Pip stays on their side of you.
    static func further(_ target: CGPoint, from: CGPoint, _ host: PipHost) -> CGPoint {
        let r = room(host)
        let dx = target.x - from.x, dy = target.y - from.y
        let d = hypot(dx, dy)
        guard r > 0.5, d > 0.5 else { return target }
        return CGPoint(x: from.x + dx / d * (d + r), y: from.y + dy / d * (d + r))
    }

    /// For `host.follow`: the point to trail so Pip ends up the room further back, up and to the left as before.
    static func trail(_ point: CGPoint, _ host: PipHost) -> CGPoint {
        let r = room(host)
        let o = PipFollow.offset
        let d = hypot(o.width, o.height)
        guard r > 0.5, d > 0 else { return point }
        return CGPoint(x: point.x - o.width / d * r, y: point.y - o.height / d * r)
    }
}
