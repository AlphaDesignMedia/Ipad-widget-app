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

/// The bar of plugin buttons at the bottom left, and the open card above it.
/// Shown only while a plugin that has a card is on. Works with Pip switched off.
struct PluginBar: View {
    let host: PipHost
    let size: CGSize

    private var withCards: [any SandboxPlugin] { host.plugins.filter { $0.hasCard && host.isOn($0.info.id) } }

    var body: some View {
        let items = withCards
        if !items.isEmpty {
            ZStack(alignment: .bottomLeading) {
                if let id = host.openCard, let p = items.first(where: { $0.info.id == id }) {
                    card(p)
                        .padding(.bottom, PluginBarLook.cardBottom)
                        .transition(host.simpler ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                }
                HStack(spacing: PluginBarLook.barGap) {
                    ForEach(items.indices, id: \.self) { i in button(items[i]) }
                }
                .padding(PluginBarLook.barPadding)
                .glassEffect(.regular, in: .rect(cornerRadius: PluginBarLook.radius))
                .padding(.bottom, PluginBarLook.barBottom)
            }
            .padding(.leading, PluginBarLook.edge)
            .frame(width: size.width, height: size.height, alignment: .bottomLeading)
        }
    }

    private func button(_ p: any SandboxPlugin) -> some View {
        let open = host.openCard == p.info.id
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { host.openCard = open ? nil : p.info.id }
        } label: {
            Image(systemName: p.info.icon)
                .font(.system(size: 19))
                .frame(width: PluginBarLook.button, height: PluginBarLook.button)
                .background(open ? Color.primary.opacity(0.1) : .clear,
                            in: .rect(cornerRadius: PluginBarLook.buttonRadius))
                .contentShape(.rect(cornerRadius: PluginBarLook.buttonRadius))
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
