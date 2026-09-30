// Renders the Installer background images: swift make-installer-art.swift <app-icon.icns> <out-dir>
// Produces background.png (light) and background-dark.png, shown in the left part of the
// Installer window behind the step list.
import AppKit

let iconPath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
let icon = NSImage(contentsOfFile: iconPath)

// Installer's sidebar area is about 170pt wide; 2x for Retina
let size = NSSize(width: 620, height: 418)

func render(dark: Bool) -> Data {
    let scale: CGFloat = 2
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Soft brand glow in the bottom-left corner, fading out to full transparency
    let ctx = NSGraphicsContext.current!.cgContext
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let alpha: CGFloat = dark ? 0.45 : 0.22
    let glow = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: 0.21, green: 0.45, blue: 0.65, alpha: alpha),
        CGColor(srgbRed: 0.21, green: 0.45, blue: 0.65, alpha: alpha * 0.35),
        CGColor(srgbRed: 0.21, green: 0.45, blue: 0.65, alpha: 0),
    ] as CFArray, locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 60, y: 60), startRadius: 0,
                           endCenter: CGPoint(x: 60, y: 60), endRadius: 330, options: [])

    // App icon, slightly rotated, partly off the corner
    if let icon {
        ctx.saveGState()
        ctx.translateBy(x: 88, y: 88)
        ctx.rotate(by: 0.18)
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        icon.draw(in: NSRect(x: -80, y: -80, width: 160, height: 160), from: .zero, operation: .sourceOver, fraction: dark ? 0.95 : 0.9)
        ctx.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
try render(dark: false).write(to: URL(fileURLWithPath: "\(outDir)/background.png"))
try render(dark: true).write(to: URL(fileURLWithPath: "\(outDir)/background-dark.png"))
