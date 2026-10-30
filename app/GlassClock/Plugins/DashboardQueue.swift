import SwiftUI
import UIKit

// DASHBOARD QUEUE · plugin v1 (On trial). Ideas from the plugin agent's chats that are waiting to go on Aaron's real
// dashboard, kept here, with a step-by-step walk to move them over: copy, switch to the dashboard, paste, done. Pip
// leads it when Pip's here (and offers at most 3 times); with Pip off it's plain step cards. Progress stays on the
// device. No network. A plain copy of the list sits in DASHBOARD-QUEUE.md at the repo root.
// Joy: host.joy sets how big the cheers are (0 = words only). Wonder: each idea you move goes off as a little
// letter from Pip, and the last one gets a proper send-off.
// Where: a section in the Dashboard panel.

struct DashboardQueue: SandboxPlugin {
    let info = PluginInfo(id: "dashqueue", name: "Dashboard queue", version: "v1", shelf: .trial,
                          icon: "tray.and.arrow.up", what: "Ideas waiting to go on your dashboard, and a walk to move them over.")

    // MARK: Data

    struct Item: Identifiable {
        let id: String
        let title: String
        let text: String
    }

    static let items: [Item] = [
        Item(id: "sketchbook", title: "Pip's Sketchbook",
             text: "💡 Pip's Sketchbook: Pip loves watching you draw, wants to join, wishes they were better. Starts thinking everything is a house or a face. Stages: Watch (built) → Guess, you teach → Trace Pip's wobbly drawing → skill grows. Rules: Pip off = no effect; offers 3 times; Pip's lines on their own layer; learning stays on the device."),
        Item(id: "namedrift", title: "Pip's name drifts",
             text: "💡 Pip's name drifts: everyone starts as Pip. Over weeks the vowel follows their personality: Pip curious, Pep energetic, Pop playful, Pap calm, Pup cheeky. A mini you with their own quirks. Slow, Pip asks first, lockable, on device, Pip off = none."),
        Item(id: "circles", title: "Circles over sliders",
             text: "💡 Circles over sliders: 2D pads for Pip's personality, 4 labelled edges, a live readout, Pip reacts while you drag. Fix Helper Dial the same way."),
        Item(id: "helphome", title: "Help Pip home",
             text: "💡 Help Pip home: tap to flap a tired, heavy Pip to a ledge. Pip's own game: no pipes, no fail screen."),
        Item(id: "backstory", title: "Pip's backstory",
             text: "💡 Pip's backstory: once the star of \"Updraft\", a forgotten made-up arcade cabinet. Flew out through the glass when the arcade closed. Now flaps by choice, loves rests and being carried."),
        Item(id: "story", title: "Pip's story unfolds",
             text: "💡 Pip's story unfolds: chapters unlock with time and the Bond ladder, never money. Branches from how you use the app. Light users get the cover story: \"I was a screensaver.\""),
        Item(id: "android", title: "Android",
             text: "💡 Android: no port for now. Try the web Pip Sandbox in Chrome on Android (Add to Home Screen)."),
        Item(id: "ladder", title: "Restraint ladder",
             text: "💡 Restraint ladder: Play → Proven → Hidden → Gentle (off by default) → Core. First open of Glass Clock = just the clock."),
        Item(id: "busypip", title: "Busy Pip",
             text: "💡 Busy Pip: in Developer mode, Pip with a clipboard audits the plugins. Real mode = clear and exact, 3 questions max. Pretend mode = confident nonsense. Your answers set how calm Pip is for everyone."),
        Item(id: "tea", title: "Tea break",
             text: "💡 Tea break: hard-working Pip asks for a cuppa 3 times max, then makes their own and sulks a little."),
        Item(id: "guests", title: "Guest Takeover",
             text: "💡 Guest Takeover: made-up guests (Tack the drawing pin, Fuse the lamp) barge in and do Pip's job. Pip takes it back."),
        Item(id: "selfcheck", title: "Pip checks themselves",
             text: "💡 Pip checks themselves: after each update Pip tries what's new and asks \"Still feel like me?\". Feels off = that change switches off, plus a note for the developer. 3 per build."),
        Item(id: "feelrule", title: "Feel rule",
             text: "💡 Feel rule: every build must pass \"Does this still feel like Pip?\": smooth, fresh, fits a floating fairy, one tap off."),
    ]

    enum Lines {
        static func offer(_ n: Int) -> String { "I've got \(n) ideas queued for your dashboard. Want to move them over together?" }
        static let start = "Brilliant. One at a time. I'll hold the list."
        static let done = ["Moved! One less for me to carry.", "Lovely. That one's home.", "Done. The dashboard's getting clever."]
        static let skip = "Skipping that one. It stays here."
        static let later = "Later it is. I'll keep it safe."
        static let finished = "All moved! The dashboard knows everything now."
    }

    static let maxOffers = 3

    // MARK: Logic

    /// Progress, kept on the device: each item's id and where it got to.
    enum Mark: String { case moved, skipped }

    static func marks(_ raw: String) -> [String: Mark] {
        var out: [String: Mark] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, let m = Mark(rawValue: String(parts[1])) { out[String(parts[0])] = m }
        }
        return out
    }

    static func encode(_ marks: [String: Mark]) -> String {
        marks.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.rawValue)" }.joined(separator: ",")
    }

    /// A dashboard link from the packed dashboard.json, if it has one under "url", "link" or "dashboardUrl".
    static let dashboardLink: URL? = {
        struct Links: Decodable {
            var url: String?
            var link: String?
            var dashboardUrl: String?
        }
        guard let file = Bundle.main.url(forResource: "dashboard", withExtension: "json"),
              let raw = try? Data(contentsOf: file),
              let l = try? JSONDecoder().decode(Links.self, from: raw),
              let text = l.dashboardUrl ?? l.url ?? l.link,
              let url = URL(string: text), url.scheme == "https" else { return nil }
        return url
    }()

    /// Session state for the walk.
    @MainActor @Observable final class Walk {
        var active = false
        var current: String?
        var copied = false
        @ObservationIgnored var offeredThisSession = false
    }
    private let walk = Walk()

    func on(_ event: PipEvent, _ host: PipHost) {
        guard case .appear = event else { return }
        offer(host)
    }

    /// Pip mentions the queue once a session, a little after appearing, and at most 3 times ever.
    private func offer(_ host: PipHost) {
        guard !walk.offeredThisSession, host.isOn("dashboard") else { return }
        walk.offeredThisSession = true
        host.later(25) {
            let offers = (host.value("dashqueue", "offers") as Int?) ?? 0
            let left = Self.waiting((host.value("dashqueue", "marks") as String?) ?? "").count
            guard offers < Self.maxOffers, left > 0, host.pipHere, !host.pipAsleep, BusyPip.floorFree(host) else { return }
            if host.say(Lines.offer(left), for: 4.5) {
                BusyPip.takeFloor(host, for: 6)
                host.setValue(offers + 1, "dashqueue", "offers")
            }
        }
    }

    /// Items not yet moved, in order (skipped ones come last).
    static func waiting(_ raw: String) -> [Item] {
        let m = marks(raw)
        return items.filter { m[$0.id] == nil } + items.filter { m[$0.id] == .skipped }
    }

    // MARK: Views

    var addsTo: String? { "dashboard" }
    func addOn(_ host: PipHost) -> some View { QueueSection(walk: walk, host: host) }

    struct QueueSection: View {
        let walk: Walk
        let host: PipHost
        @AppStorage("plug.dashqueue.marks") private var raw = ""
        @AppStorage("plug.dashqueue.lastMoved") private var lastMoved = ""

        private var marks: [String: Mark] { DashboardQueue.marks(raw) }
        private var movedCount: Int { marks.values.filter { $0 == .moved }.count }
        private var total: Int { DashboardQueue.items.count }

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("Dashboard queue").bold()
                Text("\(movedCount) of \(total) moved")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel("\(movedCount) of \(total) ideas moved to your dashboard")
                if walk.active, let id = walk.current, let item = DashboardQueue.items.first(where: { $0.id == id }) {
                    step(item)
                } else if movedCount == total {
                    Text("All moved. The dashboard knows everything now.").font(.system(size: 13.5))
                } else {
                    Button(host.pipHere ? "Move them over with Pip" : "Move them over") { begin() }
                        .buttonStyle(PluginCardButton(on: true))
                        .accessibilityLabel("Start moving the queued ideas to your dashboard")
                    ForEach(DashboardQueue.waiting(raw)) { item in
                        HStack(spacing: 6) {
                            Text(item.title).font(.system(size: 13.5))
                            if marks[item.id] == .skipped {
                                Text("skipped").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if !lastMoved.isEmpty, !walk.active {
                    Button("Undo last moved") { undo() }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Undo the last idea marked as moved")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        /// One step card: the idea, Copy, switch to the dashboard, then Done / Skip / Later.
        private func step(_ item: Item) -> some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text(item.title).font(.system(size: 13.5).weight(.semibold))
                Text(item.text).font(.system(size: 13.5)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Button(walk.copied ? "Copied" : "1. Copy") {
                        UIPasteboard.general.string = item.text
                        withAnimation(.easeInOut(duration: 0.2)) { walk.copied = true }
                    }
                    .buttonStyle(PluginCardButton(on: walk.copied))
                    .accessibilityLabel(walk.copied ? "Copied" : "Copy this idea")
                    if let link = DashboardQueue.dashboardLink {
                        Link("2. Open your dashboard", destination: link)
                            .buttonStyle(PluginCardButton())
                            .accessibilityLabel("Open your dashboard")
                    }
                }
                if DashboardQueue.dashboardLink == nil {
                    Text("2. Switch to your dashboard and paste it in.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("3. Pasted it?").font(.system(size: 13.5))
                HStack(spacing: 6) {
                    Button("Done") { finish(item, .moved) }
                        .buttonStyle(PluginCardButton(on: true))
                        .accessibilityLabel("Done, it's on the dashboard")
                    Button("Skip") { finish(item, .skipped) }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Skip this idea")
                    Button("Later") { later() }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Stop for now, carry on later")
                }
            }
        }

        private func begin() {
            let next = DashboardQueue.waiting(raw).first?.id
            withAnimation(.easeInOut(duration: 0.3)) {
                walk.active = next != nil
                walk.current = next
                walk.copied = false
            }
            host.say(Lines.start, for: 2.2)
        }

        private func finish(_ item: Item, _ mark: Mark) {
            var m = marks
            m[item.id] = mark
            raw = DashboardQueue.encode(m)
            if mark == .moved {
                lastMoved = item.id
                if m.values.filter({ $0 == .moved }).count == total {
                    celebrate()
                } else {
                    posted()
                    host.say(Lines.done.randomElement()!, for: 1.8)
                }
            } else {
                host.say(Lines.skip, for: 1.8)
            }
            // The next one that's neither moved nor just skipped in this walk.
            let next = DashboardQueue.items.first { m[$0.id] == nil }?.id
            withAnimation(.easeInOut(duration: 0.3)) {
                walk.current = next
                walk.active = next != nil
                walk.copied = false
            }
        }

        private func later() {
            withAnimation(.easeInOut(duration: 0.3)) {
                walk.active = false
                walk.current = nil
                walk.copied = false
            }
            host.say(Lines.later, for: 1.8)
        }

        private func undo() {
            var m = marks
            m[lastMoved] = nil
            raw = DashboardQueue.encode(m)
            lastMoved = ""
        }

        /// The small wonder: Pip "posts" each idea. A soft glow at joy 1, a cheer and a little letter as joy grows.
        private func posted() {
            let joy = host.joy
            guard joy > 0 else { return }
            host.blush(PipLook.glow, for: 1.2)
            if joy >= 2 { host.cheer() }
            if joy >= 3 { NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: "✉️") }
        }

        private func celebrate() {
            let joy = host.joy
            if joy > 0 {
                host.cheer()
                host.blush(PipLook.glow, for: 4)
            }
            if joy >= 2 { NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: "🎉") }
            host.say(Lines.finished, for: 3.5)
            if joy >= 3 { host.later(1.2) { host.cheer() } }
        }
    }
}
