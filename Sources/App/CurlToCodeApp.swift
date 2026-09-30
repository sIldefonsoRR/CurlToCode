import AppKit
import SwiftUI

/// App entry point: the main window, the Help window and the menu bar commands,
/// all sharing one `ConverterModel`.
@main
struct CurlToCodeApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var model = ConverterModel()

    var body: some Scene {
        Window("cURL to Code", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 940, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open cURL File…", action: model.openFile)
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Code…", action: model.save)
                    .keyboardShortcut("s")
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Paste cURL Command", action: model.paste)
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button("Copy Generated Code", action: model.copy)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
            CommandMenu("Language") {
                LanguageMenuItems(model: model)
            }
            CommandGroup(replacing: .help) {
                HelpMenuItem()
            }
        }

        Window("cURL to Code Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 640, height: 720)
    }
}

/// Language menu entries with a checkmark on the current one and ⌘1–⌘9 shortcuts.
private struct LanguageMenuItems: View {
    @ObservedObject var model: ConverterModel

    var body: some View {
        ForEach(Array(Language.allCases.enumerated()), id: \.element) { index, language in
            Toggle(
                "\(language.displayName)  (\(language.library))",
                isOn: Binding(get: { model.language == language }, set: { if $0 { model.language = language } })
            )
            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
        }
    }
}

private struct HelpMenuItem: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("cURL to Code Help") { openWindow(id: "help") }
            .keyboardShortcut("?", modifiers: .command)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare binary (e.g. during development).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
