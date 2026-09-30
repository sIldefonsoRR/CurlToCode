// Renders app views offscreen to PNGs (no screen-recording permission needed).
// Built by snapshot.sh together with the app sources, minus the @main App file.
import AppKit
import SwiftUI

@main
enum Snapshot {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
        // Not running from the bundle, so borrow the built app's icon
        if let icon = NSImage(contentsOfFile: "build/CurlToCode.app/Contents/Resources/AppIcon.icns") {
            app.applicationIconImage = icon
        }

        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            let model = ConverterModel()
            model.showSplash = false
            render(ContentView().environmentObject(model), size: NSSize(width: 1180, height: 720), dark: dark, to: "\(out)/main-\(suffix).png")

            model.language = .rust
            render(ContentView().environmentObject(model), size: NSSize(width: 1180, height: 720), dark: dark, to: "\(out)/rust-\(suffix).png")

            model.curlText = ""
            render(ContentView().environmentObject(model), size: NSSize(width: 940, height: 540), dark: dark, to: "\(out)/empty-\(suffix).png")

            model.curlText = "curl 'https://e.com"
            render(ContentView().environmentObject(model), size: NSSize(width: 940, height: 540), dark: dark, to: "\(out)/error-\(suffix).png")
            model.language = .python
        }
        render(SplashView(), size: NSSize(width: 1150, height: 680), dark: false, to: "\(out)/splash.png")
        render(HelpView(), size: NSSize(width: 640, height: 900), dark: false, to: "\(out)/help.png")
    }

    static func render<V: View>(_ view: V, size: NSSize, dark: Bool, to path: String) {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()
        host.display()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}
