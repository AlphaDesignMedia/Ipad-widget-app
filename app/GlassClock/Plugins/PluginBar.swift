import SwiftUI

// The plugin bar, cards and Settings list. Sizes are the web sandbox's (#plugbar, .plugcard, button.pc
// in the PipPlugBar helper that every web plugin shares).

// MARK: Data

enum PluginBarLook {
    static let edge: CGFloat = 16           // from the screen's left edge
    static let barBottom: CGFloat = 14
    static let cardBottom: CGFloat = 70     // the card sits just above the bar
    static let button: CGFloat = 40
    static let buttonRadius: CGFloat = 17
    static let radius: CGFloat = 22         // bar and card
    static let barPadding: CGFloat = 4, barGap: CGFloat = 2
    static let cardWidth: CGFloat = 310, cardPadding: CGFloat = 14, cardGap: CGFloat = 10
}

/// A plugin's panel, sized like the app's own (ContentView: settings at least 320 wide, 16 from the edges).
/// Everything else about its look comes from the app's panel pieces: SettingsCard, Corner, PanelBacking.
enum PanelLook {
    static let width: CGFloat = 320
    static let margin: CGFloat = 16
    static let sideKey = "plugPanelLeading"     // which side it was last put down on
}

// MARK: Views

/// Every plugin's overlay, under Pip.
struct PluginOverlays: View {
    let host: PipHost
    var body: some View {
        ForEach(host.plugins.indices, id: \.self) { i in
            let p = host.plugins[i]
            if host.isOn(p.info.id) { p.anyOverlay(host) }
        }
    }
}

/// The bar of plugin buttons at the bottom left, and the open card above it (or the open panel, at the side).
/// Shown only while a plugin that has a card is on. Works with Pip switched off.
struct PluginBar: View {
    let host: PipHost
    let size: CGSize
    @AppStorage(PanelLook.sideKey) private var panelLeading = true

    private var withCards: [any SandboxPlugin] { host.plugins.filter { $0.hasCard && host.isOn($0.info.id) } }

    var body: some View {
        let items = withCards
        if !items.isEmpty {
            let open = host.openCard.flatMap { id in items.first { $0.info.id == id } }
            ZStack {
                if let open, open.info.panel {
                    PluginPanel(host: host, plugin: open, size: size)
                        .id(open.info.id)
                        .transition(host.simpler ? .opacity : .move(edge: panelLeading ? .leading : .trailing).combined(with: .opacity))
                }
                ZStack(alignment: .bottomLeading) {
                    if let open, !open.info.panel {
                        card(open)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { host.cardFrame = $0 }
                            .onDisappear { host.cardFrame = .null }
                            .padding(.bottom, PluginBarLook.cardBottom)
                            .transition(host.simpler ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                    }
                    let look = host.activeBarLook
                    let buttons = HStack(spacing: look?.gap ?? PluginBarLook.barGap) {
                        ForEach(items.indices, id: \.self) { i in button(items[i], look) }
                    }
                    Group {
                        if let look { look.bar(AnyView(buttons)) }
                        else {
                            buttons
                                .padding(PluginBarLook.barPadding)
                                .glassEffect(.regular, in: .rect(cornerRadius: PluginBarLook.radius))
                        }
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { host.barFrame = $0 }
                    .onDisappear { host.barFrame = .null }
                    .padding(.bottom, PluginBarLook.barBottom)
                }
                .padding(.leading, PluginBarLook.edge)
                .frame(width: size.width, height: size.height, alignment: .bottomLeading)
            }
        }
    }

    private func button(_ p: any SandboxPlugin, _ look: BarLook?) -> some View {
        let open = host.openCard == p.info.id
        let icon = Image(systemName: p.info.icon)
            .font(.system(size: 19))
            .frame(width: PluginBarLook.button, height: PluginBarLook.button)
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { host.openCard = open ? nil : p.info.id }
        } label: {
            if let look { look.button(AnyView(icon), open) }
            else {
                icon
                    .background(open ? Color.primary.opacity(0.1) : .clear,
                                in: .rect(cornerRadius: PluginBarLook.buttonRadius))
                    .contentShape(.rect(cornerRadius: PluginBarLook.buttonRadius))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(p.info.name)
        .accessibilityAddTraits(open ? .isSelected : [])
    }

    private func card(_ p: any SandboxPlugin) -> some View {
        VStack(alignment: .leading, spacing: PluginBarLook.cardGap) {
            Label(p.info.name, systemImage: p.info.icon)
                .font(.system(size: 16, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            ScrollView { p.anyCard(host).frame(maxWidth: .infinity, alignment: .leading) }
                .scrollBounceBehavior(.basedOnSize)
        }
        .padding(PluginBarLook.cardPadding)
        .frame(width: min(PluginBarLook.cardWidth, size.width - 32), alignment: .leading)
        .frame(maxHeight: size.height - 160, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: .rect(cornerRadius: PluginBarLook.radius))
    }
}

/// A plugin whose card opens as a panel (`PluginInfo.panel`), made of the app's own panel pieces so it
/// looks and moves like the settings: it slides in from its side; hold a card's title bar, then drag, to
/// carry it to the other side; flick a title bar towards its edge to tuck it aside (tap it to bring it
/// back), and push it again to close it. Other plugins add their sections under its cards (`addsTo`).
struct PluginPanel: View {
    let host: PipHost
    let plugin: any SandboxPlugin
    let size: CGSize
    @AppStorage(PanelLook.sideKey) private var leading = true
    @AppStorage("appTheme") private var theme = AppTheme.home
    @AppStorage("reduceGlass") private var reducesGlass = false
    @AppStorage(CarryStyle.key) private var carryStyle = CarryStyle.lift
    @AppStorage("simpleMotion") private var simpleMotion = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reducesTransparency
    @State private var tucked = false
    @State private var carried = false
    @State private var move = CGSize.zero
    @State private var grab: CarryGrab?
    @State private var rest = CGRect.zero
    @State private var area = CGRect.zero

    private var simple: Bool { systemReduceMotion || simpleMotion }
    private var width: CGFloat { min(PanelLook.width, size.width - PanelLook.margin * 2) }
    private var addOns: [any SandboxPlugin] {
        host.plugins.filter { $0.addsTo == plugin.info.id && $0.hasAddOn && host.isOn($0.info.id) }
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            cards
            ScrollView { cards }.scrollIndicators(.hidden)
        }
        .modifier(ScrollEdges(fades: glassy))
        // In the Glass theme each card is its own glass; otherwise the panel has glass behind its cards.
        .modifier(PanelBacking(clear: glassy))
        .frame(width: width)
        // Measured at rest, before the lift and the carry, like the app's panels.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if !carried { rest = $0; report() } }
        .modifier(CarriedShape(carried: carried, style: carryStyle,
                               icon: grab?.icon ?? plugin.info.icon, title: grab?.title ?? plugin.info.name, simple: simple,
                               hold: grab.map { CGPoint(x: $0.point.x - rest.minX, y: $0.point.y - rest.minY) },
                               size: rest.size))
        .scaleEffect(carried ? 1.025 : 1)
        .shadow(color: .black.opacity(carried ? 0.2 : 0), radius: 22, y: 12)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: carried)
        .offset(move)
        .modifier(Peek(on: tucked, towardsLeading: leading, width: width, simple: simple,
                       wake: { setTucked(false) }, further: close))
        .environment(\.panelCarry, PanelCarry(
            grabbed: { g in if grab == nil { grab = g } },
            moved: { m in
                if !carried { carried = true }
                move = m
            },
            ended: putDown,
            flicked: { towardsLeading in setTucked(towardsLeading == leading) }))
        .sensoryFeedback(.impact(weight: .medium), trigger: carried) { _, lifted in lifted }
        .padding(.horizontal, PanelLook.margin)
        .padding(.top, PanelLook.margin)
        .padding(.bottom, PluginBarLook.cardBottom)
        .frame(width: size.width, height: size.height, alignment: leading ? .topLeading : .topTrailing)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { area = $0 }
        .onChange(of: tucked) { report() }
        .onDisappear { host.panelFrame = .null }
    }

    private var glassy: Bool { theme.isGlassy && !reducesGlass && !reducesTransparency }

    private var cards: some View {
        VStack(spacing: Corner.inset) {
            plugin.anyCard(host)
            ForEach(addOns.indices, id: \.self) { i in
                let p = addOns[i]
                SettingsCard(title: p.info.name, icon: p.info.icon) { p.anyAddOn(host) }
            }
        }
        .padding(Corner.edge)
    }

    private func setTucked(_ on: Bool) {
        withAnimation(simple ? nil : .spring(response: 0.45, dampingFraction: 0.85)) { tucked = on }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) { host.openCard = nil }
    }

    /// Put down on the side the finger let go, gliding home from exactly where it was dropped.
    private func putDown(_ moved: CGSize?) {
        if let moved {
            let finger = grab.map { CGPoint(x: $0.point.x + moved.width, y: $0.point.y + moved.height) }
                ?? CGPoint(x: rest.midX + moved.width, y: rest.midY + moved.height)
            let toLeading = finger.x < area.midX
            if toLeading != leading {
                let home = toLeading ? area.minX + PanelLook.margin : area.maxX - PanelLook.margin - rest.width
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) {
                    leading = toLeading
                    move = CGSize(width: moved.width - (home - rest.minX), height: moved.height)
                }
            }
        }
        grab = nil
        withAnimation(simple ? nil : ContentView.cardLand) {
            move = .zero
            carried = false
        }
    }

    /// Tells the host where the panel is, so the Pencil leaves it alone (and only its edge, when tucked).
    private func report() {
        let away: CGFloat = leading ? -1 : 1
        host.panelFrame = tucked ? rest.offsetBy(dx: away * (width - Peek.showing), dy: 0) : rest
    }
}

/// A button inside a plugin card (the web's button.pc): `.buttonStyle(PluginCardButton())`,
/// or `PluginCardButton(on: true)` for one that's selected.
struct PluginCardButton: ButtonStyle {
    var on = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(on ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(on ? PipLook.accent : Color.primary.opacity(0.08), in: .rect(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// The plugins in Settings: one switch each, grouped by shelf, with the reason if the host switched one off.
struct PluginList: View {
    private let host = PipHost.shared

    var body: some View {
        ForEach(PluginShelf.allCases) { shelf in
            let items = host.plugins.filter { $0.info.shelf == shelf }
            if !items.isEmpty {
                Text(shelf.label).font(.caption).foregroundStyle(.secondary)
                ForEach(items.indices, id: \.self) { i in row(items[i]) }
            }
        }
    }

    private func row(_ p: any SandboxPlugin) -> some View {
        let id = p.info.id
        return VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(get: { host.isOn(id) }, set: { host.setOn(id, $0) })) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.info.name)
                        Text(p.info.what).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: p.info.icon) }
            }
            .disabled(host.broken[id] != nil)
            if let reason = host.broken[id] {
                Text(reason).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
