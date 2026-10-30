import SwiftUI

/// The rebuilt app (PLAN.md, "The rebuild"). Steps 1 to 3: the backdrop, the widget at real
/// size on a Home Screen grid (drag it to a slot, pinch to resize), and the settings as cards
/// with Apply to Widget, on the shared model. Debug builds open it with `-rebuild YES`
/// (`Scripts/run-on-ipad.sh --rebuild`); until step 8 the old app stays the default.
/// The settings sit beside the stage when there's room and below it when there isn't. Classic
/// (step 4) shows just the basics. Panels (step 5) has every group, as panels you can carry
/// to either side or put aside, when the window has room; in a narrow window it's stacked.
struct RebuildRoot: View {
    @State private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }

    /// The app as it was left, or a fixed sample for Previews.
    @MainActor init(model: AppModel? = nil) {
        _model = State(initialValue: model ?? AppModel())
    }

    var body: some View {
        StageBackdrop(backdrop: model.backdrop, homeScreen: model.homeScreen)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: Theme.Space.medium) {
                    interfaceSwitch
                    arrangement
                }
                .padding(Theme.Space.medium)
            }
            .environment(model)
    }

    /// The stage and the settings, side by side or stacked.
    private var arrangement: some View {
        GeometryReader { space in
            if space.size.width >= Theme.Size.sideBySide && model.interface == .panels {
                PanelsLayout(window: space.size)
                    .transition(.opacity)
            } else if space.size.width >= Theme.Size.sideBySide {
                HStack(spacing: Theme.Gap.panels) {
                    if model.settingsLeading { settings.frame(width: Theme.Size.settingsColumn) }
                    Stage()
                    if !model.settingsLeading { settings.frame(width: Theme.Size.settingsColumn) }
                }
            } else {
                VStack(spacing: Theme.Gap.panels) {
                    Stage().frame(height: space.size.height * 0.4)
                    settings
                }
            }
        }
    }

    private var settings: some View {
        SettingsList(simple: model.interface == .classic)
            .id(model.interface)
            .transition(.opacity)
    }

    /// Classic (the basics) or Panels (everything), one tap away at the top.
    private var interfaceSwitch: some View {
        GlassPicker("Interface", selection: Binding(
            get: { model.interface },
            set: { next in withAnimation(reduceMotion ? nil : Theme.Motion.settle) { model.interface = next } }
        ), options: InterfaceStyle.allCases) { $0.label }
        .frame(width: 220)
        .glassEffect(.regular, in: .capsule)
        .accessibilityHint("Classic keeps things simple; Panels has every setting")
    }
}

// Sized like the real screens, whichever device Xcode has picked: the M1 iPad Pro 12.9-inch
// both ways round, and an iPhone.
#Preview("iPad 12.9 landscape", traits: .fixedLayout(width: 1366, height: 1024)) {
    RebuildRoot(model: AppModel(sample: ClockStyle()))
}

#Preview("iPad 12.9 portrait", traits: .fixedLayout(width: 1024, height: 1366)) {
    RebuildRoot(model: AppModel(sample: ClockStyle(), interface: .panels, homeScreen: .dark, backdrop: .midnight))
}

#Preview("iPhone", traits: .fixedLayout(width: 393, height: 852)) {
    RebuildRoot(model: AppModel(sample: ClockStyle(), size: .small))
}
