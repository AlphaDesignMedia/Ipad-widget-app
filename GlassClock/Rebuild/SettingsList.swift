import SwiftUI

/// Every group's settings as cards in one scrolling list (PLAN.md, rebuild step 3), with
/// Apply to Widget held at the bottom so it's always in reach. Steps 4 and 5 arrange this list
/// as Classic and Panels; the list itself stays the same in both.
struct SettingsList: View {
    @Environment(AppModel.self) private var model
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Gap.cards) {
                StyleCard(group: .presets, footer: SettingsSection.presets.footer) { PresetRows() }
                StyleCard(group: .layout) { LayoutRows() }
                StyleCard(group: .fonts) { FontRows() }
                StyleCard(group: .colour) { ColourRows() }
                StyleCard(group: .effects, footer: SettingsSection.effects.footer) { EffectRows() }
                StyleCard(group: .card, footer: SettingsSection.card.footer) { CardRows() }
                StyleCard(group: .homeScreens, footer: SettingsSection.homeScreens.footer) { HomeScreenRows() }
                StyleCard(group: .accessibility,
                          footer: "Simpler effects turns off the lift, lean and light sweeps. Reduce glass swaps the glass for solid cards; it's also on when Reduce Transparency is on in the iPad's Settings.") {
                    AccessibilityRows()
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
