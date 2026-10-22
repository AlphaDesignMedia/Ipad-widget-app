import SwiftUI

/// Panels (PLAN.md, rebuild step 5): the settings and the groups as panels on either side of
/// the stage. Hold a card's title (or anywhere on the groups) to pick a panel up and carry it
/// to the other side; flick it towards its edge to put it aside, and tap the tab left at the
/// edge to bring it back. Double-tap the stage to clear both panels away, and again to bring
/// them back.
struct PanelsLayout: View {
    let window: CGSize
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }

    /// Kept here rather than in each panel, so a panel put aside comes back as it left.
    @State private var settingsCarry = PanelLift()
    @State private var groupsCarry = PanelLift()

    var body: some View {
        HStack(spacing: Theme.Gap.panels) {
            if !model.groupsTrailing && !model.groupsAside { groups(leading: true) }
            if model.settingsLeading && !model.settingsAside { settings(leading: true) }
            stage
            if !model.settingsLeading && !model.settingsAside { settings(leading: false) }
            if model.groupsTrailing && !model.groupsAside { groups(leading: false) }
        }
        .overlay(alignment: .leading) { tabs(leading: true) }
        .overlay(alignment: .trailing) { tabs(leading: false) }
        .onAppear { connect() }
        .onChange(of: window.width) { connect() }
        .onChange(of: model.settingsLeading) { connect() }
        .onChange(of: model.groupsTrailing) { connect() }
    }

    /// Double-tap anywhere on it (the widget too) to clear the panels away or bring them back.
    private var stage: some View {
        Stage()
            .contentShape(.rect)
            .onTapGesture(count: 2) {
                let clear = !model.settingsAside || !model.groupsAside
                show(settings: !clear, groups: !clear)
            }
            .sensoryFeedback(.selection, trigger: model.settingsAside && model.groupsAside)
            .accessibilityAction(named: "Clear the panels away") { show(settings: false, groups: false) }
            .accessibilityAction(named: "Bring the panels back") { show(settings: true, groups: true) }
    }

    private func settings(leading: Bool) -> some View {
        SettingsList()
            .frame(width: Theme.Size.settingsColumn)
            .environment(\.panelLift, settingsCarry)
            .modifier(CarryEffect(carry: settingsCarry))
            .transition(.move(edge: leading ? .leading : .trailing).combined(with: .opacity))
    }

    private func groups(leading: Bool) -> some View {
        GroupsPanel(carry: groupsCarry)
            .modifier(CarryEffect(carry: groupsCarry))
            .transition(.move(edge: leading ? .leading : .trailing).combined(with: .opacity))
    }

    /// The tabs of panels put aside, at the edge they went to.
    @ViewBuilder private func tabs(leading: Bool) -> some View {
        VStack(spacing: Theme.Space.small) {
            if model.settingsAside && model.settingsLeading == leading {
                EdgeTab(title: "Settings", icon: "slider.horizontal.3", leading: leading) {
                    show(settings: true, groups: !model.groupsAside)
                }
            }
            if model.groupsAside && model.groupsTrailing != leading {
                EdgeTab(title: "Groups", icon: "square.stack", leading: leading) {
                    show(settings: !model.settingsAside, groups: true)
                }
            }
        }
        // Tucked half under the window's edge, so they read as tabs on something put away.
        .offset(x: leading ? -Theme.Space.medium : Theme.Space.medium)
    }

    private func show(settings: Bool, groups: Bool) {
        // Back from aside, a panel starts where it rests, not where the finger let it go.
        if settings && model.settingsAside { settingsCarry.offset = .zero }
        if groups && model.groupsAside { groupsCarry.offset = .zero }
        withAnimation(reduceMotion ? nil : Theme.Motion.settle) {
            model.settingsAside = !settings
            model.groupsAside = !groups
        }
    }

    /// Tells each carry its side, the window's width and what a drop does.
    private func connect() {
        settingsCarry.windowWidth = window.width
        groupsCarry.windowWidth = window.width
        settingsCarry.onLeading = model.settingsLeading
        groupsCarry.onLeading = !model.groupsTrailing
        settingsCarry.onDrop = { [model] drop in
            switch drop {
            case .stay: break
            case .otherSide: model.settingsLeading.toggle()
            case .aside: model.settingsAside = true
            }
        }
        groupsCarry.onDrop = { [model] drop in
            switch drop {
            case .stay: break
            case .otherSide: model.groupsTrailing.toggle()
            case .aside: model.groupsAside = true
            }
        }
    }
}

/// The groups as a column of icons in a glass pill: tap one (or run a finger along them) to
/// scroll the settings to it. Hold anywhere on the pill, then drag, to carry it.
private struct GroupsPanel: View {
    let carry: PanelLift
    @Environment(AppModel.self) private var model
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue

    /// The groups the settings list has a card for, in its order.
    static let groups: [SettingsSection] = [.presets, .layout, .fonts, .colour, .effects, .card, .homeScreens, .accessibility]
    private static let rowHeight: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Self.groups) { group in
                Button { model.jump(to: group) } label: {
                    Image(systemName: group.icon)
                        .font(.title3.weight(.semibold))
                        .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                        .foregroundStyle(model.jumpedTo == group ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                        .background {
                            if model.jumpedTo == group {
                                Circle().fill(AppColor.chosen(appColor))
                            }
                        }
                        .frame(height: Self.rowHeight)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(group.title)
                .accessibilityAddTraits(model.jumpedTo == group ? .isSelected : [])
            }
        }
        .padding(.vertical, Theme.Space.small)
        .padding(.horizontal, Theme.Space.small / 2)
        .glassEffect(.regular, in: .capsule)
        .modifier(CarryHandle(carry: carry, name: "groups"))
        // A plain finger run along the icons jumps through the groups; after a hold, the
        // finger carries the pill instead.
        .simultaneousGesture(scrub)
        .sensoryFeedback(.selection, trigger: model.jumps)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Groups")
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard !carry.lifted else { return }
                let index = Int((value.location.y - Theme.Space.small) / Self.rowHeight)
                guard Self.groups.indices.contains(index) else { return }
                let group = Self.groups[index]
                if group != model.jumpedTo { model.jump(to: group) }
            }
    }
}

/// What's left at the window's edge when a panel is put aside: tap it, or pull it inwards,
/// to bring the panel back.
private struct EdgeTab: View {
    let title: String
    let icon: String
    let leading: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(width: Theme.Size.tapTarget + Theme.Space.medium, height: 96)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .simultaneousGesture(
            DragGesture(minimumDistance: 12).onEnded { value in
                let inwards = leading ? value.translation.width : -value.translation.width
                if inwards > 30 { open() }
            }
        )
        .accessibilityLabel("Show \(title.lowercased())")
        .transition(.move(edge: leading ? .leading : .trailing).combined(with: .opacity))
    }
}
