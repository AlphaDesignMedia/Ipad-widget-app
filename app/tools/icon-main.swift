// Draws the Pip Sandbox app icon with PipBody (GlassClock/Pieces/PipLook.swift). Run make-icon.sh.
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct PipIcon: View {
    let sparkles: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (512, 175, 28), (140, 470, 18), (885, 450, 24), (300, 860, 15), (745, 850, 21), (875, 175, 11),
    ]

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 31 / 255, green: 58 / 255, blue: 128 / 255),
                                    Color(red: 10 / 255, green: 19 / 255, blue: 48 / 255)],
                           center: UnitPoint(x: 0.5, y: 0.45), startRadius: 0, endRadius: 720)
            Circle()
                .fill(RadialGradient(colors: [PipLook.glow.opacity(0.45), PipLook.glow.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 430))
                .frame(width: 860, height: 860)
                .position(x: 512, y: 540)
            ForEach(sparkles.indices, id: \.self) { i in
                let s = sparkles[i]
                ZStack {
                    Circle().fill(RadialGradient(colors: [PipLook.glow.opacity(0.6), PipLook.glow.opacity(0)],
                                                 center: .center, startRadius: 0, endRadius: s.r * 2.4))
                        .frame(width: s.r * 4.8, height: s.r * 4.8)
                    PipSparkle().fill(.white).frame(width: s.r * 2, height: s.r * 2)
                }
                .position(x: s.x, y: s.y)
            }
            PipBody(face: .awake, size: 370, rim: 0.3)
                .position(x: 512, y: 545)
        }
        .frame(width: 1024, height: 1024)
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: PipIcon())
    renderer.scale = 1
    guard let image = renderer.cgImage else { fatalError("Couldn't draw the icon.") }
    // App icons have no transparency: draw onto an opaque canvas.
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Couldn't save the icon.") }
    print("Icon saved.")
}
