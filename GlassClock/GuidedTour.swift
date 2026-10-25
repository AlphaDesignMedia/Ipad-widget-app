import SwiftUI

/// A quick guide laid over the real app on first launch (owner idea, 2026-10-21): the screen
/// dims, a soft spotlight moves to each part, and a short note says what you can do with it.
/// Skip it at any point, or pick "Keep it simple" to go straight to Classic. It can be shown
/// again from the App and Widget settings.
enum GuideStep: Int, CaseIterable {
    case welcome, colour, widget, settings, groups, backdrop, toolbar

    var symbol: String {
        switch self {
        case .welcome: "sparkles"
        case .colour: "paintpalette"
        case .widget: "hand.draw"
        case .settings: "hand.tap"
        case .groups: "rectangle.portrait.and.arrow.right"
        case .backdrop: "arrow.up.and.down"
        case .toolbar: "arrow.up.left.and.arrow.down.right"
        }
    }

    var title: String {
        switch self {
        case .welcome: "Welcome to Glass Clock"
        case .colour: "What's your favourite colour?"
        case .widget: "Your widget, by hand"
        case .settings: "Every setting, in one list"
        case .groups: "Jump around, or tuck it away"
        case .backdrop: "Try it on different backdrops"
        case .toolbar: "Make the space your own"
        }
    }

    var text: String {
        switch self {
        case .welcome:
            "A quick look at what you can do. It takes half a minute, and you can skip it any time."
        case .colour:
            "The app's buttons and highlights take it on. You can change it any time in App settings."
        case .widget:
            "Drag it anywhere. Pinch to change its size. Hold it until it wiggles to resize from a corner, like on your Home Screen."
        case .settings:
            "Scroll through the cards; the one you're on comes forward. Hold the panel for a moment, then drag it to the other side."
        case .groups:
            "Tap a group to glide straight to it. Drag this panel anywhere, or flick it away and it folds into a small button."
        case .backdrop:
            "Swipe up or down on an empty space to pull in the next backdrop. Let go early to stay where you are."
        case .toolbar:
            "Up here: Full Screen hides the panels, Arrange moves them, and Apply to Widget sends your design to the Home Screen."
        }
    }

    /// A little more, behind Learn More, for anyone who wants it (owner, 25 Oct 2026).
    var more: String? {
        switch self {
        case .welcome, .colour: nil
        case .widget:
            "It snaps to the Home Screen grid as you let go. Flick it and it glides to the next slot. Light, Dark, Clear and Tinted above it show how it'll look on each kind of Home Screen."
        case .settings:
            "Each card is one group of settings. Changes show on the widget straight away; nothing reaches your Home Screen until you Apply."
        case .groups:
            "Groups you open most stay near the top. Folded away, the panel becomes a small rail you can tap to bring it back."
        case .backdrop:
            "Use a photo of your own Home Screen to see the widget where it'll really live. Backdrops are only for trying things out; they don't change your wallpaper."
        case .toolbar:
            "Accessibility settings are in the App card: bigger text, outlines round the glass, and less motion."
        }
    }

    /// Asked only the first time: the welcome and the colour question aren't worth repeating.
    var firstTimeOnly: Bool { self == .welcome || self == .colour }
}

struct GuidedTour: View {
    /// Where each part is on screen, in the window's space.
    var targets: [GuideStep: CGRect]
    var finish: () -> Void
    var keepSimple: () -> Void
    /// The first time it's the full tour; shown again, it skips straight to the parts.
    var firstTime = true
    @State private var step = GuideStep.welcome
    @State private var showsMore = false
    /// The card can be dragged out of the way (owner, 25 Oct 2026).
    @State private var cardOffset = CGSize.zero
    @GestureState private var cardDrag = CGSize.zero
    @AppStorage("appColor") private var appColor = ClockColor.auto.rawValue
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }

    var body: some View {
        GeometryReader { geometry in
            let area = geometry.size
            let hole = targets[step].map { $0.insetBy(dx: -12, dy: -12) }
            ZStack(alignment: .topLeading) {
                let shape = SpotlightShape(hole: hole ?? CGRect(x: area.width / 2, y: area.height / 2, width: 0, height: 0))
                // The lit part stays live, so you can try each movement as it's shown (owner,
                // 25 Oct 2026); a tap on the dimmed part moves on.
                shape
                    .fill(.black.opacity(0.42), style: FillStyle(eoFill: true))
                    .contentShape(shape, eoFill: true)
                    .onTapGesture(perform: next)
                if let hole {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.7), lineWidth: 2)
                        .frame(width: hole.width, height: hole.height)
                        .position(x: hole.midX, y: hole.midY)
                        .allowsHitTesting(false)
                }
                card
                    .frame(width: 360)
                    .position(cardPosition(beside: hole, in: area))
                    .offset(x: cardOffset.width + cardDrag.width, y: cardOffset.height + cardDrag.height)
                    .gesture(
                        DragGesture()
                            .updating($cardDrag) { value, drag, _ in drag = value.translation }
                            .onEnded { value in
                                cardOffset.width += value.translation.width
                                cardOffset.height += value.translation.height
                            }
                    )
            }
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: step)
        }
        .onAppear { if !firstTime { step = steps.first ?? .widget } }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: step.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: step)
            Text(step.title)
                .font(.title3.weight(.bold))
            Text(step.text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if step == .colour { colourSwatches }
            if let more = step.more {
                if showsMore {
                    Text(more)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                Button(showsMore ? "Show Less" : "Learn More") {
                    withAnimation(.snappy) { showsMore.toggle() }
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.borderless)
            }
            if !step.firstTimeOnly {
                Label("Go ahead and try it: the lit part works.", systemImage: "hand.point.up.left")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.tint)
            }
            HStack(spacing: 6) {
                ForEach(steps, id: \.self) { dot in
                    Capsule()
                        .fill(dot == step ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.4)))
                        .frame(width: dot == step ? 18 : 6, height: 6)
                }
            }
            .padding(.top, 4)
            if step == .welcome {
                Button(action: next) {
                    Text("Show Me").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .prominentButton()
                .buttonBorderShape(.capsule)
                HStack {
                    Button("I'll explore myself", action: finish)
                    Spacer()
                    Button("Keep it simple", action: keepSimple)
                }
                .font(.subheadline.weight(.medium))
            } else {
                HStack {
                    Button("Skip", action: finish)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button(action: next) {
                        Text(step == steps.last ? "Done" : "Next")
                            .font(.headline)
                            .padding(.horizontal, 10)
                    }
                    .prominentButton()
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(22)
        .background(.regularMaterial, in: .rect(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
    }

    private var steps: [GuideStep] {
        firstTime ? GuideStep.allCases : GuideStep.allCases.filter { !$0.firstTimeOnly }
    }

    private func next() {
        showsMore = false
        if let index = steps.firstIndex(of: step), index + 1 < steps.count {
            step = steps[index + 1]
        } else {
            finish()
        }
    }

    /// The colours to choose from; picking one sets the app colour straight away.
    private var colourSwatches: some View {
        let choices: [ClockColor] = [.red, .orange, .yellow, .green, .mint, .blue, .purple, .auto]
        return HStack(spacing: 8) {
            ForEach(choices) { choice in
                let picked = appColor == choice.rawValue
                Button {
                    withAnimation(.snappy) { appColor = choice.rawValue }
                } label: {
                    Circle()
                        .fill(AppColor.chosen(choice.rawValue))
                        .frame(width: 32, height: 32)
                        .overlay { Circle().strokeBorder(.white, lineWidth: picked ? 3 : 0) }
                        .overlay { Circle().strokeBorder(.primary.opacity(picked ? 0.6 : 0), lineWidth: 1).padding(-2) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice == .auto ? "Blue, the app's own" : choice.rawValue.capitalized)
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
    }

    /// Beside the spotlight, on whichever side has room; in the middle when there's nothing
    /// to point at.
    private func cardPosition(beside hole: CGRect?, in area: CGSize) -> CGPoint {
        let half = CGSize(width: 180, height: 150)
        guard let hole else { return CGPoint(x: area.width / 2, y: area.height / 2) }
        let clampY = { (y: CGFloat) in min(area.height - half.height - 24, max(half.height + 24, y)) }
        let clampX = { (x: CGFloat) in min(area.width - half.width - 24, max(half.width + 24, x)) }
        if hole.maxX + 24 + half.width * 2 < area.width {
            return CGPoint(x: hole.maxX + 24 + half.width, y: clampY(hole.midY))
        }
        if hole.minX - 24 - half.width * 2 > 0 {
            return CGPoint(x: hole.minX - 24 - half.width, y: clampY(hole.midY))
        }
        if hole.maxY + 24 + half.height * 2 < area.height {
            return CGPoint(x: clampX(hole.midX), y: hole.maxY + 24 + half.height)
        }
        return CGPoint(x: clampX(hole.midX), y: clampY(hole.minY - 24 - half.height))
    }
}

/// The dimmed screen with a rounded hole where the spotlight is. The hole glides between steps.
struct SpotlightShape: Shape {
    var hole: CGRect

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(hole.origin.x, hole.origin.y), AnimatablePair(hole.width, hole.height)) }
        set { hole = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: 30, height: 30), style: .continuous)
        return path
    }
}
