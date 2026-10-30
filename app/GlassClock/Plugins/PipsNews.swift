import SwiftUI

// PIP'S NEWS · plugin v1 (Dream). Pip tells you what's new. A little after Pip appears or wakes, Pip whispers
// one thing you haven't seen ("Psst!"). Tap Pip while it's talking and that plugin's card opens: then it's
// seen. Each thing is offered 3 times at most, then Pip stops. Never more than one per visit.
// To announce something new, add a line to `items` (newest first).
// Where: the newspaper button in the plugin bar lists everything, with a "Show me" for each.

struct PipsNews: SandboxPlugin {
    let info = PluginInfo(id: "news", name: "Pip's News", version: "v1", shelf: .dream,
                          icon: "newspaper", what: "Pip tells you what's new, once or twice, then stops.")

    // MARK: Data

    struct Item: Identifiable {
        let id: String
        let title: String
        let line: String        // what Pip whispers
        let opens: String?      // the plugin whose card "Show me" opens
    }

    static let items = [
        Item(id: "timemachine", title: "Looks Time Machine", line: "Psst! I built a time machine. Save how you like things!", opens: "timemachine"),
        Item(id: "liquidRail", title: "Liquid side rail", line: "Psst! The side rail's gone drippy too. Tap me!", opens: "liquid"),
        Item(id: "liquid", title: "Liquid Icons", line: "Psst! The bar's gone all liquid. Tap me and I'll show you!", opens: "liquid"),
        Item(id: "lean", title: "Pip leans and wobbles", line: "Psst! I lean into corners now. Wheee!", opens: "bond"),
    ]
    static let offers = 3               // times each thing is offered
    static let after = 2.6              // seconds after Pip appears or wakes
    static let talks = 4.5              // how long Pip's line stays, and how long a tap counts

    // MARK: Logic

    /// What Pip is offering right now, so a tap on Pip can open it.
    @MainActor private static var offering: Item?

    func on(_ event: PipEvent, _ host: PipHost) {
        switch event {
        case .appear, .wake: host.later(Self.after) { Self.offer(host) }
        case .tap:
            guard let item = Self.offering else { return }
            Self.offering = nil
            Self.show(item, host)
            host.later(0.1) { host.say("Ta-da!", for: 1.4) }
        default: break
        }
    }

    static func seen(_ host: PipHost) -> [String] { host.value("news", "seen") ?? [] }
    static func told(_ host: PipHost) -> [String: Int] { host.value("news", "told") ?? [:] }

    static func offer(_ host: PipHost) {
        guard offering == nil, host.pipHere, !host.pipAsleep, host.openCard == nil else { return }
        let seen = seen(host)
        var told = told(host)
        guard let item = items.first(where: { !seen.contains($0.id) && told[$0.id, default: 0] < offers }) else { return }
        guard host.say(item.line, for: talks) else { return }
        told[item.id, default: 0] += 1
        host.setValue(told, "news", "told")
        offering = item
        host.later(talks) { if offering?.id == item.id { offering = nil } }
    }

    static func show(_ item: Item, _ host: PipHost) {
        var seen = seen(host)
        if !seen.contains(item.id) { seen.append(item.id); host.setValue(seen, "news", "seen") }
        if let id = item.opens, host.isOn(id) {
            withAnimation(.easeOut(duration: 0.2)) { host.openCard = id }
        }
    }

    // MARK: Views

    func card(_ host: PipHost) -> some View { NewsCard(host: host) }

    struct NewsCard: View {
        let host: PipHost

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("What's new").bold()
                ForEach(PipsNews.items) { item in
                    HStack {
                        Text(item.title)
                        Spacer()
                        if item.opens.map(host.isOn) == true {
                            Button("Show me") { PipsNews.show(item, host) }
                                .buttonStyle(PluginCardButton())
                                .accessibilityLabel("Show me \(item.title)")
                        }
                    }
                }
                Button("Tell me again") {
                    host.setValue(nil, "news", "seen")
                    host.setValue(nil, "news", "told")
                    withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
                    host.later(0.4) { PipsNews.offer(host) }
                }
                .buttonStyle(PluginCardButton())
                .disabled(!host.pipHere)
            }
            .font(.system(size: 13.5))
        }
    }
}
