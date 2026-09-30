import AppKit
import SwiftUI

/// What a `CodeTextView` should be syntax-highlighted as.
enum Highlight: Equatable {
    case curl
    case code(Language)
}

/// Monospaced NSTextView wrapper with a line-number gutter. Unlike SwiftUI's
/// TextEditor it disables smart quotes/dashes, which would silently corrupt
/// pasted shell commands.
struct CodeTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable = true
    var highlight: Highlight?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = CodeTheme.background
        scroll.scrollerStyle = .overlay
        let tv = scroll.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = CodeTheme.font
        tv.textColor = CodeTheme.text
        tv.backgroundColor = CodeTheme.background
        tv.insertionPointColor = .controlAccentColor
        tv.defaultParagraphStyle = CodeTheme.paragraph
        tv.typingAttributes = baseAttributes
        tv.textContainerInset = NSSize(width: 6, height: 12)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.smartInsertDeleteEnabled = false

        let ruler = LineNumberRuler(textView: tv)
        if #available(macOS 14, *) { ruler.clipsToBounds = true }
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true

        setText(text, on: tv)
        context.coordinator.highlighted = highlight
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? NSTextView else { return }
        if tv.string != text || context.coordinator.highlighted != highlight {
            setText(text, on: tv)
            context.coordinator.highlighted = highlight
            scroll.verticalRulerView?.needsDisplay = true
        }
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: CodeTheme.font, .foregroundColor: CodeTheme.text, .paragraphStyle: CodeTheme.paragraph]
    }

    fileprivate func setText(_ value: String, on tv: NSTextView) {
        if tv.string != value {
            let selection = tv.selectedRanges
            tv.string = value
            if tv.isEditable { tv.selectedRanges = selection.filter { NSMaxRange($0.rangeValue) <= (value as NSString).length } }
        }
        if let storage = tv.textStorage {
            SyntaxHighlighter.apply(to: storage, highlight: highlight, base: baseAttributes)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextView
        var highlighted: Highlight?

        init(_ parent: CodeTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            if let storage = tv.textStorage {
                SyntaxHighlighter.apply(to: storage, highlight: parent.highlight, base: parent.baseAttributes)
            }
            tv.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }
    }
}

/// Gutter that draws line numbers for the visible part of a text view.
final class LineNumberRuler: NSRulerView {
    private weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
        if let clip = textView.enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSView.boundsDidChangeNotification, object: clip)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSText.didChangeNotification, object: textView)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func refresh() { needsDisplay = true }

    // Draw only the numbers: NSRulerView's default drawing adds a border line,
    // which (with views no longer clipping by default) bleeds outside the gutter.
    override func draw(_ dirtyRect: NSRect) {
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        CodeTheme.background.setFill()
        bounds.fill()
        guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer else { return }

        let string = tv.string as NSString
        let lineCount = max(1, string.components(separatedBy: "\n").count)
        let wanted = CGFloat(max(2, String(lineCount).count)) * 8 + 22
        if abs(ruleThickness - wanted) > 0.5 { ruleThickness = wanted }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: CodeTheme.lineNumber,
        ]
        let origin = convert(NSPoint.zero, from: tv).y + tv.textContainerInset.height
        let visible = tv.visibleRect
        let glyphs = lm.glyphRange(forBoundingRect: visible, in: tc)
        let chars = lm.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)

        func draw(_ number: Int, in lineRect: NSRect) {
            let label = "\(number)" as NSString
            let size = label.size(withAttributes: attrs)
            // Line height multiple adds space above the glyphs, so align to the bottom
            let y = origin + lineRect.maxY - size.height - 2
            label.draw(at: NSPoint(x: ruleThickness - size.width - 10, y: y), withAttributes: attrs)
        }

        var index = string.lineRange(for: NSRange(location: chars.location, length: 0)).location
        var number = 1
        for i in 0..<index where string.character(at: i) == 10 { number += 1 }

        while index < string.length && index <= NSMaxRange(chars) {
            let line = string.lineRange(for: NSRange(location: index, length: 0))
            let glyph = lm.glyphIndexForCharacter(at: line.location)
            draw(number, in: lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil))
            number += 1
            index = NSMaxRange(line)
        }
        // Empty document, or the empty line after a trailing newline
        if string.length == 0 || string.hasSuffix("\n") {
            let extra = lm.extraLineFragmentRect
            if extra.height > 0 { draw(number, in: extra) } else if string.length == 0 { draw(1, in: NSRect(x: 0, y: 0, width: 0, height: 16)) }
        }
    }
}

/// Small regex-based highlighter for the curl input and the generated code.
enum SyntaxHighlighter {
    private static var cache: [String: [(NSRegularExpression, NSColor)]] = [:]

    private static let stringPattern = #"'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*""#

    private static func rules(for highlight: Highlight) -> [(NSRegularExpression, NSColor)] {
        let key: String
        var patterns: [(String, NSColor)]
        switch highlight {
        case .curl:
            key = "curl"
            patterns = [
                (#"^\s*(curl)\b"#, CodeTheme.keyword),
                (#"(?<=\s)--?[A-Za-z0-9#][\w.-]*"#, CodeTheme.flag),
                (stringPattern, CodeTheme.string),
                (#"https?://[^\s'"\\]+"#, CodeTheme.url),
                (#"(?<=\s)\\$"#, CodeTheme.comment),
                (#"^[ \t]*#[^\n]*"#, CodeTheme.comment),
            ]
        case .code(let language):
            key = language.rawValue
            let keywords = language.keywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            let comment = NSRegularExpression.escapedPattern(for: language.lineComment)
            patterns = [
                (#"\b[A-Z][A-Za-z0-9]*(?=[.(:<{])"#, CodeTheme.type),
                (#"\b(\#(keywords))\b"#, CodeTheme.keyword),
                (#"(?<![\w.])-?\d+(\.\d+)?([eE][+-]?\d+)?\b"#, CodeTheme.number),
                (stringPattern, CodeTheme.string),
            ]
            if language == .go { patterns.append((#"`[^`]*`"#, CodeTheme.string)) }
            // Generated code only has whole-line comments; matching those alone keeps
            // "#" and "//" inside strings and URLs from being treated as comments.
            patterns.append((#"^[ \t]*\#(comment)[^\n]*"#, CodeTheme.comment))
        }
        if let cached = cache[key] { return cached }
        let compiled = patterns.map { (try! NSRegularExpression(pattern: $0.0, options: .anchorsMatchLines), $0.1) }
        cache[key] = compiled
        return compiled
    }

    static func apply(to storage: NSTextStorage, highlight: Highlight?, base: [NSAttributedString.Key: Any]) {
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes(base, range: full)
        if let highlight {
            for (regex, color) in rules(for: highlight) {
                for match in regex.matches(in: storage.string, range: full) {
                    let range = match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound && highlight == .curl
                        ? match.range(at: 1) : match.range
                    storage.addAttribute(.foregroundColor, value: color, range: range)
                }
            }
        }
        storage.endEditing()
    }
}
