import SwiftUI
import UIKit

// DASHBOARD PANELS · part of the Dashboard plugin (Jules, 31 Oct). Aaron: "my dashboard as a classic panels
// dashboard". The whole Glass Clock Progress dashboard full screen, laid out like Glass Clock's Panels interface:
// a glass sidebar of sections on the left and the chosen section's cards on a glass panel on the right.
// Opened from the Dashboard card ("Open as Panels"). Read-only, like the rest of the plugin: answers stay on the
// iPad and "Copy for the dashboard" makes a FOR DASHBOARD paste. No network, no timers, nothing moves on its own.
// Pip: says nothing here. Simpler motion: sections swap with no slide.

extension Dashboard {

    // MARK: Data

    enum PanelSection: String, CaseIterable, Identifiable {
        case status, needsYou, upNext, builds, ideas, reminders, principles
        var id: Self { self }

        var title: String {
            switch self {
            case .status: "Where we are"
            case .needsYou: "Needs you"
            case .upNext: "Up next"
            case .builds: "Builds"
            case .ideas: "Ideas"
            case .reminders: "Reminders"
            case .principles: "How we work"
            }
        }

        var icon: String {
            switch self {
            case .status: "location"
            case .needsYou: "questionmark.bubble"
            case .upNext: "arrow.right.circle"
            case .builds: "hammer"
            case .ideas: "lightbulb"
            case .reminders: "bell"
            case .principles: "star"
            }
        }

        /// The little number beside it in the sidebar, if it has one.
        @MainActor func count(_ data: DashboardData, _ host: PipHost) -> Int? {
            switch self {
            case .status: nil
            case .needsYou: (data.needsYou ?? []).filter { Dashboard.answer($0.q, host) == nil }.count
            case .upNext: data.upNext?.count
            case .builds: data.builds?.count
            case .ideas: data.ideas?.count
            case .reminders: data.reminders?.count
            case .principles: data.principles?.count
            }
        }
    }

    static let sidebarWidth: CGFloat = 280

    // MARK: Views

    /// The button in the Dashboard card that opens the full-screen Panels dashboard.
    struct PanelsButton: View {
        let host: PipHost
        @State private var open = false

        var body: some View {
            Button {
                open = true
            } label: {
                Label("Open as Panels", systemImage: "rectangle.split.3x1")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PluginCardButton(on: true))
            .accessibilityHint("Opens the whole dashboard full screen, with a sidebar of sections.")
            .fullScreenCover(isPresented: $open) {
                PanelsScreen(data: Dashboard.feed.data, host: host) { open = false }
            }
        }
    }

    /// The dashboard, full screen: sidebar on the left, the chosen panel on the right, a close button that's
    /// always there.
    struct PanelsScreen: View {
        let data: DashboardData
        let host: PipHost
        let close: () -> Void
        @State private var section = PanelSection.status
        /// Bumped when a question is answered, so the sidebar's counts redraw.
        @State private var taps = 0

        var body: some View {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color.indigo.opacity(0.55), Color.teal.opacity(0.45), Color.orange.opacity(0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                HStack(alignment: .top, spacing: Corner.inset) {
                    sidebar
                    panel
                }
                .padding(Corner.inset)

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .appGlass(Circle(), interactive: true)
                .padding(Corner.inset + 6)
                .accessibilityLabel("Close the dashboard")
            }
        }

        private var sidebar: some View {
            let _ = taps
            return VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PROGRESS").font(.system(size: 11, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                    Text(data.source ?? "Glass Clock Progress").font(.system(size: 20, weight: .bold))
                    Text(Dashboard.freshness).font(.system(size: 12)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
                .accessibilityElement(children: .combine)

                ForEach(PanelSection.allCases) { s in
                    sidebarRow(s)
                }
                Spacer(minLength: 0)
            }
            .padding(Corner.edge)
            .frame(width: Dashboard.sidebarWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .appGlass(RoundedRectangle(cornerRadius: Corner.panel, style: .continuous), panel: true)
        }

        private func sidebarRow(_ s: PanelSection) -> some View {
            let picked = section == s
            let count = s.count(data, host)
            return Button {
                if host.simpler {
                    section = s
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { section = s }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: s.icon).frame(width: 22)
                    Text(s.title)
                    Spacer(minLength: 4)
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(s == .needsYou ? 0.16 : 0.07)))
                    }
                }
                .font(.system(size: 15, weight: picked ? .semibold : .regular))
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: max(4, Corner.card - 4), style: .continuous)
                        .fill(picked ? PipLook.accent.opacity(0.22) : Color.clear)
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(count.map { "\(s.title), \($0)" } ?? s.title)
            .accessibilityAddTraits(picked ? .isSelected : [])
        }

        private var panel: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Corner.inset) {
                    Label(section.title, systemImage: section.icon)
                        .font(.system(size: 26, weight: .bold))
                        .padding(.trailing, 60)
                        .accessibilityAddTraits(.isHeader)
                    content
                }
                .padding(Corner.edge)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appGlass(RoundedRectangle(cornerRadius: Corner.panel, style: .continuous), panel: true)
        }

        @ViewBuilder private var content: some View {
            switch section {
            case .status: StatusPanel(data: data, host: host)
            case .needsYou: AsksPanel(asks: data.needsYou ?? [], host: host) { taps += 1 }
            case .upNext: UpNextPanel(steps: data.upNext ?? [])
            case .builds: BuildsPanel(builds: data.builds ?? [])
            case .ideas: IdeasPanel(ideas: data.ideas ?? [])
            case .reminders: RemindersPanel(reminders: data.reminders ?? [])
            case .principles: PrinciplesPanel(principles: data.principles ?? [])
            }
        }
    }

    /// Shown when a section has nothing in it.
    struct EmptyNote: View {
        let text: String
        var body: some View {
            SettingsCard { Text(text).foregroundStyle(.secondary) }
        }
    }

    struct StatusPanel: View {
        let data: DashboardData
        let host: PipHost

        var body: some View {
            let waiting = (data.needsYou ?? []).filter { Dashboard.answer($0.q, host) == nil }.count
            GlassTile(data: data, waiting: waiting)
            SettingsCard(title: "Where we are", icon: "location", footer: data.status?.updatedAt) {
                if let headline = data.status?.headline {
                    Text(Dashboard.clean(headline)).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let build = data.status?.ipadBuild {
                SettingsCard(title: "On the iPad", icon: "ipad.landscape") {
                    Text(build)
                    if let note = data.status?.ipadNote {
                        Text(Dashboard.clean(note)).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    struct AsksPanel: View {
        let asks: [DashboardData.Ask]
        let host: PipHost
        let answered: () -> Void
        @State private var taps = 0
        @State private var copied = false

        var body: some View {
            let _ = taps
            let waiting = asks.filter { Dashboard.answer($0.q, host) == nil }.count
            if asks.isEmpty {
                EmptyNote(text: "Nothing needs you right now.")
            } else {
                ForEach(asks.indices, id: \.self) { i in
                    question(asks[i])
                }
                SettingsCard(footer: "Your answers stay on this iPad until you paste them on.") {
                    Button {
                        UIPasteboard.general.string = Dashboard.paste(asks, host)
                        copied = true
                    } label: {
                        Label(copied ? "Copied. Paste it to the team" : "Copy for the dashboard",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PluginCardButton(on: waiting < asks.count))
                    .disabled(waiting == asks.count)
                    .accessibilityHint("Copies your answers as a FOR DASHBOARD message.")
                }
            }
        }

        private func question(_ ask: DashboardData.Ask) -> some View {
            let picked = Dashboard.answer(ask.q, host)
            return SettingsCard(highlighted: picked == nil) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Dashboard.clean(ask.q)).font(.system(size: 16, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let s = ask.suggested {
                        Text(Dashboard.clean(s)).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: PluginBarLook.cardGap) {
                        ForEach(Answer.allCases, id: \.self) { a in
                            Button(a.label) {
                                Dashboard.setAnswer(picked == a ? nil : a, ask.q, host)
                                copied = false
                                taps += 1
                                answered()
                            }
                            .buttonStyle(PluginCardButton(on: picked == a))
                            .accessibilityLabel("\(a.label): \(Dashboard.clean(ask.q))")
                            .accessibilityAddTraits(picked == a ? .isSelected : [])
                        }
                    }
                }
            }
        }
    }

    struct UpNextPanel: View {
        let steps: [DashboardData.Step]

        var body: some View {
            let areas = steps.reduce(into: [String]()) { list, step in
                let area = step.area ?? "Other"
                if !list.contains(area) { list.append(area) }
            }
            if steps.isEmpty {
                EmptyNote(text: "Nothing queued.")
            } else {
                ForEach(areas, id: \.self) { area in
                    SettingsCard(title: area, icon: "arrow.right.circle") {
                        let mine = steps.filter { ($0.area ?? "Other") == area }
                        ForEach(mine.indices, id: \.self) { i in
                            Text(Dashboard.clean(mine[i].title)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    struct BuildsPanel: View {
        let builds: [DashboardData.Build]

        var body: some View {
            if builds.isEmpty {
                EmptyNote(text: "No builds listed yet.")
            } else {
                ForEach(builds.indices, id: \.self) { i in
                    let b = builds[i]
                    SettingsCard(title: Dashboard.clean(b.title ?? "Build"), icon: "hammer", footer: Dashboard.date(b.at)) {
                        ForEach((b.changes ?? []).indices, id: \.self) { j in
                            Label(Dashboard.clean(b.changes?[j] ?? ""), systemImage: "checkmark")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    struct IdeasPanel: View {
        let ideas: [DashboardData.Idea]

        var body: some View {
            if ideas.isEmpty {
                EmptyNote(text: "The idea shelf is empty.")
            } else {
                SettingsCard(title: "The idea shelf", icon: "lightbulb", footer: "Ideas wait here. They're not jobs until Aaron says yes.") {
                    ForEach(ideas.indices, id: \.self) { i in
                        let idea = ideas[i]
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Dashboard.clean(idea.title ?? "")).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 6) {
                                if let status = idea.status {
                                    Text(status)
                                        .font(.system(size: 11, weight: .semibold))
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                                }
                                if let branch = idea.branch {
                                    Text(branch).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    struct RemindersPanel: View {
        let reminders: [DashboardData.Reminder]

        var body: some View {
            if reminders.isEmpty {
                EmptyNote(text: "No reminders.")
            } else {
                SettingsCard(title: "Reminders", icon: "bell") {
                    ForEach(reminders.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Dashboard.clean(reminders[i].title))
                            if let when = Dashboard.date(reminders[i].due) {
                                Text(when).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    struct PrinciplesPanel: View {
        let principles: [String]

        var body: some View {
            if principles.isEmpty {
                EmptyNote(text: "No principles listed.")
            } else {
                SettingsCard(title: "How we work", icon: "star") {
                    ForEach(principles.indices, id: \.self) { i in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(i + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(PipLook.accent)
                                .frame(width: 20, alignment: .trailing)
                            Text(Dashboard.clean(principles[i]))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
