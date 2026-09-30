import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// App state shared by the main window and the menu bar commands.
/// An ObservableObject rather than @State because @State is a macro in recent
/// SDKs, and its plugin isn't shipped with the Command Line Tools.
final class ConverterModel: ObservableObject {
    static let example = """
    curl 'https://httpbin.org/post?source=app' \\
      -H 'Accept: application/json' \\
      -H 'Content-Type: application/json' \\
      -H 'Cookie: session=abc123' \\
      --data-raw '{"name": "widget", "tags": ["a", "b"], "active": true}'
    """

    private let defaults: UserDefaults

    @Published var curlText = ConverterModel.example
    @Published var language: Language {
        didSet { defaults.set(language.rawValue, forKey: "language") }
    }
    @Published var splitQueryParams: Bool {
        didSet { defaults.set(splitQueryParams, forKey: "splitQueryParams") }
    }
    @Published var includePrint: Bool {
        didSet { defaults.set(includePrint, forKey: "includePrint") }
    }
    @Published var copied = false
    @Published var showSplash = true
    @Published var loadedFileName: String?

    /// `defaults` stores the chosen language and options; tests pass a throwaway suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .python
        splitQueryParams = defaults.object(forKey: "splitQueryParams") as? Bool ?? true
        includePrint = defaults.object(forKey: "includePrint") as? Bool ?? true
    }

    var conversion: Result<String, Error> {
        Result {
            try CodeGenerator.generate(
                curlText,
                language: language,
                options: GeneratorOptions(splitQueryParams: splitQueryParams, includePrint: includePrint)
            )
        }
    }

    var code: String { (try? conversion.get()) ?? "" }

    var inputIsEmpty: Bool { curlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - Actions

    func paste() {
        if let text = NSPasteboard.general.string(forType: .string) {
            curlText = text
            loadedFileName = nil
        }
    }

    func loadExample() {
        curlText = ConverterModel.example
        loadedFileName = nil
    }

    func clear() {
        curlText = ""
        loadedFileName = nil
    }

    func copy() {
        let code = code
        guard !code.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.copied = false }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.title = "Open cURL Command"
        panel.message = "Choose a text or shell script file containing a curl command."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url)
    }

    func load(_ url: URL) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int, size > 5_000_000 {
                throw CocoaError(.fileReadTooLarge)
            }
            var encoding = String.Encoding.utf8
            if let text = try? String(contentsOf: url, usedEncoding: &encoding) {
                curlText = text
            } else {
                curlText = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            }
            loadedFileName = url.lastPathComponent
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func save() {
        let code = code
        guard !code.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Save \(language.displayName) Code"
        if let type = UTType(filenameExtension: language.fileExtension) {
            panel.allowedContentTypes = [type]
        }
        panel.nameFieldStringValue = language.defaultFileName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try code.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
