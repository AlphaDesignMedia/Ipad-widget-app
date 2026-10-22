import SwiftUI

/// The rebuilt app (PLAN.md, "The rebuild"). Step 1: the backdrop, the widget at real size and
/// Apply, running on the shared model. Debug builds open it with `-rebuild YES`
/// (`Scripts/run-on-ipad.sh --rebuild`); until step 8 the old app stays the default.
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
                WidgetCard(style: model.style, size: model.previewSize, homeScreen: model.homeScreen)
            }
            .overlay(alignment: .topTrailing) {
                Button(model.isApplied ? "Applied" : "Apply to Widget", action: model.apply)
                    .buttonStyle(.glassProminent)
                    .disabled(model.isApplied)
                    .padding(Theme.Space.medium)
            }
            .environment(model)
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
