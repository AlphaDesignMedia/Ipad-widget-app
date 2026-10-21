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
    /// How deep the bent rim of the sheet is.
    private let rimDepth: CGFloat = 110

    /// The bend fades in as the sheet starts moving and out as it finishes, so it's never
    /// there while the backdrop is still.
    private var bend: CGFloat {
        max(0, min(1, progress * 8, (1 - progress) * 8))
    }

    private var moving: Bool { progress > 0.001 && progress < 0.999 }

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                // The sheet's rim bends the picture on it, like the rounded edge of thick glass:
                // a squeezed copy, drawn from a little further in, fades in towards the edge.
                // The glass lip below then bends whatever the edge passes over.
                .overlay {
                    if moving {
                        content
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(x: 1 + 0.02 * bend, y: 1 - 0.22 * bend, anchor: upward ? .bottom : .top)
                            .brightness(0.06 * bend)
                            .mask {
                                LinearGradient(colors: [.black, .black.opacity(0)],
                                               startPoint: upward ? .bottom : .top,
                                               endPoint: upward ? .top : .bottom)
                                    .frame(height: rimDepth)
                                    .frame(maxHeight: .infinity, alignment: upward ? .bottom : .top)
                            }
                            .allowsHitTesting(false)
                    }
                }
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
