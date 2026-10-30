import SwiftUI

/// Picking up a panel and carrying it (PLAN.md, rebuild step 5). Hold a panel's handle for a
/// moment and it lifts with a tap of feedback; then it follows the finger. Let go past the
/// middle of the window and it moves to that side; flick it towards its own edge and it goes
/// aside, behind a tab; anywhere else and it settles back.
///
/// The finger's distance lives here, read only by `CarryEffect`, so while a panel is carried
/// just that one modifier redraws, not the panel's cards or the rest of the screen.
@Observable @MainActor
final class PanelLift {
    var offset = CGSize.zero
    var lifted = false

    /// Which side the panel is on and how wide the window is, set by the layout. Nothing is
    /// measured while it's carried: the old app measured panels on every frame of a drag, and
    /// each measurement redrew the whole screen.
    @ObservationIgnored var onLeading = true
    @ObservationIgnored var windowWidth: CGFloat = 0
    /// What to do once it's let go. Set by the layout that holds the panel.
    @ObservationIgnored var onDrop: (PanelDrop) -> Void = { _ in }

    func lift() {
        guard !lifted else { return }
        withAnimation(Theme.Motion.lift) { lifted = true }
    }

    func follow(_ translation: CGSize) {
        offset = translation
    }

    /// Lets go with the finger's distance and where it was heading.
    func drop(translation: CGSize, predicted: CGSize) {
        let outward = onLeading ? -predicted.width : predicted.width
        let result: PanelDrop
        let inwards = onLeading ? translation.width : -translation.width
        if outward > 240 && abs(predicted.width) > abs(predicted.height) {
            result = .aside
        } else if inwards > windowWidth * 0.35 {
            result = .otherSide
        } else {
            result = .stay
        }
        settle(result)
    }

    /// Ends a carry the system cut short (a scroll took over, or a call came in).
    func settleIfStranded() {
        if lifted { settle(.stay) }
    }

    /// Moves the panel without a finger: VoiceOver's actions, and the edge tab.
    func settle(_ result: PanelDrop) {
        // Going aside, it leaves from where the finger let go; the distance is cleared when it
        // comes back. Otherwise the distance springs back to zero along with the move, so the
        // panel glides on from under the finger.
        withAnimation(Theme.Motion.settle) {
            if result != .aside { offset = .zero }
            lifted = false
            onDrop(result)
        }
    }
}

enum PanelDrop {
    case stay, otherSide, aside
}

extension EnvironmentValues {
    /// The carry of the panel a view sits in, so a card's title can pick the panel up.
    @Entry var panelLift: PanelLift?
}

/// The lift, the shadow and the finger's distance, on the panel being carried.
struct CarryEffect: ViewModifier {
    let carry: PanelLift
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }

    func body(content: Content) -> some View {
        content
            .scaleEffect(carry.lifted && !reduceMotion ? 1.02 : 1)
            .shadow(color: .black.opacity(carry.lifted ? 0.25 : 0), radius: carry.lifted ? 28 : 0, y: carry.lifted ? 16 : 0)
            .offset(carry.offset)
            .zIndex(carry.lifted ? 1 : 0)
            .sensoryFeedback(.impact(weight: .medium), trigger: carry.lifted) { _, now in now }
    }
}

/// Makes a view a handle that picks up its panel: hold, then drag. A quick tap or a scroll
/// passes straight through, so the handle's own buttons and the list still work.
struct CarryHandle: ViewModifier {
    let carry: PanelLift?
    /// What VoiceOver calls the panel, as in "Move settings to the other side".
    var name = "panel"
    @GestureState private var holding = false

    func body(content: Content) -> some View {
        if let carry {
            content
                .contentShape(.rect)
                .gesture(hold(carry))
                .onChange(of: holding) { _, now in if !now { carry.settleIfStranded() } }
                .accessibilityAction(named: "Move \(name) to the other side") { carry.settle(.otherSide) }
                .accessibilityAction(named: "Put \(name) aside") { carry.settle(.aside) }
        } else {
            content
        }
    }

    private func hold(_ carry: PanelLift) -> some Gesture {
        LongPressGesture(minimumDuration: Theme.Motion.hold)
            .sequenced(before: DragGesture(coordinateSpace: .global))
            .updating($holding) { value, holding, _ in
                if case .second(true, _) = value { holding = true }
            }
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                // Lifts the moment the hold is long enough, before the finger moves.
                carry.lift()
                if let drag { carry.follow(drag.translation) }
            }
            .onEnded { value in
                guard case .second(true, let drag) = value else { return }
                carry.drop(translation: drag?.translation ?? .zero,
                           predicted: drag?.predictedEndTranslation ?? .zero)
            }
    }
}
