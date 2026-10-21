import SwiftUI

/// The backdrop change, done like unlocking the iPad (owner's screen recording, 2026-10-21):
/// the old backdrop lifts away like a sheet of glass, with a bright glass edge that bends the
/// pictures it passes over, while the new one settles in from slightly zoomed. Reduce Motion
/// uses a plain fade instead (set by the caller).
struct GlassSheetTransition: Transition {
    /// The old backdrop leaves upwards (true) or downwards.
    var upward: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            // The new backdrop settles from slightly zoomed, as the Home Screen does on unlock.
            .scaleEffect(phase == .willAppear ? 1.06 : 1)
            .modifier(GlassSheetEffect(progress: phase == .didDisappear ? 1 : 0, upward: upward))
    }
}

/// Slides a view away by `progress` of its height, with a strip of clear glass along its
/// trailing edge that refracts both the view and what's revealed behind it.
struct GlassSheetEffect: ViewModifier, Animatable {
    var progress: Double
    var upward: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private let edgeHeight: CGFloat = 64

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                .overlay(alignment: upward ? .bottom : .top) {
                    if progress > 0.001 && progress < 0.999 {
                        edge
                            // Straddles the sheet's edge, so it bends both sides.
                            .offset(y: upward ? edgeHeight / 2 : -edgeHeight / 2)
                    }
                }
                .offset(y: (upward ? -1 : 1) * progress * geometry.size.height)
        }
    }

    /// The glass lip: clear glass with a bright line where light catches the edge.
    private var edge: some View {
        ZStack(alignment: upward ? .top : .bottom) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.clear, in: Rectangle())
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.9), .white.opacity(0)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1.5)
                .padding(.top, upward ? edgeHeight / 2 - 0.75 : 0)
                .padding(.bottom, upward ? 0 : edgeHeight / 2 - 0.75)
                .shadow(color: .white.opacity(0.8), radius: 6)
        }
        .frame(height: edgeHeight)
        .allowsHitTesting(false)
    }
}
