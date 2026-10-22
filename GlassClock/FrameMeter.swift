import SwiftUI
import QuartzCore
import os

/// Debug builds only: a small readout of how smoothly the screen is drawing, so a glitch seen
/// on the iPad shows up as a number that can be compared with the Simulator, before and after a
/// fix. Turn it on by launching with `-frameMeter YES` (`Scripts/run-on-ipad.sh --meter`).
/// Tap it to start counting again.
@Observable final class FrameWatch: NSObject {
    /// Frames drawn in the last second.
    private(set) var fps = 0
    /// Frames that came late since the last reset (more than half a frame behind).
    private(set) var hitches = 0
    /// The longest gap between frames since the last reset, in milliseconds.
    private(set) var worstMs = 0

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var last: CFTimeInterval = 0
    @ObservationIgnored private var secondStart: CFTimeInterval = 0
    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var pendingHitches = 0
    @ObservationIgnored private var pendingWorst = 0
    @ObservationIgnored private let log = Logger(subsystem: "com.aarondennel.glassclock", category: "hitch")

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func reset() {
        pendingHitches = 0; pendingWorst = 0
        hitches = 0; worstMs = 0
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let frame = max(link.targetTimestamp - link.timestamp, 1.0 / 120)
        if last > 0 {
            let gap = now - last
            if gap > frame * 1.5 {
                let ms = Int(gap * 1000)
                pendingHitches += 1
                pendingWorst = max(pendingWorst, ms)
                log.warning("Hitch: \(ms) ms")
            }
        } else {
            secondStart = now
        }
        last = now
        frames += 1
        // Published once a second, so the meter itself costs next to nothing.
        if now - secondStart >= 1 {
            fps = frames
            hitches += pendingHitches
            worstMs = max(worstMs, pendingWorst)
            frames = 0; pendingHitches = 0; pendingWorst = 0
            secondStart = now
        }
    }
}

struct FrameMeter: View {
    @State private var watch = FrameWatch()

    var body: some View {
        Text("\(watch.fps) fps · \(watch.hitches) hitches · worst \(watch.worstMs) ms")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background((watch.hitches > 0 ? Color.red : Color.black).opacity(0.6), in: .capsule)
            .onTapGesture { watch.reset() }
            .onAppear { watch.start() }
            .accessibilityHidden(true)
    }
}
