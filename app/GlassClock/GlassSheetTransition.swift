import SwiftUI

/// Changing the backdrop feels like pushing a carousel (owner feedback, 2026-10-21): the
/// current backdrop slides away with the finger and shrinks back a touch, while the next one
/// slides in from the edge, growing to full size. No glass edge or white rim, just the two
/// pictures moving together. Reduce Motion uses a plain fade instead (set by the caller).
struct GlassSheetTransition: Transition {
    /// The old backdrop leaves upwards (true) or downwards.
    var upward: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(CarouselSlide(
            progress: phase == .identity ? 0 : 1,
            // Leaving goes the way of the swipe; arriving comes in from the other side.
            edge: phase == .didDisappear ? (upward ? -1 : 1) : (upward ? 1 : -1)
        ))
    }
}

/// One backdrop in the carousel, `progress` of the way off screen (0 is in place) towards
/// `edge` (-1 up, 1 down), shrinking slightly and rounding its corners as it goes.
struct CarouselSlide: ViewModifier, Animatable {
    var progress: Double
    var edge: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let p = min(1, max(0, progress))
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipShape(.rect(cornerRadius: 36 * min(1, p * 4), style: .continuous))
                .scaleEffect(1 - 0.05 * p)
                .offset(y: edge * p * geometry.size.height)
        }
    }
}

/// The backdrop being swiped away, following the finger (`progress` 0…1 of the way).
struct GlassSheetEffect: ViewModifier, Animatable {
    var progress: Double
    var upward: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.modifier(CarouselSlide(progress: progress, edge: upward ? -1 : 1))
    }
}
