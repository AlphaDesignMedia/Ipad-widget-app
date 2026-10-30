import SwiftUI

// PIP'S MANNERS · plugin v1 (Grounded). One shared talk budget, so all the plugins together can't make Pip chatty.
// The budget itself lives in PipTalkTurns (`spend`). This plugin is its switch, its card, and its ears: it keeps
// Pip quiet while you draw and for a few minutes after you flick Pip away hard.
// How much Pip may start on their own follows Joy: 0 none, 1 about 2 every 10 minutes, 3 about 5, 5 no real limit.
// Replies to something you did (a tap, a button) never count. Switched off: plugins only take turns, as before.
// Where: the raised-hand button in the plugin bar.

struct PipManners: SandboxPlugin {
    let info = PluginInfo(id: "manners", name: "Pip's Manners", version: "v1", shelf: .grounded,
                          icon: "hand.raised", what: "Keeps Pip from chatting too much on their own. Follows the Joy setting.")

    // MARK: Data

    /// A flick this fast (points per second) means "go away for a bit". Same line as a hard bump.
    static let hardFlick: Double = 1150
    /// "Shh for an hour".
    static let shhSeconds: Double = 3600

    // MARK: Logic

    static func saidLine(_ n: Int) -> String {
        "Pip has said \(n) \(n == 1 ? "thing" : "things") in the last 10 minutes, on their own."
    }

    @MainActor static func joyLine(joy: Int) -> String {
        switch joy {
        case ...0: return "Joy is 0, so Pip doesn't start chats on their own. They still answer you."
        case 5...: return "Joy is 5, so Pip can chat as much as they like."
        default:
            let n = PipTalkTurns.allowance(joy: joy)
            return "Joy is \(joy), so Pip starts up to \(n) chats on their own every 10 minutes. "
                + "Answers to your taps don't count. Change it with the Joy setting."
        }
    }

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .ink:
            PipTalkTurns.quiet(for: PipTalkTurns.afterInk)
        case .flick(let speed) where speed > Self.hardFlick:
            PipTalkTurns.quiet(for: PipTalkTurns.afterFlick)
        default:
            break
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { MannersCard(host: host) }

    struct MannersCard: View {
        let host: PipHost
        @AppStorage("plug.pip.hushUntil") private var hushUntil: Double = 0

        var body: some View {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let said = PipTalkTurns.saidLately()
                let hushed = hushUntil > context.date.timeIntervalSince1970
                VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                    Text(PipManners.saidLine(said))
                    Text(PipManners.joyLine(joy: host.joy))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Text("Pip also stays quiet while you draw, and for a few minutes after you flick them away.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    if hushed {
                        let until = Date(timeIntervalSince1970: hushUntil).formatted(date: .omitted, time: .shortened)
                        Text("Shh until \(until).").font(.system(size: 12)).foregroundStyle(.secondary)
                        Button {
                            PipTalkTurns.shh(host, for: 0)
                        } label: {
                            Label("Let Pip chat again", systemImage: "bubble.left")
                        }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Let Pip chat again")
                        .accessibilityHint("Ends the shh now. Pip still follows the Joy setting.")
                    } else {
                        Button {
                            PipTalkTurns.shh(host, for: PipManners.shhSeconds)
                        } label: {
                            Label("Shh for an hour", systemImage: "moon.zzz")
                        }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Shh for an hour")
                        .accessibilityHint("Pip won't start chats on their own for an hour. They still answer you.")
                    }
                }
                .font(.system(size: 13.5))
                .accessibilityElement(children: .contain)
            }
        }
    }
}
