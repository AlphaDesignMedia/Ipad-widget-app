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

    /// The button in the Dashboard card: switches the app to the Dashboard tab and puts the card away.
    struct PanelsButton: View {
        let host: PipHost

        var body: some View {
            Button {
                host.openCard = nil
                host.openScreen = "dashboard"
            } label: {
                Label("Open the dashboard", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PluginCardButton(on: true))
            .accessibilityHint("Shows the Dashboard tab, next to Classic and Panels.")
        }
    }

    /// The plugin sections that live only here (Next action, the queue, Busy Pip, Stable & Sandbox), so the
    /// dashboard is in one place. They point `addsTo` at this slot instead of "dashboard", so the side card
    /// doesn't repeat them.
    static let panelsSlot = "dashboard.panels"

    /// The dashboard's groups, like Panels' settings groups, in Status · Actions · Direction order.
    enum DashGroup: String, CaseIterable, Identifiable {
        case glance, builds, stable, busypip, needs, forrob, dashqueue, nextaction, upnext, ideas, reminders, principles
        var id: Self { self }

        var title: String {
            switch self {
            case .glance: "At a glance"
            case .builds: "Builds"
            case .stable: "Stable & Sandbox"
            case .busypip: "Busy Pip"
            case .needs: "Needs you"
            case .forrob: "For Rob"
            case .dashqueue: "Dashboard queue"
            case .nextaction: "Next action"
            case .upnext: "Up next"
            case .ideas: "Ideas"
            case .reminders: "Reminders"
            case .principles: "How we work"
            }
        }

        var icon: String {
            switch self {
            case .glance: "location"
            case .builds: "hammer"
            case .stable: "shield"
            case .busypip: "gauge.with.dots.needle.33percent"
            case .needs: "questionmark.bubble"
            case .forrob: "terminal"
            case .dashqueue: "tray.full"
            case .nextaction: "arrow.right.circle"
            case .upnext: "list.bullet"
            case .ideas: "lightbulb"
            case .reminders: "bell"
            case .principles: "star"
            }
        }

        /// Groups that come from another plugin (shown only while that plugin is on).
        var plugin: String? {
            switch self {
            case .stable: "stable"
            case .busypip: "busypip"
            case .dashqueue: "dashqueue"
            case .nextaction: "nextaction"
            default: nil
            }
        }
    }

    /// THE dashboard, as its own tab (Aaron, 1 Nov: "it should look more like the real Panels but function like a
    /// widget… don't remake what's already there"). Laid out like Panels, from Panels' own parts: the groups pill on
    /// the left (frosted glass, glossy bead, shimmer), a Home Screen of resizable widgets on the stage where the clock
    /// widget sits (DashboardHome.swift), and the settings column of `SettingsCard`s on the right. Picking a group glides
    /// the column to it; scrolling the column moves the bead. Tap a widget to glide its card in; hold it to resize.
    /// Narrow windows: icons only, widgets on top of the column.
    /// Private: Aaron's mission control. It lives in the Sandbox and never moves to Glass Clock.
    struct PanelsScreen: View {
        let host: PipHost
        @Bindable private var feed = Feed.shared
        /// Bumped when a question is answered, so counts redraw.
        @State private var taps = 0
        @State private var selected = DashGroup.glance
        @State private var jump: DashGroup?
        @State private var columnHeight: CGFloat = 800
        @Namespace private var bead
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @AppStorage("appTheme") private var appTheme = AppTheme.home
        @AppStorage("reduceGlass") private var reducesGlass = false
        @AppStorage("glassAmount") private var glassAmount = GlassAmount.standard
        @AppStorage(Tweak.frost.key) private var tweakFrost = Tweak.frost.standard

        init(host: PipHost) { self.host = host }

        var body: some View {
            let data = feed.data
            let groups = DashGroup.allCases.filter { shows($0, data) }
            GeometryReader { geo in
                let wide = geo.size.width >= 980
                HStack(alignment: .top, spacing: 16) {
                    groupsList(groups, iconsOnly: !wide)
                        .frame(width: wide ? 230 : 68)
                    if wide {
                        stage(data)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    column(groups, data, showsWidget: !wide)
                        .frame(width: wide ? min(440, max(360, geo.size.width * 0.33)) : nil)
                        .frame(maxWidth: wide ? nil : .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .onAppear { feed.refresh() }
        }

        private func shows(_ g: DashGroup, _ data: DashboardData) -> Bool {
            if let id = g.plugin { return addOn(id) != nil }
            if g == .forrob { return !(data.outboxForRob ?? []).isEmpty }
            return true
        }

        // MARK: Groups (Panels' groups pill)

        private func groupsList(_ groups: [DashGroup], iconsOnly: Bool) -> some View {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(groups) { g in groupButton(g, iconsOnly: iconsOnly) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                if appTheme.isGlassy && !reducesGlass {
                    GlassAmount.backing(GlassAmount.frosted(glassAmount, by: tweakFrost), in: .rect(cornerRadius: Corner.panel))
                }
            }
            .appGlass(.rect(cornerRadius: Corner.panel), panel: true)
            .animation(reduceMotion ? nil : .snappy, value: selected)
        }

        private func groupButton(_ g: DashGroup, iconsOnly: Bool) -> some View {
            let on = selected == g
            return Button {
                selected = g
                jump = g
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: g.icon).font(.body.weight(.semibold)).foregroundStyle(.tint).frame(width: 24)
                    if !iconsOnly {
                        Text(g.title).font(.body.weight(on ? .semibold : .regular)).foregroundStyle(.primary).lineLimit(1)
                        Spacer(minLength: 0)
                        if let n = badge(g) {
                            Text(n).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, iconsOnly ? 0 : 16)
                .padding(.vertical, iconsOnly ? 0 : 12)
                .frame(width: iconsOnly ? 44 : nil, height: iconsOnly ? 44 : nil)
                .background {
                    if on {
                        GlossyBead(shape: Capsule())
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                            .matchedGeometryEffect(id: "dashboard group", in: bead)
                    }
                }
                .shimmer(trigger: on, in: Capsule())
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(badge(g).map { "\(g.title), \($0)" } ?? g.title)
            .accessibilityAddTraits(on ? .isSelected : [])
        }

        private func badge(_ g: DashGroup) -> String? {
            let data = feed.data
            let _ = taps
            switch g {
            case .needs:
                let n = (data.needsYou ?? []).filter { Dashboard.answer($0.q, host) == nil }.count
                return n > 0 ? "\(n)" : nil
            case .forrob:
                let n = (data.outboxForRob ?? []).filter { $0.done != true }.count
                return n > 0 ? "\(n)" : nil
            case .upnext: return data.upNext.map { "\($0.count)" }
            case .ideas: return data.ideas.map { "\($0.count)" }
            default: return nil
            }
        }

        // MARK: Stage (a Home Screen of widgets, where the clock sits in Panels: DashboardHome.swift)

        private func stage(_ data: DashboardData) -> some View {
            ScrollView {
                board(data).padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }

        /// The widgets, and a hint under them. Tap a widget to glide its full card in; hold it to resize.
        /// ("Live · checked…" now shows only in At a glance, not twice.)
        private func board(_ data: DashboardData) -> some View {
            VStack(spacing: 14) {
                HomeBoard(host: host, data: data, taps: taps) { g in
                    selected = g
                    jump = g
                }
                Text("Tap a widget for its card. Hold it to change its size.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .modifier(PanelLabelBacking())
            }
        }

        // MARK: Column (Panels' settings column: SettingsCards, each group in turn)

        private func column(_ groups: [DashGroup], _ data: DashboardData, showsWidget: Bool) -> some View {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Corner.inset) {
                        if showsWidget {
                            board(data).frame(maxWidth: .infinity)
                        }
                        ForEach(groups) { g in
                            VStack(alignment: .leading, spacing: Corner.inset) { content(g, data) }
                                .id(g)
                                // The group crossing a line a third of the way down is the one in use, as in Panels.
                                .onGeometryChange(for: Bool.self) { p in
                                    let f = p.frame(in: .named("dashboardColumn"))
                                    let line = max(120, columnHeight / 3)
                                    return f.minY <= line && f.maxY >= line
                                } action: { onLine in
                                    if onLine, jump == nil, selected != g { selected = g }
                                }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "dashboardColumn")
                .scrollIndicators(.hidden)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { columnHeight = $0 }
                .onChange(of: jump) { _, to in
                    guard let to else { return }
                    if reduceMotion { proxy.scrollTo(to, anchor: .top) } else {
                        withAnimation(.smooth(duration: 0.45)) { proxy.scrollTo(to, anchor: .top) }
                    }
                    host.later(0.6) { jump = nil }
                }
            }
        }

        /// A plugin's section, if that plugin is on.
        private func addOn(_ id: String) -> (any SandboxPlugin)? {
            host.plugins.first { $0.info.id == id && $0.addsTo == Dashboard.panelsSlot && $0.hasAddOn && host.isOn(id) }
        }

        @ViewBuilder private func content(_ g: DashGroup, _ data: DashboardData) -> some View {
            switch g {
            case .glance:
                SettingsCard(title: "At a glance", icon: "location", footer: Dashboard.freshness) {
                    if let live = data.live { LiveNumbers(live: live) }
                    Toggle("Follow the live dashboard", isOn: $feed.on)
                        .accessibilityHint("Only downloads the board. Nothing is sent.")
                }
                StatusPanel(data: data, host: host)
            case .builds: BuildsPanel(builds: Array((data.builds ?? []).prefix(3)))
            case .needs: AsksPanel(asks: data.needsYou ?? [], host: host) { taps += 1 }
            case .forrob:
                SettingsCard(title: "For Rob", icon: "terminal") { ForRobList(jobs: data.outboxForRob ?? []) }
            case .upnext: UpNextPanel(steps: data.upNext ?? [])
            case .ideas: IdeasPanel(ideas: data.ideas ?? [])
            case .reminders: RemindersPanel(reminders: data.reminders ?? [])
            case .principles: PrinciplesPanel(principles: data.principles ?? [])
            case .stable, .busypip, .dashqueue, .nextaction:
                if let id = g.plugin, let p = addOn(id) {
                    SettingsCard(title: g.title, icon: g.icon) { p.anyAddOn(host) }
                }
            }
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
