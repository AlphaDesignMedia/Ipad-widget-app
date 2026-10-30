import SwiftUI
import UIKit

// PLUGIN DESK · plugin v1 (On trial). One card to look over every plugin: switch it, tweak how it
// behaves, and give it a verdict (Keep, Tweak, Scrap) with a note. "Send to the agents" turns the
// notes into a message for AGENT-NOTES.md, so the plugin and app agents know what to change.
// Tweaks work through each plugin's own saved settings, so the Desk changes how a plugin behaves
// without touching its code. Other panels can show their own tweaks with one line:
// `PluginDesk.Tweaks(for: "sketch")` (see the note in AGENT-NOTES.md).
// Where: the checklist button in the plugin bar.

struct PluginDesk: SandboxPlugin {
    let info = PluginInfo(id: "desk", name: "Plugin Desk", version: "v1", shelf: .trial,
                          icon: "checklist", what: "Review every plugin: switch, tweak, keep or scrap, with notes for the agents.")

    // MARK: Data

    enum Verdict: String, Codable, CaseIterable {
        case undecided, keep, tweak, scrap
        var label: String {
            switch self {
            case .undecided: "Not sure"
            case .keep: "Keep"
            case .tweak: "Tweak"
            case .scrap: "Scrap"
            }
        }
        var icon: String {
            switch self {
            case .undecided: "questionmark.circle"
            case .keep: "checkmark.circle"
            case .tweak: "wrench.adjustable"
            case .scrap: "trash"
            }
        }
    }

    struct Review: Codable, Equatable {
        var verdict = Verdict.undecided
        var note = ""
        var changed = Date.now
    }

    /// One thing a plugin lets you change, stored under a key the plugin already reads.
    struct Tweak: Identifiable {
        enum Kind {
            case toggle(Bool)
            case slider(ClosedRange<Double>, step: Double, start: Double)
            case choice([String], start: String)
        }
        let key: String          // the full UserDefaults key
        let label: String
        let kind: Kind
        var note: String? = nil  // shown under the control, e.g. when it takes effect
        var id: String { key }
    }

    /// Tweaks by plugin id. Each one uses a setting the plugin already reads, so nothing else changes.
    /// To give a plugin tweaks, add it here (and ask its maker which keys it reads).
    static let tweaks: [String: [Tweak]] = [
        "sketch": [
            Tweak(key: "plug.sketch.size", label: "Brush size", kind: .slider(2...24, step: 1, start: 6)),
            Tweak(key: "plug.sketch.anywhere", label: "Pencil draws anywhere", kind: .toggle(true)),
            Tweak(key: "plug.sketch.paper", label: "Paper behind the ink", kind: .toggle(false)),
            Tweak(key: "plug.sketch.tool", label: "Tool", kind: .choice(["pen", "marker", "highlighter"], start: "pen"),
                  note: "Sketch picks these up next time it opens."),
        ],
        "playground": [
            Tweak(key: "playground.joy", label: "Joy (0 still … 5 unhinged)", kind: .slider(0...5, step: 1, start: 1)),
        ],
    ]

    static let reviewsKey = "plug.desk.reviews"

    enum Lines {
        static let keep = ["Keeper!", "That one stays."]
        static let scrap = ["Scrapped. It had a good run.", "Into the bin. Gently."]
        static let tweak = ["Noted. Back to the workbench."]
        static let sent = "Sent. The agents will read it next time."
    }

    // MARK: Logic

    static func load() -> [String: Review] {
        guard let data = UserDefaults.standard.data(forKey: reviewsKey),
              let reviews = try? JSONDecoder().decode([String: Review].self, from: data) else { return [:] }
        return reviews
    }

    static func save(_ reviews: [String: Review]) {
        if let data = try? JSONEncoder().encode(reviews) { UserDefaults.standard.set(data, forKey: reviewsKey) }
    }

    /// The message for the agents: every plugin with a verdict or a note, scraps first.
    static func message(_ host: PipHost, _ reviews: [String: Review]) -> String {
        let order: [Verdict] = [.scrap, .tweak, .keep, .undecided]
        var lines = ["## \(Date.now.formatted(date: .abbreviated, time: .shortened)) · Aaron (Plugin Desk)", ""]
        for verdict in order {
            let items = host.plugins.filter { (reviews[$0.info.id]?.verdict ?? .undecided) == verdict }
                .filter { verdict != .undecided || !(reviews[$0.info.id]?.note.isEmpty ?? true) }
            guard !items.isEmpty else { continue }
            lines.append("**\(verdict.label):**")
            for p in items {
                let r = reviews[p.info.id] ?? Review()
                let state = host.isOn(p.info.id) ? "on" : "off"
                let note = r.note.trimmingCharacters(in: .whitespacesAndNewlines)
                lines.append("- \(p.info.name) \(p.info.version) (\(p.info.shelf.label), \(state))\(note.isEmpty ? "" : ": \(note)")")
            }
            lines.append("")
        }
        if lines.count == 2 { lines.append("No verdicts yet.") }
        return lines.joined(separator: "\n")
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { Desk(host: host) }

    struct Desk: View {
        let host: PipHost
        @State private var reviews = PluginDesk.load()
        @State private var open: String?
        @State private var copied = false

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                tally
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(host.plugins.indices, id: \.self) { i in
                            let p = host.plugins[i]
                            if p.info.id != "desk" { row(p) }
                        }
                    }
                }
                .frame(maxHeight: 420)
                HStack(spacing: 8) {
                    Button(copied ? "Copied" : "Copy for the agents") {
                        UIPasteboard.general.string = PluginDesk.message(host, reviews)
                        copied = true
                        host.say(Lines.sent, for: 2)
                        host.later(2) { copied = false }
                    }
                    .buttonStyle(PluginCardButton(on: copied))
                    .accessibilityHint("Copies your verdicts and notes, ready to paste into AGENT-NOTES.md.")
                    ShareLink(item: PluginDesk.message(host, reviews)) {
                        Image(systemName: "square.and.arrow.up").accessibilityLabel("Share the notes")
                    }
                    .buttonStyle(PluginCardButton())
                }
            }
            .font(.system(size: 13.5))
            .onChange(of: reviews) { _, new in PluginDesk.save(new) }
        }

        /// How many of each verdict, as a row of small counts.
        private var tally: some View {
            HStack(spacing: 12) {
                ForEach([Verdict.keep, .tweak, .scrap, .undecided], id: \.self) { v in
                    let n = host.plugins.filter { $0.info.id != "desk" && (reviews[$0.info.id]?.verdict ?? .undecided) == v }.count
                    Label("\(n)", systemImage: v.icon)
                        .accessibilityLabel("\(n) \(v.label)")
                }
            }
            .foregroundStyle(.secondary)
        }

        private func row(_ p: any SandboxPlugin) -> some View {
            let id = p.info.id
            let review = reviews[id] ?? Review()
            let expanded = open == id
            return VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(host.simpler ? nil : .snappy) { open = expanded ? nil : id }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: p.info.icon).frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.info.name).bold()
                            Text("\(p.info.shelf.label) · \(host.isOn(id) ? "On" : "Off")")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: review.verdict.icon).foregroundStyle(.secondary)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(p.info.name), \(host.isOn(id) ? "on" : "off"), \(review.verdict.label)")
                .accessibilityHint(expanded ? "Closes its details." : "Opens its switch, tweaks and verdict.")

                if expanded { details(p, review) }
            }
            .padding(10)
            .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
        }

        @ViewBuilder private func details(_ p: any SandboxPlugin, _ review: Review) -> some View {
            let id = p.info.id
            Text(p.info.what).foregroundStyle(.secondary)
            Toggle("On", isOn: Binding(get: { host.isOn(id) }, set: { host.setOn(id, $0) }))
            if let tweaks = PluginDesk.tweaks[id] {
                Tweaks(for: id, tweaks: tweaks)
            }
            HStack(spacing: 6) {
                ForEach([Verdict.keep, .tweak, .scrap], id: \.self) { v in
                    Button {
                        set(id) { $0.verdict = $0.verdict == v ? .undecided : v }
                        if let line = line(for: v) { host.say(line, for: 1.8) }
                    } label: {
                        Label(v.label, systemImage: v.icon).labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(PluginCardButton(on: review.verdict == v))
                    .accessibilityAddTraits(review.verdict == v ? .isSelected : [])
                }
            }
            TextField("A note for the agents…", text: Binding(
                get: { reviews[id]?.note ?? "" },
                set: { text in self.set(id) { $0.note = text } }), axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Note about \(p.info.name)")
        }

        private func line(for v: Verdict) -> String? {
            switch v {
            case .keep: Lines.keep.randomElement()
            case .scrap: Lines.scrap.randomElement()
            case .tweak: Lines.tweak.randomElement()
            case .undecided: nil
            }
        }

        private func set(_ id: String, _ edit: (inout Review) -> Void) {
            var r = reviews[id] ?? Review()
            edit(&r)
            r.changed = .now
            reviews[id] = r
        }
    }

    /// A plugin's tweaks as controls. Other panels can show these too, with one line:
    /// `PluginDesk.Tweaks(for: "sketch")`.
    struct Tweaks: View {
        let plugin: String
        let tweaks: [Tweak]

        init(for plugin: String, tweaks: [Tweak]? = nil) {
            self.plugin = plugin
            self.tweaks = tweaks ?? PluginDesk.tweaks[plugin] ?? []
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tweaks) { tweak in
                    TweakControl(tweak: tweak)
                }
            }
            .font(.system(size: 13.5))
        }
    }

    private struct TweakControl: View {
        let tweak: Tweak
        @State private var number = 0.0
        @State private var flag = false
        @State private var pick = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                switch tweak.kind {
                case .toggle:
                    Toggle(tweak.label, isOn: $flag)
                        .onChange(of: flag) { _, v in UserDefaults.standard.set(v, forKey: tweak.key) }
                case .slider(let range, let step, _):
                    HStack {
                        Text(tweak.label)
                        Spacer()
                        Text(number.formatted(.number.precision(.fractionLength(step < 1 ? 1 : 0))))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $number, in: range, step: step)
                        .accessibilityLabel(tweak.label)
                        .onChange(of: number) { _, v in UserDefaults.standard.set(v, forKey: tweak.key) }
                case .choice(let options, _):
                    Picker(tweak.label, selection: $pick) {
                        ForEach(options, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    .onChange(of: pick) { _, v in UserDefaults.standard.set(v, forKey: tweak.key) }
                }
                if let note = tweak.note {
                    Text(note).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            .onAppear(perform: read)
        }

        /// Starts from the saved value, or the plugin's own default.
        private func read() {
            let saved = UserDefaults.standard.object(forKey: tweak.key)
            switch tweak.kind {
            case .toggle(let start): flag = saved as? Bool ?? start
            case .slider(_, _, let start): number = (saved as? Double) ?? (saved as? Int).map { Double($0) } ?? start
            case .choice(_, let start): pick = saved as? String ?? start
            }
        }
    }
}
