// Renders the app icon PNGs into an .iconset folder: swift make-icon.swift <out.iconset>
import AppKit

let outDir = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rect = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(red: 0.21, green: 0.45, blue: 0.65, alpha: 1),
               ending: NSColor(red: 0.13, green: 0.22, blue: 0.40, alpha: 1))!.draw(in: path, angle: -90)

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    func draw(_ text: String, size: CGFloat, y: CGFloat, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .bold),
            .foregroundColor: color, .paragraphStyle: para,
        ]
        text.draw(in: NSRect(x: rect.minX, y: y, width: rect.width, height: size * 1.3), withAttributes: attrs)
    }
    draw("curl", size: s * 0.15, y: s * 0.56, color: NSColor.white.withAlphaComponent(0.75))
    draw("↓", size: s * 0.12, y: s * 0.43, color: NSColor.white.withAlphaComponent(0.6))
    draw("</>", size: s * 0.2, y: s * 0.18, color: NSColor(red: 1, green: 0.83, blue: 0.23, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base).png"))
    try render(base * 2).write(to: URL(fileURLWithPath: "\(outDir)/icon_\(base)x\(base)@2x.png"))
}
