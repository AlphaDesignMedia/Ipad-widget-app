import SwiftUI

// IDEA INBOX · plugin v1 (On trial). Jot an idea on the iPad in a few words, with an optional tag. Ideas stay on
// this device, newest first, and Share sends them all as plain text in the dashboard's style, ready to AirDrop
// or paste. No network. Works the same with Pip off; with Pip here, saving an idea gets one warm line a session.
// Where: a section in the Dashboard panel (no button of its own).

struct IdeaInbox: SandboxPlugin {
    let info = PluginInfo(id: "ideainbox", name: "Idea inbox", version: "v1", shelf: .trial,
                          icon: "lightbulb", what: "Jot an idea in a few words. Share them all when you're ready.")

    // MARK: Data

    static let storeKey = "plug.ideainbox.ideas"
    static let tags = ["Pip", "Clock", "Look", "Sandbox"]
    static let pipLines = [
        "Ooh, I like that one. Saved.",
        "Written down. I'll keep it safe.",
        "That's a good one. It's in the inbox.",
    ]

    struct Idea: Codable, Identifiable, Equatable {
        var id = UUID()
        var text: String
        var tag: String?
        var at = Date()
    }

    // MARK: Logic

    static func decode(_ text: String) -> [Idea] {
        (try? JSONDecoder().decode([Idea].self, from: Data(text.utf8))) ?? []
    }

    static func encode(_ ideas: [Idea]) -> String {
        (try? String(data: JSONEncoder().encode(ideas), encoding: .utf8)) ?? ""
    }

    /// One line per idea, in the dashboard's paste style, newest first.
    static func shareText(_ ideas: [Idea]) -> String {
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_GB")
        out.dateFormat = "d MMM"
        let lines = ideas.map { idea in
            "💡 \(idea.tag.map { "[\($0)] " } ?? "")\(idea.text) (\(out.string(from: idea.at)))"
        }
        return (["FOR DASHBOARD · Idea inbox"] + lines).joined(separator: "\n")
    }

    /// Pip's warm line comes once a session at most.
    static var pipSpoke = false

    // MARK: Views

    var addsTo: String? { "dashboard" }
    func addOn(_ host: PipHost) -> some View { Inbox(host: host) }

    struct Inbox: View {
        let host: PipHost
        @AppStorage(IdeaInbox.storeKey) private var stored = ""
        @State private var draft = ""
        @State private var tag: String?

        var body: some View {
            let ideas = IdeaInbox.decode(stored)
            VStack(alignment: .leading, spacing: 8) {
                Text("Idea inbox").bold()
                TextField("An idea, in a few words", text: $draft, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .accessibilityLabel("New idea")
                HStack(spacing: 6) {
                    ForEach(IdeaInbox.tags, id: \.self) { t in
                        Button(t) { tag = tag == t ? nil : t }
                            .buttonStyle(PluginCardButton(on: tag == t))
                            .accessibilityLabel("Tag \(t)")
                            .accessibilityAddTraits(tag == t ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                    Button("Save", action: save)
                        .buttonStyle(PluginCardButton(on: true))
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Save idea")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if ideas.isEmpty {
                Text("No ideas yet. They stay on this iPad until you share them.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(ideas) { idea in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let t = idea.tag {
                                Text(t.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            Text(idea.text)
                        }
                        .accessibilityElement(children: .combine)
                        Spacer(minLength: 0)
                        Button {
                            remove(idea)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(PluginCardButton())
                        .accessibilityLabel("Delete idea: \(idea.text)")
                    }
                }
                ShareLink(item: IdeaInbox.shareText(ideas)) {
                    Label("Share all (\(ideas.count))", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PluginCardButton())
                .accessibilityLabel("Share all \(ideas.count) ideas as text")
            }
        }

        private func save() {
            let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            var ideas = IdeaInbox.decode(stored)
            ideas.insert(Idea(text: text, tag: tag), at: 0)
            stored = IdeaInbox.encode(ideas)
            draft = ""
            tag = nil
            if host.pipHere && !IdeaInbox.pipSpoke {
                IdeaInbox.pipSpoke = true
                host.say(IdeaInbox.pipLines.randomElement()!, for: 2.4)
            }
        }

        private func remove(_ idea: Idea) {
            stored = IdeaInbox.encode(IdeaInbox.decode(stored).filter { $0.id != idea.id })
        }
    }
}
