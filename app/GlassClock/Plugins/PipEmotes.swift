import SwiftUI

// PIP'S EMOTES · plugin v1 (Dream). Emoji bubbles over Pip, back from the web sandbox: a small glass bubble
// pops up above Pip, drifts a little and fades. Pip uses them for taps, flicks, dizzy bumps and naps, and
// any plugin can send one without depending on this file:
//     NotificationCenter.default.post(name: Notification.Name("pip.emote"), object: "😮‍💨")
// How many is a setting (a few by default). Under simpler motion they fade in place.
// Where: the face button in the plugin bar.

struct PipEmotes: SandboxPlugin {
    let info = PluginInfo(id: "emotes", name: "Pip's Emotes", version: "v1", shelf: .dream,
                          icon: "face.smiling", what: "Emoji bubbles over Pip. Other plugins can send them too.")

    // MARK: Data

    static let channel = Notification.Name("pip.emote")

    enum Amount: String, CaseIterable {
        case few, some, lots
        var label: String { rawValue.capitalized }
        /// The chance an event gets a bubble (bubbles sent by plugins always show).
        var chance: Double { ["few": 0.25, "some": 0.55, "lots": 1][rawValue] ?? 0.25 }
    }

    static func reaction(to event: PipEvent) -> [String] {
        switch event {
        case .appear: ["👀"]
        case .wake: ["👋", "🥱"]
        case .tap: ["💙", "😊", "✨", "🙂"]
        case .flick(let speed): speed > 1400 ? ["😆", "🌀"] : ["😄"]
        case .bump(let speed): speed > 1150 ? ["😵‍💫", "💫"] : ["😬"]
        case .rest: ["😌"]
        default: []
        }
    }

    // MARK: Logic

    func on(_ event: PipEvent, _ host: PipHost) {
        let amount = Amount(rawValue: host.value("emotes", "amount") ?? "") ?? .few
        guard Double.random(in: 0...1) < amount.chance, let emoji = Self.reaction(to: event).randomElement() else { return }
        NotificationCenter.default.post(name: Self.channel, object: emoji)
    }

    // MARK: Views

    func overlay(_ host: PipHost) -> some View { Bubbles(host: host) }

    func card(_ host: PipHost) -> some View { AmountCard(host: host) }

    struct Bubbles: View {
        let host: PipHost
        @State private var bubble: (emoji: String, id: Int)?
        @State private var count = 0
        @State private var risen = false

        var body: some View {
            ZStack {
                if let bubble, host.pipHere {
                    let p = host.pipPosition
                    Text(bubble.emoji)
                        .font(.system(size: 22))
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: .circle)
                        .scaleEffect(risen || host.simpler ? 1 : 0.4)
                        .opacity(risen ? 1 : 0)
                        .position(x: p.x + 18, y: p.y - (risen && !host.simpler ? 44 : 30))
                        .id(bubble.id)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: PipEmotes.channel)) { note in
                guard host.isOn("emotes"), let emoji = note.object as? String else { return }
                count += 1
                let mine = count
                risen = false
                bubble = (emoji, mine)
                withAnimation(host.simpler ? .easeOut(duration: 0.25) : .spring(duration: 0.35, bounce: 0.45)) { risen = true }
                host.later(1.6) {
                    guard count == mine else { return }
                    withAnimation(.easeIn(duration: 0.3)) { risen = false }
                    host.later(0.3) { if count == mine { bubble = nil } }
                }
            }
        }
    }

    struct AmountCard: View {
        let host: PipHost
        @AppStorage("plug.emotes.amount") private var amount = Amount.few.rawValue

        var body: some View {
            VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
                Text("How many bubbles").bold()
                HStack(spacing: 6) {
                    ForEach(Amount.allCases, id: \.self) { a in
                        Button(a.label) { amount = a.rawValue }
                            .buttonStyle(PluginCardButton(on: amount == a.rawValue))
                            .accessibilityAddTraits(amount == a.rawValue ? .isSelected : [])
                    }
                }
                Button("Try one") {
                    NotificationCenter.default.post(name: PipEmotes.channel, object: ["💙", "✨", "😆", "🫧"].randomElement()!)
                }
                .buttonStyle(PluginCardButton())
                .disabled(!host.pipHere)
            }
            .font(.system(size: 13.5))
        }
    }
}
