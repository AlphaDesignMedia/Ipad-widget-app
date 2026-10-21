import SwiftUI

/// A quick guide laid over the real app on first launch (owner idea, 2026-10-21): the screen
/// dims, a soft spotlight moves to each part, and a short note says what you can do with it.
/// Skip it at any point, or pick "Keep it simple" to go straight to Classic. It can be shown
/// again from the App and Widget settings.
enum GuideStep: Int, CaseIterable {
    case welcome, widget, settings, groups, backdrop, toolbar

    var symbol: String {
        switch self {
        case .welcome: "sparkles"
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
}

struct GuidedTour: View {
    /// Where each part is on screen, in the window's space.
    var targets: [GuideStep: CGRect]
    var finish: () -> Void
    var keepSimple: () -> Void
    @State private var step = GuideStep.welcome
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }

    var body: some View {
        GeometryReader { geometry in
            let area = geometry.size
            let hole = targets[step].map { $0.insetBy(dx: -12, dy: -12) }
            ZStack(alignment: .topLeading) {
                SpotlightShape(hole: hole ?? CGRect(x: area.width / 2, y: area.height / 2, width: 0, height: 0))
                    .fill(.black.opacity(0.42), style: FillStyle(eoFill: true))
                    .contentShape(.rect)
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
            }
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85), value: step)
        }
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
            HStack(spacing: 6) {
                ForEach(GuideStep.allCases, id: \.self) { dot in
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
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                HStack {
                    Button("Skip", action: finish)
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
                        Text(step == GuideStep.allCases.last ? "Done" : "Next")
                            .font(.headline)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(22)
        .background(.regularMaterial, in: .rect(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 10)
    }

    private func next() {
        if let following = GuideStep(rawValue: step.rawValue + 1) {
            step = following
        } else {
            finish()
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
