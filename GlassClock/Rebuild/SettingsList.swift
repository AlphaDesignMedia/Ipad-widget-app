import SwiftUI

/// Every group's settings as cards in one scrolling list (PLAN.md, rebuild step 3), with
/// Apply to Widget held at the bottom so it's always in reach. Classic shows the basics
/// (presets, the font and the colour) and a card that opens the rest; Panels has every group.
struct SettingsList: View {
    /// Just the basics, for Classic (rebuild step 4).
    var simple = false
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Gap.cards) {
                StyleCard(group: .presets, footer: SettingsSection.presets.footer) { PresetRows() }
                if !simple { StyleCard(group: .layout) { LayoutRows() } }
                StyleCard(group: .fonts) { FontRows(simple: simple) }
                StyleCard(group: .colour) { ColourRows(simple: simple) }
                if simple {
                    moreOptions
                } else {
                    StyleCard(group: .effects, footer: SettingsSection.effects.footer) { EffectRows() }
                    StyleCard(group: .card, footer: SettingsSection.card.footer) { CardRows() }
                    StyleCard(group: .homeScreens, footer: SettingsSection.homeScreens.footer) { HomeScreenRows() }
                    StyleCard(group: .accessibility,
                              footer: "Simpler effects turns off the lift, lean and light sweeps. Reduce glass swaps the glass for solid cards; it's also on when Reduce Transparency is on in the iPad's Settings.") {
                        AccessibilityRows()
                    }
                }
            }
            .padding(.vertical, Theme.Space.small)
        }
        .scrollIndicators(.hidden)
        // A soft fade at the top and bottom rather than a hard cut (owner, 22 Oct).
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .safeAreaInset(edge: .bottom, spacing: Theme.Space.small) { applyButton }
        // The same app colour for every switch, slider and selection.
        .tint(AppColor.chosen(appColor))
    }

    /// Classic's way to everything else: one plain tap switches to Panels.
    private var moreOptions: some View {
        StyleCard(group: nil) { moreOptionsButton }
    }

    private var moreOptionsButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : Theme.Motion.settle) { model.interface = .panels }
        } label: {
            HStack(spacing: Theme.Space.medium) {
                Image(systemName: InterfaceStyle.panels.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("More options in Panels")
                        .font(.headline)
                    Text("Layout, effects, the card, Home Screen colours and accessibility")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Theme.Padding.row)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Switches to Panels, which has every setting")
    }

    /// Prominent while there are changes to send; quiet clear glass once they're on the widget,
    /// rather than the greyed-out look of a disabled button, which read as broken.
    @ViewBuilder private var applyButton: some View {
        let label = Label(model.isApplied ? "Applied" : "Apply to Widget",
                          systemImage: model.isApplied ? "checkmark" : "square.and.arrow.down")
            .contentTransition(.symbolEffect(.replace))
            .frame(maxWidth: .infinity, minHeight: Theme.Size.tapTarget)
        Group {
            if model.isApplied {
                Button {} label: { label }
                    .buttonStyle(.glass)
                    .allowsHitTesting(false)
                    .accessibilityHint("The widget already shows this style")
            } else {
                Button(action: model.apply) { label }
                    .buttonStyle(.glassProminent)
                    .accessibilityHint("Sends this style to your Home Screen widget")
            }
        }
        .sensoryFeedback(.success, trigger: model.isApplied) { _, now in now }
    }
}

