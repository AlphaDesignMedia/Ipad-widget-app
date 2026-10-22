import SwiftUI

/// The rebuilt app (PLAN.md, "The rebuild"). Steps 1 to 3: the backdrop, the widget at real
/// size on a Home Screen grid (drag it to a slot, pinch to resize), and the settings as cards
/// with Apply to Widget, on the shared model. Debug builds open it with `-rebuild YES`
/// (`Scripts/run-on-ipad.sh --rebuild`); until step 8 the old app stays the default.
/// For now the settings sit beside the stage when there's room and below it when there isn't;
/// steps 4 and 5 turn these into Classic and Panels.
struct RebuildRoot: View {
    @State private var model: AppModel

    /// The app as it was left, or a fixed sample for Previews.
    @MainActor init(model: AppModel? = nil) {
        _model = State(initialValue: model ?? AppModel())
    }

    var body: some View {
        StageBackdrop(backdrop: model.backdrop, homeScreen: model.homeScreen)
            .ignoresSafeArea()
            .overlay {
                GeometryReader { space in
                    if space.size.width >= Theme.Size.sideBySide {
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
                .padding(Theme.Space.medium)
            }
            .environment(model)
    }

    private var settings: some View {
        SettingsList()
    }
}

// Sized like the real screens, whichever device Xcode has picked: the M1 iPad Pro 12.9-inch
// both ways round, and an iPhone.
#Preview("iPad 12.9 landscape", traits: .fixedLayout(width: 1366, height: 1024)) {
    RebuildRoot(model: AppModel(sample: ClockStyle()))
}

#Preview("iPad 12.9 portrait", traits: .fixedLayout(width: 1024, height: 1366)) {
    RebuildRoot(model: AppModel(sample: ClockStyle(), homeScreen: .dark, backdrop: .midnight))
}

#Preview("iPhone", traits: .fixedLayout(width: 393, height: 852)) {
    RebuildRoot(model: AppModel(sample: ClockStyle(), size: .small))
}
