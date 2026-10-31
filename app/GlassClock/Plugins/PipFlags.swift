import SwiftUI

// PIP'S FLAGS · plugin v1 (On trial). Red flag, green flag. Pip looks down the plugin list and says which ones
// they reckon are making the app heavy, and why, in a sentence you don't need to be a developer to read.
// One tap settles every red one at once, which is the thing you want ten minutes before showing someone.
//
// HONEST ABOUT WHAT THIS IS. These are suspicions, not measurements. Nothing here profiles anything: the flags
// come from reading how often each plugin wakes up and whether it starts itself. A red flag means "worth
// switching off first if the app feels slow", not "this is broken". Say so on the card, every time.
//
// GROWING THIS. Add to `verdicts` and nothing else. If you tune a plugin so it wakes less often, move it down
// and change the reason. If a flag ever feels unfair to a plugin, it probably is: say why in `note`.

struct PipFlags: SandboxPlugin {
    let info = PluginInfo(id: "flags", name: "Pip's flags", version: "v1", shelf: .trial,
                          icon: "flag.2.crossed",
                          what: "Red flag, green flag. Which plugins Pip reckons are slowing things down.")

    /// No button of its own. Plugin Desk already exists to review plugins, so the flags live inside it:
    /// the bar has 40 buttons already and this didn't deserve a 41st.
    var addsTo: String? { "desk" }

    enum Tune {
        static let sayFor = 3.4          // how long Pip's note stays up
        static let settleGap = 0.06      // pause between switching each red one off, so it isn't one jolt
    }

    enum Flag: Int, Comparable {
        case red = 0, amber = 1, green = 2
        static func < (a: Flag, b: Flag) -> Bool { a.rawValue < b.rawValue }
        var dot: String { self == .red ? "🔴" : self == .amber ? "🟠" : "🟢" }
        var word: String { self == .red ? "Heavy" : self == .amber ? "Worth a look" : "Light" }
    }

    /// One line per plugin we've actually read. `why` is the evidence; `note` is Pip's version of it.
    struct Verdict {
        let flag: Flag, why: String, note: String
    }

    /// Everything not listed here is treated as green: it has no loop of its own and only works while you're
    /// looking at it. Wake rates below were read off each plugin's own sleep interval.
    /// Read off each plugin's own sleep pattern, not guessed. Anything not listed is treated as green:
    /// no loop of its own, so it only works while you're looking at it.
    ///
    /// The axis that matters turned out to be **does it act on its own**, not raw wake rate. A plugin that
    /// runs fast *while you're watching it move* is doing its job; one that starts up when you've walked
    /// away is the one to switch off first.
    static let verdicts: [String: Verdict] = [
        "glass": .init(flag: .red, why: "Starts itself when you stop touching the screen, then wakes every 3s and loops a shine.",
                       note: "Window Cleaner sets off on its own when you leave the room. Lovely, but it's the only one here that starts without you."),
        "busypip": .init(flag: .green, why: "Looks once a second only while Pip could start something; every 5s when Pip's asleep, away or already busy.",
                         note: "Busy Pip has learned to sit still when there's nothing to be busy about."),
        "tidy": .init(flag: .amber, why: "Wakes every 2 seconds, and keeps an animation looping.",
                      note: "Tidy Pip checks every couple of seconds, and keeps a little animation going round."),
        "vendomat": .init(flag: .amber, why: "Rests at 9s, but runs at about 22 frames a second while anything is in the air.",
                          note: "The Vend-O-Mat dozes until something's falling, then it's wide awake."),
        "weight": .init(flag: .green, why: "Adaptive: 60 a second only while Pip is actually moving, then drops to twice a second.",
                        note: "Weight only works hard while I'm moving. The rest of the time it has a sit down."),
        "twentypast": .init(flag: .green, why: "Wakes every 6s, and backs off to a minute when there's nothing due.",
                            note: "Twenty Past glances at the clock, then leaves it alone."),
        "cupboard": .init(flag: .green, why: "Only ticks while Pip is shut in the cupboard.",
                          note: "The cupboard only ticks while I'm locked in it, which is fair enough."),
        "teabreak": .init(flag: .green, why: "Wakes every 30 seconds.",
                          note: "Tea Break barely stirs. Half a minute between thoughts, like me."),
        "guests": .init(flag: .green, why: "Wakes every 60 seconds.",
                        note: "Guests check in once a minute. Hardly rushed."),
        "wonders": .init(flag: .green, why: "Only draws while a wonder is open, and halves its frames under reduced motion.",
                         note: "Wonders only work while you're watching them, which is how it should be."),
        "rob": .init(flag: .green, why: "No loop. Only does anything when he turns up, which is rarely.",
                     note: "Rob turns up, says his piece and goes. No overheads."),
        "vintage": .init(flag: .green, why: "One tick a second, and only while its card is open.",
                         note: "The tin just sits there being a tin."),
        "flags": .init(flag: .green, why: "No loop. Only reads the list when you open it.",
                       note: "This one does nothing until you ask it. I'd be a hypocrite otherwise."),
    ]

    static func verdict(_ id: String) -> Verdict {
        verdicts[id] ?? .init(flag: .green, why: "No loop of its own: it only works while you're using it.",
                              note: "Nothing to report.")
    }

    func start(_ host: PipHost) throws {}
    func on(_ event: PipEvent, _ host: PipHost) {}
    func addOn(_ host: PipHost) -> some View { FlagsCard(host: host) }
}

// MARK: The panel

private struct FlagsCard: View {
    let host: PipHost
    @State private var settling = false
    @State private var showLight = false          // the green ones stay folded away until asked for
    @State private var open: String?              // which row is expanded

    /// Built once, not on every redraw. The list and the flags never change while the panel is open;
    /// only the on/off switches do. Sorting two dozen plugins inside `body` made the panel itself
    /// the slowest thing in the app, which rather defeated the point of it.
    @State private var rows: [Row] = []
    @State private var watch: [Row] = []
    @State private var light: [Row] = []

    struct Row: Identifiable {
        let info: PluginInfo, v: PipFlags.Verdict
        var id: String { info.id }
    }

    private func buildList() {
        guard rows.isEmpty else { return }
        rows = host.plugins
            .filter { $0.info.id != "flags" }     // no switching off the switch panel
            .map { Row(info: $0.info, v: PipFlags.verdict($0.info.id)) }
            .sorted { a, b in
                a.v.flag == b.v.flag ? a.info.name < b.info.name : a.v.flag < b.v.flag
            }
        watch = rows.filter { $0.v.flag < .green }
        light = rows.filter { $0.v.flag == .green }
    }
    private var watchOn: [PluginInfo] { watch.filter { host.isOn($0.info.id) }.map(\.info) }
    private var anyOff: Bool { rows.contains { !host.isOn($0.info.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A hunch, not a measurement. Switch one off and see if it helps.")
                .font(.system(size: 12)).foregroundStyle(.secondary)

            // The one thing this panel exists for: kill the suspects, fast.
            if !watchOn.isEmpty {
                Button { settle() } label: {
                    VStack(spacing: 2) {
                        Label("Switch off the \(watchOn.count) red flags", systemImage: "moon.zzz")
                            .font(.system(size: 16, weight: .semibold))
                        Text(watchOn.map(\.name).joined(separator: ", "))
                            .font(.system(size: 11)).opacity(0.8)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(settling)
                .accessibilityLabel("Switch off the \(watchOn.count) red-flagged plugins: \(watchOn.map(\.name).joined(separator: ", "))")
            } else {
                Label("No red flags switched on.", systemImage: "checkmark.circle")
                    .font(.system(size: 14)).frame(minHeight: 44)
            }

            if anyOff {
                Button { allBackOn() } label: {
                    Label("Switch everything back on", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(settling)
            }

            group("Worth a look", watch, countColour: .orange, alwaysOpen: true)

            DisclosureGroup(isExpanded: $showLight) {
                VStack(alignment: .leading, spacing: 10) { ForEach(light) { row($0) } }
                    .padding(.top, 6)
            } label: {
                HStack {
                    Text("Running light").font(.system(size: 15, weight: .medium))
                    Text("\(light.count)").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
            }
            .accessibilityHint("The plugins Pip isn't worried about.")

            Text("Switched off, never deleted. This panel or Settings brings any of them back.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(18)
        .onAppear { buildList(); pipSays() }
    }

    @ViewBuilder private func group(_ title: String, _ list: [Row],
                                    countColour: Color, alwaysOpen: Bool) -> some View {
        if list.isEmpty {
            Label("Nothing worth a look. All quiet.", systemImage: "checkmark.circle")
                .font(.system(size: 14)).frame(minHeight: 44)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title).font(.system(size: 15, weight: .medium))
                    Text("\(list.count)").font(.system(size: 12)).foregroundStyle(countColour)
                }
                ForEach(list) { row($0) }
            }
        }
    }

    /// One plugin: flag, name, switch. Tap it to see what it does and why it's flagged.
    @ViewBuilder private func row(_ r: Row) -> some View {
        let expanded = open == r.info.id
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(r.v.flag.dot).accessibilityHidden(true)
                Button {
                    withAnimation(host.simpler ? .easeInOut(duration: 0.2) : .snappy(duration: 0.25)) {
                        open = expanded ? nil : r.info.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(r.info.name).font(.system(size: 14, weight: .medium))
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(r.info.name), \(r.v.flag.word). \(expanded ? "Hide" : "Show") details.")

                Toggle("", isOn: Binding(get: { host.isOn(r.info.id) },
                                         set: { host.setOn(r.info.id, $0) }))
                    .labelsHidden()
                    .accessibilityLabel("\(r.info.name) switched on")
            }

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    detail("What it does", r.info.what)
                    detail("Why it's flagged", r.v.why)
                    detail("Pip says", r.v.note)
                    Text("Open \(r.info.name)'s own button in the bar to change how it behaves.")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .padding(.leading, 26)
                .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder private func detail(_ head: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(head).font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(body).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Pip's note: one line about the heaviest thing that's actually on. Quiet at joy 0, silent with Pip off.
    private func pipSays() {
        guard host.joy > 0, PipTalkTurns.floorFree(host) else { return }
        let line = watch.first { host.isOn($0.info.id) }?.v.note
            ?? "Nothing heavy on. I feel quite light, actually."
        if host.say(line, for: PipFlags.Tune.sayFor) {
            PipTalkTurns.takeFloor(host, for: PipFlags.Tune.sayFor)
        }
    }

    private func settle() {
        settling = true
        let list = watchOn
        for (i, p) in list.enumerated() {
            host.later(Double(i) * PipFlags.Tune.settleGap) { host.setOn(p.id, false) }
        }
        host.later(Double(list.count) * PipFlags.Tune.settleGap + 0.1) {
            settling = false
            if host.joy > 0 { host.say("Right. That's quieter.", for: 2.2) }
        }
    }

    private func allBackOn() {
        settling = true
        let list = rows.map(\.info).filter { !host.isOn($0.id) }
        for (i, p) in list.enumerated() {
            host.later(Double(i) * PipFlags.Tune.settleGap) { host.setOn(p.id, true) }
        }
        host.later(Double(list.count) * PipFlags.Tune.settleGap + 0.1) { settling = false }
    }
}
