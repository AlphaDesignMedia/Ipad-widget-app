import SwiftUI

/// The controls around the widget (PLAN.md, rebuild step 6): the Home Screen look, the
/// widget's size and the backdrop, in one glass card at the foot of the stage. A "Preview" tag
/// sits there when they're tucked away: tap it and the controls lift out of it. They tuck back
/// in after 5 seconds untouched, so the widget has the stage to itself, but never while
/// VoiceOver is on. Swiping across the backdrop changes it too (`BackdropSwipe`).
struct WidgetControls: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverOn
    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("simpleMotion") private var simpleMotion = false
    @AppStorage("reduceGlass") private var reducesGlass = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }

    /// Out on launch, so they're found, then tucked away after the first wait.
    @State private var shown = true
    @State private var tuck: Task<Void, Never>?
    @Namespace private var lift

    /// Your photo and Make your own need pickers of their own, so they wait for a later step.
    static let backdrops = PreviewBackdrop.allCases.filter { $0 != .photo && $0 != .custom }

    var body: some View {
        ZStack(alignment: .bottom) {
            if shown || voiceOverOn { controls } else { tag }
        }
        .animation(reduceMotion ? nil : Theme.Motion.settle, value: shown)
        .padding(.bottom, Theme.Space.medium)
        .padding(.horizontal, Theme.Space.medium)
        .onAppear { restartTuck() }
        .onDisappear { tuck?.cancel() }
        // Any change made with them counts as using them, so they stay out while in use.
        .onChange(of: model.homeScreen) { restartTuck() }
        .onChange(of: model.previewSize) { restartTuck() }
        .onChange(of: model.backdrop) { restartTuck() }
    }

    /// The tag the controls tuck into.
    private var tag: some View {
        Button { show() } label: {
            Label("Preview", systemImage: "slider.horizontal.3")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .padding(.horizontal, Theme.Padding.chip)
                .frame(minHeight: Theme.Size.tapTarget)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .matchedGeometryEffect(id: "controls", in: lift)
        .accessibilityLabel("Preview controls")
        .accessibilityHint("Shows the Home Screen look, widget size and backdrop")
        .transition(.opacity)
    }

    private var controls: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Corner.panel, style: .continuous)
        let glassy = !systemReducesTransparency && !reducesGlass
        return VStack(spacing: Theme.Space.small) {
            GlassPicker("Home Screen", selection: binding(\.homeScreen), options: HomeScreenStyle.allCases) { $0.rawValue }
            GlassPicker("Widget size", selection: binding(\.previewSize), options: PreviewSize.allCases, large: true) {
                sizeClass == .compact && $0 == .extraLarge ? "XL" : $0.rawValue
            }
            BackdropRow()
        }
        .padding(Theme.Padding.bubble)
        .frame(maxWidth: 480)
        .background {
            // The same wash as the settings cards, so the words read over any backdrop.
            if glassy {
                shape.fill(colorScheme == .dark ? Color.black : .white)
                    .opacity(colorScheme == .dark ? Theme.Glass.washDark : Theme.Glass.washLight)
            } else {
                shape.fill(.background.secondary)
            }
        }
        .modifier(ClearGlass(on: glassy, shape: shape))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .matchedGeometryEffect(id: "controls", in: lift)
        // Touching them at all keeps them out a while longer.
        .simultaneousGesture(TapGesture().onEnded { restartTuck() })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preview controls")
        .accessibilityAction(named: "Tuck away") { shown = false }
        .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .bottom)))
    }

    private func binding<Value>(_ path: ReferenceWritableKeyPath<AppModel, Value>) -> Binding<Value> {
        Binding(get: { model[keyPath: path] }, set: { model[keyPath: path] = $0 })
    }

    private func show() {
        shown = true
        restartTuck()
    }

    private func restartTuck() {
        tuck?.cancel()
        tuck = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { shown = false }
        }
    }
}

/// A row of round swatches, one per backdrop. Tap one to put it behind the widget.
private struct BackdropRow: View {
    @Environment(AppModel.self) private var model
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                ForEach(WidgetControls.backdrops) { backdrop in
                    let chosen = backdrop == model.backdrop
                    Button { model.backdrop = backdrop } label: {
                        StageBackdrop(backdrop: backdrop, homeScreen: model.homeScreen)
                            .frame(width: Theme.Size.swatch, height: Theme.Size.swatch)
                            .clipShape(.circle)
                            .overlay { Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 1) }
                            .padding(3)
                            .overlay { if chosen { Circle().strokeBorder(AppColor.chosen(appColor), lineWidth: 3) } }
                            .frame(width: Theme.Size.tapTarget, height: Theme.Size.tapTarget)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(backdrop.label)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
            .padding(.horizontal, Theme.Space.small / 2)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: model.backdrop)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Backdrop")
    }
}

/// Swipe sideways across the backdrop (not the widget) to step to the next or previous one.
/// Its name shows for a moment at the top, so you know where you are.
struct BackdropSwipe: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }
    @State private var named: String?
    @State private var fade: Task<Void, Never>?

    var body: some View {
        Color.clear
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                    let across = value.translation.width
                    // Mostly sideways and far enough, so a stray touch or a scroll doesn't count.
                    guard abs(across) > 60, abs(across) > abs(value.translation.height) * 1.5 else { return }
                    step(across < 0 ? 1 : -1)
                }
            )
            .overlay(alignment: .top) {
                if let named {
                    Text(named)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, Theme.Padding.chip)
                        .padding(.vertical, Theme.Space.small)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.top, Theme.Space.medium)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHidden(true)
    }

    private func step(_ by: Int) {
        let all = WidgetControls.backdrops
        let index = all.firstIndex(of: model.backdrop) ?? 0
        let next = all[(index + by + all.count) % all.count]
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
            model.backdrop = next
            named = next.label
        }
        fade?.cancel()
        fade = Task {
            try? await Task.sleep(for: .seconds(1.2))
            if !Task.isCancelled { withAnimation { named = nil } }
        }
    }
}
