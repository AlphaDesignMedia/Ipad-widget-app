import SwiftUI

// Pip's look: the glowing orb and eyes from the web sandbox (styles.css), with the app icon's
// two pairs of wings (Aaron, 30 Oct 2026: the icon is the starting point for Pip).
// Plain SwiftUI with no app state, so it also draws the app icon (app/tools/make-icon.sh)
// and can move to Glass Clock as it is.

// MARK: Data

enum PipLook {
    static let size: CGFloat = 24        // --nd: Pip's radius is 12 (pip.js)
    static let touch: CGFloat = 48       // the web's touch area: 12px around the orb
    static let accent = Color(red: 79 / 255, green: 123 / 255, blue: 232 / 255)    // --accent #4f7be8
    static let eye = Color(red: 29 / 255, green: 24 / 255, blue: 48 / 255)          // --eye #1d1830
    static let orbLight = Color(red: 188 / 255, green: 205 / 255, blue: 246 / 255)  // accent 38% in white
    static let orbDeep = Color(red: 65 / 255, green: 101 / 255, blue: 190 / 255)    // accent 82% in black
    static let glow = Color(red: 167 / 255, green: 189 / 255, blue: 244 / 255)      // accent 50% in white
    static let flapSeconds = 0.22        // flapL / flapR, one way
    // Wings as fractions of the orb's size: (width, height, base x, base y, angle in degrees), from the icon.
    static let upperWing = (w: 0.405, h: 0.89, x: 0.284, y: -0.203, angle: 36.0)
    static let lowerWing = (w: 0.303, h: 0.608, x: 0.324, y: 0.122, angle: 118.0)
}

/// Pip's face. The sandbox has more moods (meh, annoyed, sulk); these are the ones the app uses so far.
enum PipFace: Equatable { case awake, asleep, blink, held, happy, dizzy, surprised, curious, shy, sleepy }

// MARK: View

/// Pip at any size. `flap` runs 0...1 (wings open to folded), `spin` turns the dizzy eyes,
/// `glow` adds to the halo just after Pip wakes; `halo` is its colour; `look` turns the eyes. `rim` thins the outline for large drawings such as the icon.
struct PipBody: View {
    var face: PipFace = .awake
    var flap: Double = 0
    var spin: Double = 0
    var glow: Double = 0
    var halo: Color = PipLook.glow
    var look: CGSize = .zero        // where the eyes point, -1...1 each way
    var size: CGFloat = PipLook.size
    var rim: CGFloat = 1

    var body: some View {
        let s = size, k = size / PipLook.size * rim
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [halo, halo.opacity(0)], center: .center,
                                     startRadius: 0, endRadius: s * 1.16))
                .frame(width: s * 2.4, height: s * 2.4)
                .scaleEffect(1 + glow * 0.45)
                .opacity((face == .asleep ? 0.25 : 0.6) + glow * 0.4)
            ForEach([-1.0, 1.0], id: \.self) { side in
                wing(PipLook.upperWing, side: side, s: s, k: k)
                wing(PipLook.lowerWing, side: side, s: s, k: k)
            }
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: .white.opacity(0.96), location: 0),
                    .init(color: .white.opacity(0.96), location: 0.11),
                    .init(color: .white.opacity(0.55), location: 0.22),
                    .init(color: PipLook.orbLight, location: 0.58),
                    .init(color: PipLook.orbDeep, location: 1),
                ], center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: s * 0.98)
                .shadow(.inner(color: .black.opacity(0.16), radius: 2 * k, y: -2 * k)))
                .overlay(Circle().strokeBorder(.white.opacity(0.75), lineWidth: k))
                .frame(width: s, height: s)
                .shadow(color: .black.opacity(0.2), radius: 3.5 * k, y: 2 * k)
            if face == .shy {
                HStack(spacing: s * 0.42) { cheek(s); cheek(s) }.offset(y: s * 0.12)
            }
            HStack(spacing: s * 0.17) { eye(s: s, k: k, left: true); eye(s: s, k: k, left: false) }
                .offset(x: look.width * s * 0.09, y: -s * 0.03 + look.height * s * 0.07)
                .animation(.easeOut(duration: 0.14), value: face)
        }
        .frame(width: s * 2, height: s * 2)
        .saturation(face == .asleep ? 0.7 : 1)
        .brightness(face == .asleep ? -0.08 : 0)
    }

    /// A wing standing on its base beside the orb, turned outwards; flapping narrows it and lifts it a little.
    private func wing(_ w: (w: Double, h: Double, x: Double, y: Double, angle: Double), side: Double,
                      s: CGFloat, k: CGFloat) -> some View {
        Ellipse()
            .fill(LinearGradient(colors: [.white.opacity(0.75), PipLook.accent.opacity(0.35)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(Ellipse().strokeBorder(.white.opacity(0.6), lineWidth: k))
            .frame(width: s * w.w, height: s * w.h)
            .scaleEffect(x: 1 - 0.45 * flap, y: 1, anchor: .bottom)
            .rotationEffect(.degrees(side * (w.angle - 10 * flap)), anchor: .bottom)
            .opacity(0.85)
            .offset(x: side * s * w.x, y: s * (w.y - w.h / 2))
    }

    private func cheek(_ s: CGFloat) -> some View {
        Ellipse().fill(Color.pink.opacity(0.45)).frame(width: s * 0.16, height: s * 0.09).blur(radius: s * 0.02)
    }

    // Reactions are eye swaps, old-game style: no new art, just a different pair of shapes.
    @ViewBuilder private func eye(s: CGFloat, k: CGFloat, left: Bool) -> some View {
        switch face {
        case .surprised:
            Circle().fill(PipLook.eye).frame(width: s * 0.16, height: s * 0.16)
                .overlay(Circle().fill(.white).frame(width: s * 0.05).offset(x: -s * 0.03, y: -s * 0.03))
        case .curious where !left:
            Capsule().fill(PipLook.eye).frame(width: s * 0.13, height: s * 0.08)
        case .curious:
            Capsule().fill(PipLook.eye).frame(width: s * 0.13, height: s * 0.24)
        case .sleepy:
            Capsule().fill(PipLook.eye).frame(width: s * 0.13, height: s * 0.07).offset(y: s * 0.04)
        case .shy:
            UnevenRoundedRectangle(topLeadingRadius: s * 0.06, bottomLeadingRadius: 0.5 * k,
                                   bottomTrailingRadius: 0.5 * k, topTrailingRadius: s * 0.06)
                .fill(PipLook.eye).frame(width: s * 0.12, height: s * 0.08)
        case .dizzy:
            Circle().trim(from: 0, to: 0.75)
                .stroke(PipLook.eye, lineWidth: 1.5 * k)
                .frame(width: s * 0.16, height: s * 0.16)
                .rotationEffect(.degrees(spin * 360))
        case .held:
            Ellipse().fill(PipLook.eye).frame(width: s * 0.15, height: s * 0.24)
        case .happy:
            UnevenRoundedRectangle(topLeadingRadius: s * 0.06, bottomLeadingRadius: 0.5 * k,
                                   bottomTrailingRadius: 0.5 * k, topTrailingRadius: s * 0.06)
                .fill(PipLook.eye).frame(width: s * 0.12, height: s * 0.1)
        case .asleep, .blink:
            Capsule().fill(PipLook.eye).frame(width: s * 0.12, height: 1.5 * k)
        case .awake:
            Capsule().fill(PipLook.eye).frame(width: s * 0.12, height: s * 0.21)
        }
    }
}

/// A four-pointed sparkle, for Pip's arrival and the icon.
struct PipSparkle: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), o = min(r.width, r.height) / 2, i = o * 0.28
        var p = Path()
        for n in 0..<8 {
            let a = Double(n) * .pi / 4 - .pi / 2, d = n.isMultiple(of: 2) ? o : i
            let pt = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
            n == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}
