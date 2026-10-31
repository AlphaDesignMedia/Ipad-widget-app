import SwiftUI
import UIKit

// PIP, DESIGN PARTNER · plugin v2 (On trial; grown from Idea inbox, 31 Oct 2026, Chappie's brief + Aaron's "go").
// A small creative workspace with Pip living in it. Jot an idea, move it through five stages, and copy a
// FOR CHAPPIE paste to take to Chappie. Nothing leaves the iPad on its own: no AI, no network.
// - Stages: SPARK · EXPERIMENT · DEVELOP · APPROVED · PARKED. Ideas never become tasks by themselves.
// - APPROVED needs Aaron's own tap ("Send to the dashboard?"). Yes copies a FOR DASHBOARD paste (the dashboard
//   is hand-synced), so it's still Aaron who sends it.
// - Pip perches on the idea you last touched and is happy about a new one. Only inside the panel: no overlay,
//   no timers, still when idle. With Pip off there's no Pip and no lines; the workspace works the same.
// - Later, not v1: screenshots, references, notes, variations. `extras` keeps room for them in the data.
// Keeps the id "ideainbox" so ideas saved in the old inbox carry over (they start as SPARK).
// Keeper: Jules (until Aaron takes it on).

struct IdeaInbox: SandboxPlugin {
    let info = PluginInfo(id: "ideainbox", name: "Pip, design partner", version: "v2", shelf: .trial,
                          icon: "lightbulb", what: "A little creative workspace with Pip in it. Catch ideas, move them on, take them to Chappie.",
                          panel: true)

    // MARK: Data

    static let storeKey = "plug.ideainbox.ideas"
    static let greeting = "What are we exploring today?"
    static let pipLines = [
        "Ooh, I like that one.",
        "Written down. I'll keep it safe.",
        "That's a good one.",
    ]

    enum Stage: String, Codable, CaseIterable, Identifiable {
        case spark, experiment, develop, approved, parked
        var id: Self { self }
        var label: String { rawValue.uppercased() }
        var emoji: String {
            switch self {
            case .spark: "🌱"
            case .experiment: "✏️"
            case .develop: "💡"
            case .approved: "👍"
            case .parked: "🅿️"
            }
        }
    }

    struct Idea: Codable, Identifiable, Equatable {
        var id = UUID()
        var text: String
        var tag: String?            // from the old inbox
        var at = Date()
        var stage: Stage?           // nil (old ideas) reads as SPARK
        var extras: [String]?       // later: screenshots, references, notes, variations
        var place: Stage { stage ?? .spark }
    }

    // MARK: Logic

    static func decode(_ text: String) -> [Idea] {
        (try? JSONDecoder().decode([Idea].self, from: Data(text.utf8))) ?? []
    }

    static func encode(_ ideas: [Idea]) -> String {
        (try? String(data: JSONEncoder().encode(ideas), encoding: .utf8)) ?? ""
    }

    static func day(_ d: Date) -> String {
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_GB")
        out.dateFormat = "d MMM"
        return out.string(from: d)
    }

    /// Every idea, grouped by stage, ready to paste to Chappie.
    static func forChappie(_ ideas: [Idea]) -> String {
        var lines = ["📋 FOR CHAPPIE · Pip, design partner · \(day(.now))"]
        for s in Stage.allCases {
            let these = ideas.filter { $0.place == s }
            guard !these.isEmpty else { continue }
            lines.append("\(s.emoji) \(s.label)")
            lines += these.map { "- \($0.text)" }
        }
        lines.append("Please help me think these through. End with a FOR JULES block.")
        return lines.joined(separator: "\n")
    }

    /// One approved idea for the dashboard's idea shelf.
    static func forDashboard(_ idea: Idea) -> String {
        "FOR DASHBOARD · idea approved by Aaron (\(day(.now)))\n👍 \(idea.text)"
    }

    /// Pip's happy line comes once a session at most.
    static var pipSpoke = false

    // MARK: Views

    func card(_ host: PipHost) -> some View { Workspace(host: host) }

    struct Workspace: View {
        let host: PipHost
        @AppStorage(IdeaInbox.storeKey) private var stored = ""
        @State private var draft = ""
        @State private var perch: UUID?          // the idea Pip sits by
        @State private var fresh: UUID?          // the newest idea, so Pip looks pleased
        @State private var asking: Idea?         // waiting on "Send to the dashboard?"
        @State private var copied: String?
        @Namespace private var pipSpot

        var body: some View {
            let ideas = IdeaInbox.decode(stored)
            VStack(spacing: Corner.inset) {
                SettingsCard(title: "Today", icon: "lightbulb") {
                    if host.pipHere {
                        HStack(spacing: 8) {
                            PipBody(face: .curious, size: 18)
                                .accessibilityHidden(true)
                            Text(IdeaInbox.greeting).font(.system(size: 15, weight: .semibold))
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("An idea, in a few words", text: $draft, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit(save)
                            .accessibilityLabel("New idea")
                        Button(action: save) { Image(systemName: "plus") }
                            .buttonStyle(PluginCardButton(on: true))
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel("Save idea")
                    }
                }

                SettingsCard(title: "Idea garden", icon: "leaf",
                             footer: "Ideas stay on this iPad. Only your yes sends one to the dashboard.") {
                    if ideas.isEmpty {
                        Text("Nothing growing yet. Jot one above.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Stage.allCases) { s in
                        let these = ideas.filter { $0.place == s }
                        if !these.isEmpty {
                            Text("\(s.emoji) \(s.label)")
                                .font(.system(size: 11, weight: .semibold)).tracking(1.2)
                                .foregroundStyle(.secondary)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(these) { idea in row(idea) }
                        }
                    }
                    if copied == "dashboard" {
                        Label("Approved. The FOR DASHBOARD paste is copied, ready to send.", systemImage: "checkmark")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if !ideas.isEmpty {
                    Button {
                        UIPasteboard.general.string = IdeaInbox.forChappie(ideas)
                        copied = "chappie"
                    } label: {
                        Label(copied == "chappie" ? "Copied. Paste it to Chappie" : "Copy for Chappie",
                              systemImage: copied == "chappie" ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(PluginCardButton(on: true))
                    .accessibilityHint("Copies every idea, by stage, as a FOR CHAPPIE message.")
                }
            }
            .confirmationDialog("Send to the dashboard?", isPresented: Binding(get: { asking != nil },
                                                                              set: { if !$0 { asking = nil } }),
                                titleVisibility: .visible, presenting: asking) { idea in
                Button("Yes, it's approved") { approve(idea) }
                Button("Not yet", role: .cancel) { asking = nil }
            } message: { idea in
                Text("“\(idea.text)” moves to APPROVED, and a FOR DASHBOARD paste is copied for you to send.")
            }
        }

        private func row(_ idea: Idea) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Menu {
                    ForEach(Stage.allCases) { s in
                        Button("\(s.emoji) \(s.label)") { move(idea, to: s) }
                            .disabled(s == idea.place)
                    }
                } label: {
                    Text(idea.place.emoji)
                }
                .accessibilityLabel("Stage: \(idea.place.label). Change stage")

                Text(idea.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    .onTapGesture { sit(by: idea.id) }

                if host.pipHere, perch == idea.id {
                    PipBody(face: fresh == idea.id ? .happy : .curious, size: 16)
                        .matchedGeometryEffect(id: "pip", in: pipSpot)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }

                Button { remove(idea) } label: { Image(systemName: "trash") }
                    .buttonStyle(PluginCardButton())
                    .accessibilityLabel("Delete idea: \(idea.text)")
            }
        }

        private func sit(by id: UUID) {
            if host.simpler { perch = id } else { withAnimation(.easeOut(duration: 0.25)) { perch = id } }
        }

        private func save() {
            let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            var ideas = IdeaInbox.decode(stored)
            let idea = Idea(text: text, stage: .spark)
            ideas.insert(idea, at: 0)
            stored = IdeaInbox.encode(ideas)
            draft = ""
            copied = nil
            fresh = idea.id
            sit(by: idea.id)
            if host.pipHere, host.joy > 0, !IdeaInbox.pipSpoke {
                IdeaInbox.pipSpoke = true
                host.say(IdeaInbox.pipLines.randomElement()!, for: 2.0)
            }
        }

        private func move(_ idea: Idea, to s: Stage) {
            if s == .approved { asking = idea; return }      // only Aaron's yes approves
            update(idea.id) { $0.stage = s }
            copied = nil
            sit(by: idea.id)
        }

        private func approve(_ idea: Idea) {
            update(idea.id) { $0.stage = .approved }
            UIPasteboard.general.string = IdeaInbox.forDashboard(idea)
            copied = "dashboard"
            asking = nil
            sit(by: idea.id)
        }

        private func update(_ id: UUID, _ change: (inout Idea) -> Void) {
            var ideas = IdeaInbox.decode(stored)
            guard let i = ideas.firstIndex(where: { $0.id == id }) else { return }
            change(&ideas[i])
            stored = IdeaInbox.encode(ideas)
        }

        private func remove(_ idea: Idea) {
            stored = IdeaInbox.encode(IdeaInbox.decode(stored).filter { $0.id != idea.id })
            if perch == idea.id { perch = nil }
        }
    }
}
