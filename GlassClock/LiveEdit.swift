import SwiftUI

/// The style while a slider is being dragged. A drag's changes land here rather than in the
/// main screen's style, so on each tick only the widget preview and that slider redraw; the
/// rest of the screen (cards, toolbar, Apply, Moods) catches up once, when the finger lifts.
/// Measured on the iPad (1 Nov 2026): a fast slider drag had 257 of 370 frames late, because
/// every tick rebuilt the whole screen.
@Observable @MainActor
final class LiveEdit {
    /// The style mid-drag, or nil when no slider is held.
    var style: ClockStyle?
}

/// The clock on its card in the preview, showing a slider's change as it happens. Only this
/// view reads the live style, so a drag redraws the preview and nothing around it.
struct LiveClockCard: View {
    var live: LiveEdit
    var style: ClockStyle
    var date: Date
    var homeScreen: HomeScreenStyle
    var previewSize: PreviewSize
    var card: CGSize
    var scale: CGFloat
    /// Eases into a new style (a preset, a mood, Lucky). Off with Reduce Motion.
    var eases = true

    var body: some View {
        let dragging = live.style != nil
        let shown = live.style ?? style
        ZStack {
            ClockFace(date: date, style: shown, simulatedAccent: homeScreen.accent,
                      simulatesClear: !homeScreen.showsKeptColours)
                .id(previewSize)
                .transition(.opacity)
        }
            .padding(16 * scale)
            .frame(width: card.width * scale, height: card.height * scale)
            .modifier(ClockCard(style: shown, shape: .rect(cornerRadius: 28 * scale), homeScreen: homeScreen))
            .environment(\.colorScheme, homeScreen == .dark ? .dark : .light)
            // Switches style at once rather than blending: animating the glass tint and the
            // colour mask between styles was the costliest part of a tap on the Home Screen
            // picker (2026-10-21). Size changes still animate.
            .transaction(value: homeScreen) { $0.animation = nil }
            // Only the preview eases into a new style; the rest of the screen just switches,
            // which costs far less than animating every card and glass tint along with it.
            // A held slider follows the finger exactly, with no easing.
            .animation(eases && !dragging ? .smooth(duration: 0.3) : nil, value: shown)
    }
}

/// A slider for one of the style's numbers. While held it changes only the live style; when
/// let go it hands the finished style back. A change without a drag (a VoiceOver swipe, say)
/// goes straight to the style.
struct StyleSlider: View {
    var title: String
    var key: WritableKeyPath<ClockStyle, Double>
    var range: ClosedRange<Double>
    var low: String
    var high: String
    var style: ClockStyle
    var live: LiveEdit
    var commit: (ClockStyle) -> Void

    @State private var dragging = false

    var body: some View {
        // Reads the live style only while this slider is held, so the others don't redraw.
        let value = dragging ? (live.style ?? style)[keyPath: key] : style[keyPath: key]
        LabeledContent(title) {
            Slider(value: Binding(get: { value }, set: change), in: range) {
                Text(title)
            } minimumValueLabel: {
                Text(low).font(.caption)
            } maximumValueLabel: {
                Text(high).font(.caption)
            } onEditingChanged: { editing in
                if editing {
                    live.style = style
                    dragging = true
                } else {
                    dragging = false
                    if let finished = live.style {
                        live.style = nil
                        commit(finished)
                    }
                }
            }
        }
    }

    private func change(_ value: Double) {
        if dragging, live.style != nil {
            live.style?[keyPath: key] = value
        } else {
            var next = style
            next[keyPath: key] = value
            commit(next)
        }
    }
}
