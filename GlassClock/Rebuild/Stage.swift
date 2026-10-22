import SwiftUI

/// The widget on a Home Screen-style grid of slots (PLAN.md, rebuild step 2): drag it to
/// another slot and it snaps there, pinch it to step through the widget sizes. It's drawn at
/// its real size, and scaled down only when the window is too small to hold it.
struct Stage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { space in
            let size = model.previewSize
            // Floored, as in the old app: a window laid out at zero size for a moment gave a
            // zero scale, and the grid maths went infinite (2026-10-21).
            let fit = min(1, space.size.width / size.size.width, space.size.height / size.size.height)
            let scale = fit.isFinite ? max(fit, 0.05) : 1
            let grid = HomeGrid(area: space.size, scale: scale)
            let slot = grid.clamped(column: model.widgetColumn, row: model.widgetRow, span: size.span)
            let home = grid.frame(column: slot.column, row: slot.row, span: size.span)
            MovableWidget(grid: grid, home: home, scale: scale)
                .frame(width: space.size.width, height: space.size.height)
        }
    }
}

/// The widget and everything that moves with a finger on it. The drag and pinch live here
/// rather than on the model, so while a finger moves only this view redraws, not the screen
/// (the old app's drags were slow because every frame redrew all of `ContentView`).
private struct MovableWidget: View {
    let grid: HomeGrid
    /// Where the widget rests, in the stage's space.
    let home: CGRect
    let scale: CGFloat

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("simpleMotion") private var simpleMotion = false
    private var reduceMotion: Bool { systemReduceMotion || simpleMotion }

    /// How far the finger has carried it. Resets to zero by itself when the finger lifts.
    @GestureState private var carry = CGSize.zero
    /// The slot it would land in if let go now, while it's carried.
    @State private var landing: (column: Int, row: Int)?
    /// The size it had when the pinch began.
    @State private var pinchStart: PreviewSize?

    private var span: (columns: Int, rows: Int) { model.previewSize.span }

    var body: some View {
        let lifted = carry != .zero || landing != nil
        ZStack(alignment: .topLeading) {
            if let landing { slots(landing: landing) }
            WidgetCard(style: model.style, size: model.previewSize, homeScreen: model.homeScreen)
                .scaleEffect(scale)
                .frame(width: home.width, height: home.height)
                // Picked up: it lifts a little towards the finger, with a deeper shadow.
                .scaleEffect(lifted && !reduceMotion ? 1.04 : 1)
                .shadow(color: .black.opacity(lifted ? 0.28 : 0), radius: lifted ? 24 : 0, y: lifted ? 14 : 0)
                .animation(reduceMotion ? nil : Theme.Motion.lift, value: lifted)
                .contentShape(.rect)
                .gesture(moveAndResize)
                .sensoryFeedback(.impact(weight: .light), trigger: lifted) { _, now in now }
                .sensoryFeedback(.selection, trigger: landing?.column ?? -1)
                .sensoryFeedback(.selection, trigger: landing?.row ?? -1)
                .sensoryFeedback(.selection, trigger: model.previewSize)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(model.previewSize.rawValue) widget preview")
                .accessibilityHint("Drag to move it on the Home Screen grid. Pinch to change the widget size.")
                .accessibilityAction(named: "Move left") { move(-1, 0) }
                .accessibilityAction(named: "Move right") { move(1, 0) }
                .accessibilityAction(named: "Move up") { move(0, -1) }
                .accessibilityAction(named: "Move down") { move(0, 1) }
                .accessibilityAction(named: "Bigger") { resize(by: 1) }
                .accessibilityAction(named: "Smaller") { resize(by: -1) }
                .position(x: home.midX, y: home.midY)
                .offset(carry)
        }
    }

    /// The empty slots, and a dashed outline where the widget will land.
    private func slots(landing: (column: Int, row: Int)) -> some View {
        let target = grid.frame(column: landing.column, row: landing.row, span: span)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(grid.slotFrames.enumerated()), id: \.offset) { _, frame in
                RoundedRectangle(cornerRadius: 22 * scale)
                    .fill(.white.opacity(0.08))
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
            RoundedRectangle(cornerRadius: Theme.Corner.widget * scale)
                .fill(.white.opacity(0.18))
                .strokeBorder(.white.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: target.width, height: target.height)
                .position(x: target.midX, y: target.midY)
                .animation(reduceMotion ? nil : .snappy, value: target)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// One gesture for both: one finger drags it, two fingers pinch it (and move it as well).
    /// Kept as one because a pinch moves too, and a separate drag would steal it. The drag is
    /// measured against the window, since the widget moves with the finger.
    private var moveAndResize: some Gesture {
        MagnifyGesture()
            .simultaneously(with: DragGesture(minimumDistance: 8, coordinateSpace: .global))
            .updating($carry) { value, carry, _ in
                if let drag = value.second { carry = drag.translation }
            }
            .onChanged { value in
                if let pinch = value.first {
                    let start = pinchStart ?? model.previewSize
                    if pinchStart == nil { pinchStart = start }
                    let next = Self.size(for: pinch.magnification, from: start)
                    if next != model.previewSize {
                        withAnimation(reduceMotion ? nil : Theme.Motion.settle) { model.previewSize = next }
                    }
                }
                if let drag = value.second {
                    let next = grid.nearest(to: centre(after: drag.translation), span: span)
                    if landing == nil || landing! != next {
                        withAnimation(.snappy) { landing = next }
                    }
                }
            }
            .onEnded { value in
                pinchStart = nil
                // The finger's distance springs back to zero with the same spring that moves the
                // widget to its new slot, so it glides on from under the finger.
                withAnimation(reduceMotion ? nil : Theme.Motion.settle) {
                    if let drag = value.second {
                        let target = grid.nearest(to: centre(after: drag.translation), span: span)
                        model.widgetColumn = target.column
                        model.widgetRow = target.row
                    }
                    landing = nil
                }
            }
    }

    private func centre(after translation: CGSize) -> CGPoint {
        CGPoint(x: home.midX + translation.width, y: home.midY + translation.height)
    }

    /// The widget size nearest in area to how far the fingers have spread from `start`.
    private static func size(for magnification: CGFloat, from start: PreviewSize) -> PreviewSize {
        let area = start.size.width * start.size.height * magnification * magnification
        return PreviewSize.allCases.min { a, b in
            abs(log(a.size.width * a.size.height / area)) < abs(log(b.size.width * b.size.height / area))
        } ?? start
    }

    /// VoiceOver's Move actions: one slot at a time, staying on the grid.
    private func move(_ dx: Int, _ dy: Int) {
        let slot = grid.nearest(to: CGPoint(x: home.midX, y: home.midY), span: span)
        // Floored at 0: -1 would mean "never placed" and send it to the middle.
        let next = grid.clamped(column: max(0, slot.column + dx), row: max(0, slot.row + dy), span: span)
        withAnimation(reduceMotion ? nil : Theme.Motion.settle) {
            model.widgetColumn = next.column
            model.widgetRow = next.row
        }
    }

    private func resize(by step: Int) {
        let sizes = PreviewSize.allCases
        guard let index = sizes.firstIndex(of: model.previewSize) else { return }
        let next = sizes[min(sizes.count - 1, max(0, index + step))]
        withAnimation(reduceMotion ? nil : Theme.Motion.settle) { model.previewSize = next }
    }
}
