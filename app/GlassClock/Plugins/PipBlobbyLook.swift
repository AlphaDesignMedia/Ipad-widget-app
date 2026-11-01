import SwiftUI
import UIKit

// PIP LOOKS · Blobby (V2), Aaron 1 Nov 2026 ("maybe v2 is blobby pip"). Part of Pip Looks, in its own file so that
// one stays short.
// Old-game style (Aaron, 1 Nov: "i liked the renders we made a lot more" · "think old games" · "he cant be a flat
// plane"): he's rendered once from the 3D page (app/design/pip-3d.html, Aaron's final settings) into a flipbook,
// blobby-sheet.png, by app/tools/pip-frames.js, and the app only flips pictures. The real glass look, nearly free to run.
// The sheet's rows: side (his best silhouette: round head, two leaf wings, the trailing tail, an eye; mirrored for
// left), front (looking at you; also how he turns round, like the old games' turnaround), frontBlank (looking at you
// with no face: a face emoji becomes his face). Each row is one wing beat, then a blink.
// Inside him, a real emoji (Apple's): it floats in the middle of his head with the glass's own shine over it; a face
// emoji is his face, and he looks at you (Aaron, 1 Nov: "when hes an emoji he should look at you").
// Made up by Jules (Aaron to judge): the turn through the front view, the resting flap speed, the glow, the sheen.
// To remake the sheet after a change on the 3D page: node app/tools/pip-frames.js

// MARK: Data

enum BlobbyPicks {
    /// The emoji the Looks card offers (Pip's Emotes favourites plus a heart). Any emoji works.
    static let emoji = ["⭐", "❤️", "💙", "✨", "😊", "😂", "💤"]

    /// A face emoji becomes his face; anything else floats in the middle of his head.
    static func isFace(_ e: String) -> Bool {
        guard let v = e.unicodeScalars.first?.value else { return false }
        return v == 0x263A || (0x1F600...0x1F644).contains(v) || (0x1F910...0x1F92F).contains(v)
            || (0x1F970...0x1F97A).contains(v) || v == 0x1F9D0 || (0x1FAE0...0x1FAE8).contains(v)
    }
}

/// The flipbook: blobby-sheet.png, cut into frames once. Numbers from app/tools/pip-frames.js (its blobby-sheet.json).
enum BlobbySheet {
    enum Row: Int { case side = 0, front = 1, frontBlank = 2 }
    static let frameW: CGFloat = 162, frameH: CGFloat = 173     // one frame, in sheet pixels
    static let flaps = 12                                       // frames per wing beat; then the blink
    static let beatSeconds = 0.6981                             // the 3D page's flying beat
    static let headX: CGFloat = 106.5, headY: CGFloat = 125.5   // his head's centre in a frame (measured from the sheet)
    static let headR: CGFloat = 40                              // his head's radius in the sheet

    @MainActor private static var frames: [[CGImage]]? = nil

    @MainActor static func frame(_ row: Row, _ i: Int) -> CGImage? {
        if frames == nil {
            guard let sheet = UIImage(named: "blobby-sheet")?.cgImage else { frames = []; return nil }
            frames = (0..<3).map { r in
                (0...flaps).compactMap { c in
                    sheet.cropping(to: CGRect(x: CGFloat(c) * frameW, y: CGFloat(r) * frameH, width: frameW, height: frameH))
                }
            }
        }
        guard let rows = frames, row.rawValue < rows.count, i < rows[row.rawValue].count else { return nil }
        return rows[row.rawValue][i]
    }
}

// MARK: Logic

/// Which way he faces (1 right, -1 left), easing through 0 as he turns round (through the front view): the way he's
/// moving when he moves (Aaron, 1 Nov: "he needs to turn with the motion"), otherwise where he's looking.
final class BlobbyTurn {
    static let live = BlobbyTurn()          // the one the core's Pip uses
    private var facing: Double = 1
    private var last: Double = 0
    private var lastPos: CGPoint? = nil
    private var speedX: Double = 0          // sideways speed, pt/s, smoothed

    func step(look: CGSize, pos: CGPoint? = nil, at t: Double, snap: Bool) -> Double {
        let dt: Double = last == 0 ? 0 : min(0.1, max(0, t - last))
        if let p = pos {
            if let q = lastPos, dt > 0 { speedX += ((p.x - q.x) / dt - speedX) * min(1, dt * 8) }
            lastPos = p
        }
        let moving: Double = abs(speedX) > 40 ? (speedX > 0 ? 1 : -1) : 0
        let target: Double = moving != 0 ? moving
            : look.width < -0.15 ? -1 : (look.width > 0.15 ? 1 : (facing >= 0 ? 1 : -1))
        last = t
        if snap { facing = target } else { facing += (target - facing) * min(1, dt * 5) }
        return facing
    }
}

/// Pip's latest emote (from the `pip.emote` channel: Pip's Emotes or any plugin), shown inside Blobby for a moment.
@MainActor enum BlobbyEmote {
    static var last: (emoji: String, at: Double)? = nil
    private static var token: NSObjectProtocol? = nil

    static func listen() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = NotificationCenter.default.addObserver(forName: PipEmotes.channel, object: nil, queue: .main) { note in
            guard let e = note.object as? String, !e.isEmpty else { return }
            let now = Date().timeIntervalSinceReferenceDate
            MainActor.assumeIsolated { last = (e, now) }
        }
    }
}

// MARK: Views

/// Pip in the Blobby look, centred on his head in a frame 8 × the head radius (room for the tail, wings and glow).
/// Pure: same inputs, same picture.
struct PipBlobbyBody: View {
    var radius: CGFloat = 12
    var time: Double = 0
    var face: PipFace = .awake
    var look: CGSize = .zero
    var facing: Double = 1
    var emoji: String? = nil
    /// When the emoji popped in (same clock as `time`). nil: it stays. Otherwise it's a moment: it pops in, he looks
    /// at you, and after a couple of seconds it melts back into his own face (Aaron, 1 Nov).
    var emojiAt: Double? = nil
    var simpler: Bool = false
    var flapping: Bool = false
    var halo: Color = PipLook.glow

    var body: some View {
        let r = radius
        let box: CGFloat = r * 8
        let m = moment
        let shown: String? = m.vis > 0.01 ? emoji : nil
        let faceEmoji: Bool = shown.map(BlobbyPicks.isFace) ?? false
        // side view most of the time; the front view while turning round, and while a face emoji is on (he looks at
        // you): his own face underneath, the faceless frame over it, so as the emoji goes his face comes back through
        let row: BlobbySheet.Row = faceEmoji || abs(facing) < 0.55 ? .front : .side
        let closed: Bool = face == .blink || face == .asleep || face == .sleepy
        let (i, next, blend) = flapFrames
        let shut: Bool = closed && !faceEmoji
        let mirror: CGFloat = facing < 0 ? -1 : 1
        ZStack {
            // his glow, under everything
            Circle().fill(halo.opacity(0.4)).frame(width: r * 2.6, height: r * 2.6).blur(radius: r * 0.5)
            if let img = BlobbySheet.frame(row, shut ? BlobbySheet.flaps : i) {
                sprite(img)
                // smoothing: the next frame fades in over this one, so the flipbook flows instead of clunking
                if !shut, blend > 0.02, let nxt = BlobbySheet.frame(row, next) { sprite(nxt).opacity(blend) }
                if faceEmoji, let blank = BlobbySheet.frame(.frontBlank, i) { sprite(blank).opacity(m.vis) }
                if let e = shown {
                    emojiView(e, isFace: faceEmoji, vis: m.vis, pop: m.pop)
                    // the glass's own shine back over the emoji, so it sits inside him, not on top
                    sprite(img).blendMode(.screen).opacity(0.55)
                        .mask(Circle().frame(width: r * 2, height: r * 2))
                }
            }
        }
        .scaleEffect(x: mirror, y: 1)
        .frame(width: box, height: box)
        .accessibilityHidden(true)
    }

    /// One frame, sized so his head is `radius`, placed so his head is at the centre.
    private func sprite(_ img: CGImage) -> some View {
        let s: CGFloat = radius / BlobbySheet.headR
        return Image(decorative: img, scale: 1)
            .resizable()
            .interpolation(.medium)
            .frame(width: BlobbySheet.frameW * s, height: BlobbySheet.frameH * s)
            .offset(x: (BlobbySheet.frameW / 2 - BlobbySheet.headX) * s, y: (BlobbySheet.frameH / 2 - BlobbySheet.headY) * s)
    }

    /// The emoji moment: pops in (0.3 s, a little overshoot), stays 2.5 s, melts away (0.6 s). Reduce Motion: no pop.
    private var moment: (vis: Double, pop: Double) {
        guard let at = emojiAt else { return (1, 1) }
        let since = time - at
        if since < 0 { return (0, 1) }
        if since < 0.3 { let v = since / 0.3; return (v, simpler ? 1 : 0.6 + 0.4 * sin(v * Double.pi / 2) * 1.08) }
        if since < 2.8 { return (1, 1) }
        if since < 3.4 { return (1 - (since - 2.8) / 0.6, 1) }
        return (0, 1)
    }

    /// The wing beat: flying, the 3D page's quick beat; resting, a slow gentle one. Still with Reduce Motion.
    /// Gives this frame, the next one and how far we are between them (for the fade).
    private var flapFrames: (Int, Int, Double) {
        if simpler { return (0, 0, 0) }
        let period: Double = flapping ? BlobbySheet.beatSeconds : 1.6
        let n = BlobbySheet.flaps
        let at = (time / period).truncatingRemainder(dividingBy: 1) * Double(n)
        let i = min(n - 1, max(0, Int(at)))
        return (i, (i + 1) % n, at - Double(i))
    }

    /// Floats in the very middle of his head (Aaron, 1 Nov: "isn't perfectly central"), facing you, breathing softly;
    /// a face emoji is his face, also centred, as he looks at you. Drawn mirrored back, so it never reads backwards.
    private func emojiView(_ e: String, isFace: Bool, vis: Double, pop: Double) -> some View {
        let r = radius
        let t: Double = simpler ? 0 : time
        let drift: CGFloat = isFace ? 0.3 : 1
        let dx = CGFloat(sin(t * 0.7) * 0.05) * r * drift
        let dy = CGFloat(sin(t * 1.1 + 1) * 0.06) * r * drift
        let spot = CGPoint.zero                                  // dead centre of his head (Aaron, 1 Nov)
        // the breathing pulse, the pop in, and shrinking a little as it melts away
        let pulse = CGFloat((1 + 0.04 * (0.5 + 0.5 * sin(t * 2.2))) * pop * (0.7 + 0.3 * vis))
        return Text(e)
            .font(.system(size: r * (isFace ? 1.15 : 0.95)))
            .scaleEffect(x: (facing < 0 ? -1 : 1) * pulse, y: pulse)
            .rotationEffect(.radians(simpler ? 0 : sin(t * 0.8) * 0.06))
            .opacity((isFace ? 1 : 0.92) * vis)
            .offset(x: spot.x + dx, y: spot.y + dy)
    }
}
