import SwiftUI
import UIKit

// DASHBOARD PANELS · part of the Dashboard plugin (Jules, 31 Oct; widget grid 1 Nov). Aaron: "my dashboard as a classic panels
// dashboard". The whole Glass Clock Progress dashboard full screen, laid out like Glass Clock's Panels interface:
// a glass sidebar of sections on the left and the chosen section's cards on a glass panel on the right.
// Opened from the Dashboard card ("Open as Panels"). Read-only, like the rest of the plugin: answers stay on the
// iPad and "Copy for the dashboard" makes a FOR DASHBOARD paste. No network, no timers, nothing moves on its own.
// Pip: says nothing here. Simpler motion: sections swap with no slide.

extension Dashboard {

    // MARK: Data


    // MARK: Views

    /// The button in the Dashboard card that opens the full-screen Panels dashboard.
    struct PanelsButton: View {
        let host: PipHost
        @State private var open = false

        var body: some View {
            Button {
                open = true
            } label: {
                Label("Open the dashboard", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PluginCardButton(on: true))
            .accessibilityHint("Opens the whole dashboard full screen, as widgets.")
            .fullScreenCover(isPresented: $open) {
                PanelsScreen(host: host) { open = false }
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    /// The plugin sections that live only here (Next action, the queue, Busy Pip, Stable & Sandbox), so the
    /// dashboard is in one place. They point `addsTo` at this slot instead of "dashboard", so the side card
    /// doesn't repeat them.
    static let panelsSlot = "dashboard.panels"

    /// THE dashboard (Aaron, 1 Nov: "widgets like this", from his live board): a grid of small glass widgets in
    /// three columns, Status · Actions · Direction. Each folds with – / +, remembered. Small by default: only
    /// At a glance, Needs you and Next action start open. Reads the live feed, so it updates while open.
    /// Private: Aaron's mission control. It lives in the Sandbox and never moves to Glass Clock.
    struct PanelsScreen: View {
        let host: PipHost
        let close: () -> Void
        @Bindable private var feed = Feed.shared
        /// Bumped when a question is answered, so counts redraw.
        @State private var taps = 0

        init(host: PipHost, close: @escaping () -> Void) {
            self.host = host
            self.close = close
        }

        var body: some View {
            let data = feed.data
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Corner.inset) {
                        header
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: Corner.inset) {
                                column("Status") { status(data) }
                                column("Actions") { actions(data) }
                                column("Direction") { direction(data) }
                            }
                            .frame(minWidth: 900)
                            VStack(spacing: Corner.inset) {
                                column("Status") { status(data) }
                                column("Actions") { actions(data) }
                                column("Direction") { direction(data) }
                            }
                        }
                    }
                    .padding(Corner.inset)
                    .padding(.top, 4)
                }

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
            .onAppear { feed.refresh() }
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROGRESS").font(.system(size: 11, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                Text(feed.data.source ?? "Glass Clock Progress").font(.system(size: 24, weight: .bold))
                Text(Dashboard.freshness).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.trailing, 70)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }

        private func column<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
            VStack(alignment: .leading, spacing: Corner.inset) {
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(.secondary).padding(.horizontal, 6)
                    .accessibilityAddTraits(.isHeader)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }

        /// A plugin's section, if that plugin is on.
        private func addOn(_ id: String) -> (any SandboxPlugin)? {
            host.plugins.first { $0.info.id == id && $0.addsTo == Dashboard.panelsSlot && $0.hasAddOn && host.isOn(id) }
        }

        @ViewBuilder private func plugin(_ id: String, icon: String, open: Bool = false) -> some View {
            if let p = addOn(id) {
                Widget(id: id, title: p.info.name, icon: icon, startsOpen: open) { p.anyAddOn(host) }
            }
        }

        @ViewBuilder private func status(_ data: DashboardData) -> some View {
            Widget(id: "glance", title: "At a glance", icon: "location", note: data.status?.updatedAt, startsOpen: true) {
                if let live = data.live { LiveNumbers(live: live) }
                StatusPanel(data: data, host: host)
            }
            Widget(id: "builds", title: "Builds", icon: "hammer", note: data.builds.map { "\($0.count)" }) {
                BuildsPanel(builds: data.builds ?? [])
            }
            plugin("stable", icon: "shield")
            plugin("busypip", icon: "gauge.with.dots.needle.33percent")
        }

        @ViewBuilder private func actions(_ data: DashboardData) -> some View {
            let _ = taps
            let waiting = (data.needsYou ?? []).filter { Dashboard.answer($0.q, host) == nil }.count
            Widget(id: "needs", title: "Needs you", icon: "questionmark.bubble",
                   note: waiting > 0 ? "\(waiting) waiting" : nil, startsOpen: true) {
                AsksPanel(asks: data.needsYou ?? [], host: host) { taps += 1 }
            }
            if let jobs = data.outboxForRob, !jobs.isEmpty {
                let waiting = jobs.filter { $0.done != true }.count
                Widget(id: "forrob", title: "For Rob", icon: "terminal",
                       note: waiting > 0 ? "\(waiting) to do" : "all done", startsOpen: waiting > 0) {
                    ForRobList(jobs: jobs)
                }
            }
            plugin("dashqueue", icon: "tray.full")
            Widget(id: "livefeed", title: "Live feed", icon: "antenna.radiowaves.left.and.right",
                   note: feed.on ? "on" : "off") {
                SettingsCard(footer: "Only downloads the board. Nothing is sent. Off shows the copy packed into the app.") {
                    Toggle("Follow the live dashboard", isOn: $feed.on)
                    if feed.on {
                        Button("Check now") { feed.refresh(force: true) }
                            .accessibilityHint("Downloads the latest board")
                    }
                }
            }
        }

        @ViewBuilder private func direction(_ data: DashboardData) -> some View {
            plugin("nextaction", icon: "arrow.right.circle", open: true)
            Widget(id: "upnext", title: "Up next", icon: "list.bullet", note: data.upNext.map { "\($0.count)" }) {
                UpNextPanel(steps: data.upNext ?? [])
            }
            Widget(id: "ideas", title: "Ideas", icon: "lightbulb", note: data.ideas.map { "\($0.count) ideas" }) {
                IdeasPanel(ideas: data.ideas ?? [])
            }
            Widget(id: "reminders", title: "Reminders", icon: "bell", note: data.reminders.map { "\($0.count)" }) {
                RemindersPanel(reminders: data.reminders ?? [])
            }
            Widget(id: "principles", title: "How we work", icon: "star") {
                PrinciplesPanel(principles: data.principles ?? [])
            }
        }
    }

    /// One glass widget on the dashboard, like the live board's: title, a small note on the right, – / + to fold.
    struct Widget<Content: View>: View {
        let title: String
        let icon: String
        let note: String?
        @ViewBuilder let content: () -> Content
        @AppStorage private var open: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        /// Your clock widget's saved style: the same card and colour as the widget (no look of its own).
        @State private var style = ClockStyle.load()

        init(id: String, title: String, icon: String, note: String? = nil, startsOpen: Bool = false,
             @ViewBuilder content: @escaping () -> Content) {
            self.title = title
            self.icon = icon
            self.note = note
            self.content = content
            _open = AppStorage(wrappedValue: startsOpen, "plug.dashboard.widget.\(id)")
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    if reduceMotion { open.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon).frame(width: 20).foregroundStyle(.secondary)
                        Text(title).font(.system(size: 16, weight: .bold))
                        Spacer(minLength: 4)
                        if let note {
                            Text(note).font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: open ? "minus" : "plus").font(.system(size: 13, weight: .semibold))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(note.map { "\(title), \($0)" } ?? title)
                .accessibilityValue(open ? "open" : "folded")
                .accessibilityHint(open ? "Folds it away" : "Opens it")

                if open {
                    VStack(alignment: .leading, spacing: Corner.inset) { content() }
                }
            }
            .padding(Corner.edge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(style.color == .auto ? AnyShapeStyle(.primary) : AnyShapeStyle(style.color.color))
            .modifier(ClockCard(style: style, shape: .rect(cornerRadius: 28)))
        }
    }

    /// Commands for Rob from the master chat: not done first, done ones greyed. Read-only (the text can be selected).
    struct ForRobList: View {
        let jobs: [DashboardData.RobJob]
        var body: some View {
            let ordered = jobs.filter { $0.done != true } + jobs.filter { $0.done == true }
            ForEach(ordered.indices, id: \.self) { i in
                let job = ordered[i]
                let done = job.done == true
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: done ? "checkmark.circle" : "circle")
                        Text(job.date ?? "").font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    Text(Dashboard.clean(job.command))
                        .font(.system(size: 12.5, design: .monospaced))
                        .lineLimit(done ? 2 : nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .opacity(done ? 0.5 : 1)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(done ? "Done" : "To do"), \(job.date ?? ""): \(Dashboard.clean(job.command))")
            }
        }
    }

    /// The live board's four numbers.
    struct LiveNumbers: View {
        let live: DashboardData.Live
        var body: some View {
            HStack {
                LiveNumber(value: live.needYou, label: "Need you")
                LiveNumber(value: live.toTry, label: "To try")
                LiveNumber(value: live.upNext, label: "Up next")
                LiveNumber(value: live.done, label: "Done")
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
