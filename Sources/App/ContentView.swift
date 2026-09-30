import AppKit
import SwiftUI

/// Main window: header with language chips, input and output cards, status bar,
/// and the splash overlay shown at launch.
struct ContentView: View {
    @EnvironmentObject private var model: ConverterModel

    var body: some View {
        ZStack {
            mainContent
            if model.showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
                    .onTapGesture { dismissSplash() }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { dismissSplash() }
        }
    }

    private func dismissSplash() {
        guard model.showSplash else { return }
        withAnimation(.easeOut(duration: 0.4)) { model.showSplash = false }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                inputCard
                connector
                outputCard
            }
            .padding(.horizontal, 16)
            statusBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 26, height: 26)
            Text("cURL to Code")
                .font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 16)
            LanguageChips(selection: $model.language)
        }
        // Leading room for the window's traffic-light buttons (hidden title bar)
        .padding(.leading, 84)
        .padding(.trailing, 16)
        .frame(height: 56)
    }

    // MARK: - Cards

    private var inputCard: some View {
        Card {
            HStack(spacing: 10) {
                IconBadge(systemImage: "terminal.fill", color: Color(white: 0.28))
                VStack(alignment: .leading, spacing: 1) {
                    Text("cURL command").font(.system(size: 13, weight: .semibold))
                    Text(inputSubtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                // Labeled buttons when there's room, icons only in narrow windows
                ViewThatFits(in: .horizontal) {
                    inputButtons(labeled: true)
                    inputButtons(labeled: false)
                }
            }
        } content: {
            CodeTextView(text: $model.curlText, highlight: .curl)
                .clipped()
        }
        .frame(minWidth: 300, maxWidth: .infinity)
    }

    private var outputCard: some View {
        Card {
            HStack(spacing: 10) {
                IconBadge(systemImage: "chevron.left.forwardslash.chevron.right", color: model.language.color, foreground: model.language.onColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.language.displayName).font(.system(size: 13, weight: .semibold))
                    Text(outputSubtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                HStack(spacing: 6) {
                    headerButton("Save…", systemImage: "square.and.arrow.down", help: "Save the generated code to a file (⌘S)", action: model.save)
                        .disabled(model.code.isEmpty)
                    Button(action: model.copy) {
                        Label(model.copied ? "Copied" : "Copy", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                            .frame(minWidth: 62)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(model.copied ? .green : .accentColor)
                    .controlSize(.small)
                    .help("Copy the generated code (⇧⌘C)")
                    .disabled(model.code.isEmpty)
                }
            }
        } content: {
            ZStack {
                CodeTextView(text: .constant(model.code), isEditable: false, highlight: .code(model.language))
                    .clipped()
                if model.code.isEmpty { emptyState }
            }
        }
        .frame(minWidth: 340, maxWidth: .infinity)
    }

    private var connector: some View {
        let ok = !model.code.isEmpty
        return Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(ok ? model.language.onColor : .secondary)
            .frame(width: 28, height: 28)
            .background(Circle().fill(ok ? AnyShapeStyle(model.language.color.gradient) : AnyShapeStyle(Color(nsColor: CodeTheme.gutter))))
            .overlay(Circle().strokeBorder(Color.primary.opacity(ok ? 0 : 0.1)))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            .frame(width: 20)
            .zIndex(1)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            if model.inputIsEmpty {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Paste a cURL command to get started")
                    .font(.headline)
                Text("Tip: in your browser's developer tools, right-click a request\nand choose Copy ▸ Copy as cURL.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Button("Paste", systemImage: "doc.on.clipboard", action: model.paste)
                    Button("Open File…", systemImage: "folder", action: model.openFile)
                    Button("Try an Example", systemImage: "sparkles", action: model.loadExample)
                }
                .controlSize(.regular)
                .padding(.top, 4)
            } else if case .failure(let error) = model.conversion {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.orange)
                Text("Can't convert this yet")
                    .font(.headline)
                Text(error.localizedDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: CodeTheme.background))
    }

    private func inputButtons(labeled: Bool) -> some View {
        HStack(spacing: 6) {
            headerButton(labeled ? "Open…" : nil, systemImage: "folder", help: "Load a curl command from a file (⌘O)", action: model.openFile)
            headerButton(labeled ? "Paste" : nil, systemImage: "doc.on.clipboard", help: "Replace with clipboard contents (⇧⌘V)", action: model.paste)
            headerButton(nil, systemImage: "xmark", help: "Clear the input", action: model.clear)
                .disabled(model.inputIsEmpty)
        }
        .fixedSize()
    }

    private func headerButton(_ title: String?, systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if let title {
                Label(title, systemImage: systemImage)
            } else {
                Image(systemName: systemImage)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(help)
    }

    private var inputSubtitle: String {
        if let file = model.loadedFileName { return file }
        if model.inputIsEmpty { return "Empty" }
        let lines = model.curlText.components(separatedBy: "\n").count
        return lines == 1 ? "1 line" : "\(lines) lines"
    }

    private var outputSubtitle: String {
        let code = model.code
        guard !code.isEmpty else { return model.language.library }
        let lines = code.components(separatedBy: "\n").count - 1
        return "\(model.language.library) · \(lines) lines"
    }

    // MARK: - Status bar

    private var noteCount: Int {
        model.code.components(separatedBy: "\n").filter { $0.contains(" Note: ") }.count
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            switch model.conversion {
            case .success:
                StatusPill(text: "Converted to \(model.language.displayName)", systemImage: "checkmark.circle.fill", color: .green)
                if noteCount > 0 {
                    StatusPill(text: noteCount == 1 ? "1 note" : "\(noteCount) notes", systemImage: "info.circle.fill", color: .orange)
                        .help("Some options couldn't be converted exactly; see the Note comments at the top of the code.")
                }
            case .failure(let error):
                if model.inputIsEmpty {
                    StatusPill(text: "Waiting for input", systemImage: "circle.dashed", color: .secondary)
                } else {
                    StatusPill(text: error.localizedDescription, systemImage: "exclamationmark.triangle.fill", color: .orange)
                }
            }
            Spacer()
            Toggle("Query string → params", isOn: $model.splitQueryParams)
                .disabled(!model.language.supportsParamsSplit)
                .help("Python only: move the URL's query string into a params dict")
            Toggle("Print response", isOn: $model.includePrint)
                .help("End the code by printing the status code and response body")
        }
        .toggleStyle(.checkbox)
        .font(.callout)
        .padding(.horizontal, 18)
        .frame(height: 44)
    }
}

private struct StatusPill: View {
    var text: String
    var systemImage: String
    var color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.callout.weight(.medium))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// Segmented row of language chips, each selected in the language's own color.
struct LanguageChips: View {
    @Binding var selection: Language

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(Language.allCases.enumerated()), id: \.element) { index, language in
                let selected = language == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selection = language }
                } label: {
                    Text(language.displayName)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? language.onColor : Color.primary.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                Capsule().fill(language.color.gradient)
                                    .shadow(color: language.color.opacity(0.35), radius: 3, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("\(language.displayName) · \(language.library) (⌘\(index + 1))")
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06)))
    }
}
