import SwiftUI
import UIKit

/// Parts of the clock drawn with Core Graphics into images, for the Clear and Tinted Home Screens.
///
/// In those styles iPadOS recolours everything in a widget except images marked
/// `.widgetAccentedRenderingMode(.fullColor)`. So the parts someone chooses to keep in colour
/// (the card and the AM/PM and date line) are drawn here, matching `ClockFace` as closely as
/// Core Graphics allows. (SwiftUI's `ImageRenderer` was tried for this first and left the
/// widget blank on iPadOS 27.)
///
/// A widget's timeline holds up to an hour of entries, and iPadOS rejects the whole update if
/// its archive gets too big ("failed with too large timeline archive"; 18 MB was rejected) or
/// takes too long ("Watchdog provision violated"), and the clock then stops changing (observed
/// 2026-10-20). Keeping the time itself in colour, as an image per minute, couldn't be kept
/// under the limit, so it was removed. These images are small, cropped and cached.
enum ClockRaster {
    /// Finished images, shared by every entry the widget draws. A plain dictionary rather than
    /// `NSCache`, which drops images under the widget's tight memory limit. Cleared when it
    /// gets big, which only happens after the style changes many times.
    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]
    private static let lock = NSLock()

    private static func cached(_ key: String, make: () -> UIImage) -> UIImage {
        lock.lock()
        if let image = cache[key] { lock.unlock(); return image }
        lock.unlock()
        let image = make()
        lock.lock()
        if cache.count > 80 { cache.removeAll() }
        cache[key] = image
        lock.unlock()
        return image
    }

    private static func key(_ style: ClockStyle, scale: CGFloat, dark: Bool, _ rest: String) -> String {
        let styleData = (try? JSONEncoder().encode(style)) ?? Data()
        return "\(styleData.hashValue)|\(scale)|\(dark)|\(rest)"
    }

    /// How far a glow or shadow reaches beyond the outline.
    private static func reach(_ style: ClockStyle, unit u: CGFloat) -> CGFloat {
        switch style.effect {
        case .none: 4 * u
        case .glow: u * (8 + 40 * style.effectSize) * 2
        case .shadow: u * (1 + 14 * style.effectSize) * 2 + u * 24 * style.effectDistance
        }
    }

    /// The area the AM/PM and date line draws in, including its glow or shadow.
    static func detailArea(artwork: ClockArtwork, style: ClockStyle, in size: CGSize) -> CGRect {
        guard !artwork.detail.isEmpty else { return .zero }
        let margin = reach(style, unit: artwork.unit) + 2
        // The widget pads the clock by 16 pt, so light may spill that far.
        let limit = CGRect(origin: .zero, size: size).insetBy(dx: -16, dy: -16)
        return artwork.detail.boundingRect.insetBy(dx: -margin, dy: -margin).intersection(limit).integral
    }

    /// The AM/PM and date line covering `area` (from `detailArea`), within a clock of `size`.
    static func detailImage(artwork: ClockArtwork, style: ClockStyle, area: CGRect, size: CGSize,
                            scale: CGFloat, dark: Bool) -> UIImage {
        let path = artwork.detail.cgPath
        let shape = "detail|\(artwork.detail.description.hashValue)|\(Int(artwork.unit * 100))"
        return cached(key(style, scale: scale, dark: dark, shape)) { render(size: area.size, scale: scale) { ctx in
            ctx.translateBy(x: -area.minX, y: -area.minY)
            let painter = Painter(ctx: ctx, scale: scale, dark: dark, bounds: CGRect(origin: .zero, size: size), area: area)
            ctx.setAlpha(style.textOpacity * 0.85)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            painter.light(path, style: style, unit: artwork.unit)
            if style.textFill == .glass {
                let auto = dark ? Color.white : Color(white: 0.15)
                painter.fill(path, (style.color == .auto ? auto : style.color.color).opacity(0.9))
            } else {
                painter.text(path, style: style, unit: artwork.unit)
            }
            ctx.endTransparencyLayer()
        } }
    }

    /// The card, filling the whole widget. The system rounds the corners. A solid card is a
    /// tiny image stretched to fit; a glass card is drawn at low resolution, since only its
    /// thin rim has detail. Both keep the timeline archive small.
    static func card(style: ClockStyle, size: CGSize, dark: Bool) -> UIImage {
        let scale: CGFloat = style.background == .solid ? 8 / max(size.width, size.height) : 0.5
        return cached(key(style, scale: scale, dark: dark, "card|\(size)")) { render(size: size, scale: scale) { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let painter = Painter(ctx: ctx, scale: scale, dark: dark, bounds: rect, area: rect)
            switch style.background {
            case .solid:
                painter.fill(CGPath(rect: rect, transform: nil), style.solidFill.opacity(style.cardOpacity))
            case .glass:
                // The same wash, inner glow and rim as `GlassCardBackground`.
                guard style.cardOpacity > 0 else { return }
                let shape = CGPath(roundedRect: rect, cornerWidth: 24, cornerHeight: 24, transform: nil)
                painter.fill(shape, (style.cardTint ?? .white).opacity(0.05 + 0.2 * style.cardOpacity))
                painter.innerShadow(shape, .white.opacity(0.2), blur: 8, offset: .zero)
                painter.gradientStroke(shape, width: 3, stops: [
                    (.white.opacity(0.95), 0), (.white.opacity(0.2), 0.35),
                    (.white.opacity(0.15), 0.65), (.white.opacity(0.8), 1),
                ])
            }
        } }
    }

    private static func render(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        // 8 bits per channel. On wide-colour screens the default is 16, which doubles every
        // image in the timeline archive.
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }
    }
}

/// Core Graphics versions of the SwiftUI effects `ClockFace` uses.
struct Painter {
    var ctx: CGContext
    /// Shadows are measured in pixels, not points, so blurs are multiplied by this.
    var scale: CGFloat
    var dark: Bool
    var bounds: CGRect
    /// The part of `bounds` the image covers.
    var area: CGRect

    func cg(_ color: Color) -> CGColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light)).cgColor
    }

    func fill(_ path: CGPath, _ color: Color) {
        ctx.addPath(path)
        ctx.setFillColor(cg(color))
        ctx.fillPath()
    }

    func linearGradient(_ path: CGPath, stops: [(Color, CGFloat)], from start: CGPoint, to end: CGPoint) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: stops.map { cg($0.0) } as CFArray,
            locations: stops.map(\.1)
        ) else { return }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    var topLeading: CGPoint { CGPoint(x: bounds.minX, y: bounds.minY) }
    var bottomTrailing: CGPoint { CGPoint(x: bounds.maxX, y: bounds.maxY) }

    /// Draws a blurred copy of `path`, as a Core Graphics shadow. `blur` is a SwiftUI-style
    /// radius in points. With `knockout` the sharp copy that casts the shadow is erased again,
    /// leaving only the soft part (for glows and shadows behind see-through text).
    func blurredCopy(_ path: CGPath, _ color: Color, blur: CGFloat, offset: CGSize = .zero,
                     evenOdd: Bool = false, knockout: Bool = true) {
        var shift = CGAffineTransform(translationX: offset.width, y: offset.height)
        guard let moved = path.copy(using: &shift) else { return }
        let rule: CGPathFillRule = evenOdd ? .evenOdd : .winding
        // Wide blurs are slow at full resolution, and the widget draws an hour of entries at
        // once under a time limit ("Watchdog provision violated", observed 2026-10-20). They
        // look the same drawn at low resolution and scaled up, so they are.
        let pixelsPerPoint = min(scale, max(0.05, 6 / blur))
        guard pixelsPerPoint < scale else {
            castShadow(moved, rule: rule, color: color, blur: blur * 2 * scale, knockout: knockout)
            return
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = pixelsPerPoint
        format.preferredRange = .standard
        let soft = UIGraphicsImageRenderer(size: area.size, format: format).image { context in
            context.cgContext.translateBy(x: -area.minX, y: -area.minY)
            var low = self
            low.ctx = context.cgContext
            low.scale = pixelsPerPoint
            low.castShadow(moved, rule: rule, color: color, blur: blur * 2 * pixelsPerPoint, knockout: knockout)
        }
        soft.draw(in: area)
    }

    /// A Core Graphics shadow of `path` with `blur` in pixels, optionally without the path itself.
    private func castShadow(_ path: CGPath, rule: CGPathFillRule, color: Color, blur: CGFloat, knockout: Bool) {
        ctx.saveGState()
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setShadow(offset: .zero, blur: blur, color: cg(color))
        ctx.addPath(path)
        ctx.setFillColor(cg(knockout ? .black : color))
        ctx.fillPath(using: rule)
        if knockout {
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setBlendMode(.clear)
            ctx.addPath(path)
            ctx.fillPath(using: rule)
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    /// Like SwiftUI's `.shadow(.inner(...))`: a shadow cast inside the shape by its edges.
    func innerShadow(_ path: CGPath, _ color: Color, blur: CGFloat, offset: CGSize) {
        let ring = CGMutablePath()
        ring.addRect(path.boundingBoxOfPath.insetBy(dx: -blur * 4 - 40, dy: -blur * 4 - 40))
        ring.addPath(path)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        blurredCopy(ring, color, blur: blur, offset: offset, evenOdd: true)
        ctx.restoreGState()
    }

    /// A stroke whose inner half shows, coloured by a diagonal gradient.
    func gradientStroke(_ path: CGPath, width: CGFloat, stops: [(Color, CGFloat)]) {
        let outline = path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        linearGradient(outline, stops: stops, from: topLeading, to: bottomTrailing)
        ctx.restoreGState()
    }

    /// The glow or shadow behind the text, as in `LightLayer`.
    func light(_ path: CGPath, style: ClockStyle, unit u: CGFloat) {
        let color = style.resolvedEffectColor
        switch style.effect {
        case .none:
            break
        case .glow:
            blurredCopy(path, color.opacity(style.effectStrength), blur: u * (2 + 10 * style.effectSize))
            blurredCopy(path, color.opacity(0.8 * style.effectStrength), blur: u * (8 + 40 * style.effectSize))
        case .shadow:
            blurredCopy(path, color.opacity(style.effectStrength), blur: u * (1 + 14 * style.effectSize),
                        offset: CGSize(width: 0, height: u * 24 * style.effectDistance))
        }
    }

    /// The text fill, as in `ClockStyle.textStyle` and `ClockFace.lettering`.
    func text(_ path: CGPath, style: ClockStyle, unit: CGFloat) {
        let k = max(0.6, unit)
        switch style.textFill {
        case .solid:
            fill(path, style.color.color)
        case .gradient:
            let box = path.boundingBoxOfPath
            linearGradient(path, stops: [(style.color.color, 0), (style.gradientColor.color, 1)],
                           from: CGPoint(x: box.midX, y: bounds.minY), to: CGPoint(x: box.midX, y: bounds.maxY))
        case .glass:
            let body = style.color == .auto ? (dark ? Color.white : Color(white: 0.15)) : style.color.color
            linearGradient(path, stops: [(body.opacity(0.5), 0), (body.opacity(0.18), 0.5), (body.opacity(0.38), 1)],
                           from: topLeading, to: bottomTrailing)
            innerShadow(path, .white, blur: 0.5 * k, offset: CGSize(width: 1.5 * k, height: 1.5 * k))
            innerShadow(path, .black.opacity(dark ? 0.35 : 0.45), blur: k, offset: CGSize(width: -1.5 * k, height: -2 * k))
            innerShadow(path, .white.opacity(0.6), blur: 6 * k, offset: CGSize(width: -3 * k, height: -3 * k))
        }
        if style.textFill == .glass {
            gradientStroke(path, width: max(1, 1.6 * unit) * 2, stops: [
                (.white.opacity(0.9), 0), (.white.opacity(0.15), 0.45), (.white.opacity(0.55), 1),
            ])
        }
    }
}
