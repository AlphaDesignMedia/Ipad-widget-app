import SwiftUI
import UIKit

// DASHBOARD WIDGET · part of the Dashboard plugin (Jules, 31 Oct). Aaron: "my dashboard in the style of
// Glass Clock, because that's how it all started", and it shouldn't slow the app down.
// 1. The widget: the dashboard as one Glass Clock glass tile, in the app's own glass (`appGlass`). Where we are,
//    the next step, and how many things need you. Built from the packed dashboard.json once; no timers, nothing
//    animates, so it costs nothing while it sits there. Until the core can put a plugin's widget on the canvas
//    (asked of Greg in AGENT-NOTES), it shows at the top of the Dashboard card.
// 2. Answering: each "Needs you" question gets three big buttons. Your answers stay on the iPad, and "Copy for
//    the dashboard" makes a FOR DASHBOARD paste to send on. Nothing leaves the app on its own.
// Pip: at most one short line, and only when you answer everything. Works the same with Pip off.
// Simpler motion: nothing here moves anyway.

extension Dashboard {

    // MARK: Data

    enum Answer: String, CaseIterable {
        case yes, notYet, talk
        var label: String {
            switch self {
            case .yes: "Yes"
            case .notYet: "Not yet"
            case .talk: "Let's talk"
            }
        }
        /// How it reads in the paste.
        var said: String {
            switch self {
            case .yes: "yes, as suggested"
            case .notYet: "not yet"
            case .talk: "let's talk about it"
            }
        }
    }

    static let doneLine = "All answered. Lovely."
    static let widgetWidth: CGFloat = 340

    // MARK: Logic

    /// The headline's first sentence, so the widget stays a glance.
    static func glance(_ text: String) -> String {
        let clean = Dashboard.clean(text)
        guard let end = clean.range(of: ". ") else { return clean }
        return String(clean[..<end.lowerBound]) + "."
    }

    @MainActor static func answer(_ q: String, _ host: PipHost) -> Answer? {
        (host.value("dashboard", stableKey(q)) as String?).flatMap(Answer.init(rawValue:))
    }

    /// Answers are kept by question, so a new board with new questions starts fresh. (Not `hashValue`: that
    /// changes every launch.)
    static func stableKey(_ q: String) -> String {
        var h: UInt64 = 5381
        for b in q.utf8 { h = (h &* 33) &+ UInt64(b) }
        return "answer.\(h)"
    }

    @MainActor static func setAnswer(_ a: Answer?, _ q: String, _ host: PipHost) {
        host.setValue(a?.rawValue, "dashboard", stableKey(q))
    }

    /// The FOR DASHBOARD paste: every answered question, in plain words.
    @MainActor static func paste(_ asks: [DashboardData.Ask], _ host: PipHost) -> String {
        let lines = asks.compactMap { ask -> String? in
            guard let a = answer(ask.q, host) else { return nil }
            return "- \(Dashboard.clean(ask.q)) → \(a.said)"
        }
        return (["FOR DASHBOARD · Aaron's answers from the iPad"] + lines).joined(separator: "\n")
    }

    // MARK: Views

    /// The widget: one glass tile, like the clock's neighbours.
    struct GlassTile: View {
        let data: DashboardData
        let waiting: Int

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("PROGRESS").font(.system(size: 11, weight: .semibold)).tracking(1.2)
                    Spacer(minLength: 8)
                    if let when = Dashboard.date(data.syncedAt) {
                        Text(when).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.secondary)
                if let headline = data.status?.headline {
                    Text(Dashboard.glance(headline))
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let next = data.upNext?.first {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "arrow.right.circle").font(.system(size: 13))
                        Text(Dashboard.clean(next.title)).font(.system(size: 14)).lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Next: \(Dashboard.clean(next.title))")
                }
                HStack(spacing: 8) {
                    Chip(icon: "questionmark.bubble", text: waiting == 0 ? "Nothing needs you" : "\(waiting) need\(waiting == 1 ? "s" : "") you",
                         lit: waiting > 0)
                    if let due = data.reminders, !due.isEmpty {
                        Chip(icon: "bell", text: "\(due.count) reminder\(due.count == 1 ? "" : "s")", lit: false)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: Dashboard.widgetWidth, alignment: .leading)
            .appGlass(RoundedRectangle(cornerRadius: Corner.card, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Progress dashboard")
        }
    }

    struct Chip: View {
        let icon: String
        let text: String
        let lit: Bool

        var body: some View {
            Label(text, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.primary.opacity(lit ? 0.12 : 0.05)))
        }
    }

    /// The widget, then the questions with their buttons. Shown at the top of the Dashboard card.
    struct Front: View {
        let data: DashboardData
        let host: PipHost
        /// Bumped on every tap, so the counts and buttons redraw (answers live in storage).
        @State private var taps = 0
        @State private var copied = false

        var body: some View {
            let asks = data.needsYou ?? []
            let _ = taps
            let waiting = asks.filter { Dashboard.answer($0.q, host) == nil }.count
            VStack(alignment: .leading, spacing: Corner.inset) {
                GlassTile(data: data, waiting: waiting)
                    .frame(maxWidth: .infinity)
                if !asks.isEmpty {
                    SettingsCard(title: "Needs you", icon: "questionmark.bubble") {
                        ForEach(asks.indices, id: \.self) { i in
                            question(asks[i], asks)
                        }
                        Button {
                            UIPasteboard.general.string = Dashboard.paste(asks, host)
                            copied = true
                        } label: {
                            Label(copied ? "Copied. Paste it to the team" : "Copy for the dashboard",
                                  systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(PluginCardButton(on: waiting < asks.count))
                        .disabled(waiting == asks.count)
                        .accessibilityHint("Copies your answers as a FOR DASHBOARD message.")
                    }
                }
            }
        }

        private func question(_ ask: DashboardData.Ask, _ asks: [DashboardData.Ask]) -> some View {
            let picked = Dashboard.answer(ask.q, host)
            return VStack(alignment: .leading, spacing: 6) {
                Text(Dashboard.clean(ask.q))
                if let s = ask.suggested {
                    Text(Dashboard.clean(s)).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: PluginBarLook.cardGap) {
                    ForEach(Answer.allCases, id: \.self) { a in
                        Button(a.label) {
                            Dashboard.setAnswer(picked == a ? nil : a, ask.q, host)
                            copied = false
                            taps += 1
                            if asks.allSatisfy({ Dashboard.answer($0.q, host) != nil }), host.joy > 0,
                               PipTalkTurns.spend(host) {
                                host.say(Dashboard.doneLine, for: 1.8)
                            }
                        }
                        .buttonStyle(PluginCardButton(on: picked == a))
                        .accessibilityLabel("\(a.label): \(Dashboard.clean(ask.q))")
                        .accessibilityAddTraits(picked == a ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
