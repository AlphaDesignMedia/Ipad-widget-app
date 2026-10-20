import SwiftUI
import UIKit
import CoreImage

/// The clock drawn with Core Graphics into an image, for the Clear and Tinted Home Screens.
///
/// In those styles iPadOS recolours everything in a widget except images marked
/// `.widgetAccentedRenderingMode(.fullColor)`. So the parts someone chooses to keep in colour
/// are drawn here, matching `ClockFace` as closely as Core Graphics allows. (SwiftUI's
/// `ImageRenderer` was tried for this first and left the widget blank on iPadOS 27.)
enum ClockRaster {
    enum Part { case time, detail }

    static func image(_ part: Part, artwork: ClockArtwork, style: ClockStyle, size: CGSize,
                      scale: CGFloat, dark: Bool) -> UIImage {
        let path = (part == .time ? artwork.time : artwork.detail).cgPath
        return render(size: size, scale: scale) { ctx in
            let painter = Painter(ctx: ctx, scale: scale, dark: dark, bounds: CGRect(origin: .zero, size: size))
            ctx.setAlpha(style.textOpacity * (part == .detail ? 0.85 : 1))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            painter.light(path, style: style, unit: artwork.unit)
            if part == .detail && style.textFill == .glass {
                painter.fill(path, (style.color == .auto ? Color.white : style.color.color).opacity(0.9))
            } else {
                painter.text(path, style: style, unit: artwork.unit, withInnerColour: part == .time)
            }
            ctx.endTransparencyLayer()
        }
    }

    /// The card, filling the whole widget. The system rounds the corners.
    static func card(style: ClockStyle, size: CGSize, scale: CGFloat, dark: Bool) -> UIImage {
        render(size: size, scale: scale) { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let painter = Painter(ctx: ctx, scale: scale, dark: dark, bounds: rect)
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
        }
    }

    private static func render(size: CGSize, scale: CGFloat, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }
    }
}

/// Core Graphics versions of the SwiftUI effects `ClockFace` uses.
private struct Painter {
    var ctx: CGContext
    /// Shadows are measured in pixels, not points, so blurs are multiplied by this.
    var scale: CGFloat
    var dark: Bool
    var bounds: CGRect

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

    /// Draws a blurred copy of `path`. `blur` is a SwiftUI-style radius in points.
    /// (Casting a shadow from a copy drawn off the image doesn't work: Core Graphics skips
    /// drawing that lies entirely outside the image, shadow included.)
    func blurredCopy(_ path: CGPath, _ color: Color, blur: CGFloat, offset: CGSize = .zero, evenOdd: Bool = false) {
        // Soft blurs look the same at 1× and cost a quarter as much, which matters because the
        // widget redraws every minute.
        let pixels = blur >= 2 ? min(scale, 1) : scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = pixels
        let sharp = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            let c = context.cgContext
            c.translateBy(x: offset.width, y: offset.height)
            c.addPath(path)
            c.setFillColor(cg(color))
            c.fillPath(using: evenOdd ? .evenOdd : .winding)
        }
        guard let input = sharp.cgImage.map(CIImage.init(cgImage:)),
              let blurred = Self.ciContext.createCGImage(
                input.applyingGaussianBlur(sigma: blur * pixels).cropped(to: input.extent),
                from: input.extent
              )
        else { return }
        UIImage(cgImage: blurred, scale: pixels, orientation: .up).draw(in: bounds)
    }

    private static let ciContext = CIContext()

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
    func text(_ path: CGPath, style: ClockStyle, unit: CGFloat, withInnerColour: Bool) {
        let k = max(0.6, unit)
        switch style.textFill {
        case .solid:
            fill(path, style.color.color)
        case .gradient:
            let box = path.boundingBoxOfPath
            linearGradient(path, stops: [(style.color.color, 0), (style.gradientColor.color, 1)],
                           from: CGPoint(x: box.midX, y: bounds.minY), to: CGPoint(x: box.midX, y: bounds.maxY))
        case .glass:
            let body = style.color == .auto ? Color.white : style.color.color
            linearGradient(path, stops: [(body.opacity(0.5), 0), (body.opacity(0.18), 0.5), (body.opacity(0.38), 1)],
                           from: topLeading, to: bottomTrailing)
            innerShadow(path, .white, blur: 0.5 * k, offset: CGSize(width: 1.5 * k, height: 1.5 * k))
            innerShadow(path, .black.opacity(dark ? 0.35 : 0.45), blur: k, offset: CGSize(width: -1.5 * k, height: -2 * k))
            innerShadow(path, .white.opacity(0.6), blur: 6 * k, offset: CGSize(width: -3 * k, height: -3 * k))
        }
        if withInnerColour, let inner = style.innerColor {
            let outline = path.copy(strokingWithWidth: unit * 9, lineCap: .round, lineJoin: .round, miterLimit: 10)
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            blurredCopy(outline, inner.color.opacity(style.innerStrength), blur: unit * 4)
            ctx.restoreGState()
        }
        if style.textFill == .glass {
            gradientStroke(path, width: max(1, 1.6 * unit) * 2, stops: [
                (.white.opacity(0.9), 0), (.white.opacity(0.15), 0.45), (.white.opacity(0.55), 1),
            ])
        }
    }
}
