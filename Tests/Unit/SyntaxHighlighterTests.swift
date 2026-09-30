import AppKit
import Foundation

private let base: [NSAttributedString.Key: Any] = [.font: CodeTheme.font, .foregroundColor: CodeTheme.text]

/// Highlights `text` and returns the color at the first occurrence of `fragment`.
private func color(of fragment: String, in text: String, as highlight: Highlight?) -> NSColor? {
    let storage = NSTextStorage(string: text)
    SyntaxHighlighter.apply(to: storage, highlight: highlight, base: base)
    let range = (text as NSString).range(of: fragment)
    guard range.location != NSNotFound else { return nil }
    return storage.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
}

let syntaxHighlighterTests = TestSuite("SyntaxHighlighter", [
    Test("no highlight leaves plain text") {
        expectTrue(color(of: "curl", in: "curl 'x'", as: nil) === CodeTheme.text)
    },
    Test("curl input: command, flags, strings and URLs") {
        let text = "curl https://e.com -H 'Accept: x' \\\n  --data-raw 'y'"
        expectTrue(color(of: "curl", in: text, as: .curl) === CodeTheme.keyword)
        expectTrue(color(of: "-H", in: text, as: .curl) === CodeTheme.flag)
        expectTrue(color(of: "--data-raw", in: text, as: .curl) === CodeTheme.flag)
        expectTrue(color(of: "'Accept", in: text, as: .curl) === CodeTheme.string)
        expectTrue(color(of: "https", in: text, as: .curl) === CodeTheme.url)
    },
    Test("code: keywords, strings, numbers, types") {
        let text = "import requests\nx = requests.get('a', timeout=30)\nprint(True)"
        let py = Highlight.code(.python)
        expectTrue(color(of: "import", in: text, as: py) === CodeTheme.keyword)
        expectTrue(color(of: "'a'", in: text, as: py) === CodeTheme.string)
        expectTrue(color(of: "30", in: text, as: py) === CodeTheme.number)
        expectTrue(color(of: "True", in: text, as: py) === CodeTheme.keyword)
        expectTrue(color(of: "Client", in: "let c = Client::new();", as: .code(.rust)) === CodeTheme.type)
    },
    Test("comment lines use the language's comment syntax") {
        expectTrue(color(of: "# Note", in: "# Note: x\nimport requests", as: .code(.python)) === CodeTheme.comment)
        expectTrue(color(of: "// Note", in: "// Note: x\nlet a = 1", as: .code(.swift)) === CodeTheme.comment)
    },
    Test("# and // inside strings are not comments") {
        expectTrue(color(of: "#b", in: "x = 'a#b'", as: .code(.python)) === CodeTheme.string)
        expectTrue(color(of: "//e.com", in: "fetch('https://e.com')", as: .code(.javascript)) === CodeTheme.string)
    },
    Test("Go backtick strings are highlighted") {
        expectTrue(color(of: "json", in: "body := `json`", as: .code(.go)) === CodeTheme.string)
    },
    Test("reapplying resets old colors") {
        let storage = NSTextStorage(string: "import x")
        SyntaxHighlighter.apply(to: storage, highlight: .code(.python), base: base)
        SyntaxHighlighter.apply(to: storage, highlight: nil, base: base)
        expectTrue(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor === CodeTheme.text)
    },
])

let themeTests = TestSuite("Theme", [
    Test("adaptive colors resolve differently in light and dark") {
        let light = NSAppearance(named: .aqua)!
        let dark = NSAppearance(named: .darkAqua)!
        var lightColor: NSColor?
        var darkColor: NSColor?
        light.performAsCurrentDrawingAppearance { lightColor = CodeTheme.background.usingColorSpace(.sRGB) }
        dark.performAsCurrentDrawingAppearance { darkColor = CodeTheme.background.usingColorSpace(.sRGB) }
        expectEqual(lightColor?.brightnessComponent ?? 0, 1, "light editor background is white")
        expectTrue((darkColor?.brightnessComponent ?? 1) < 0.2, "dark editor background is dark")
    },
    Test("hex colors decode") {
        let c = NSColor(hex: 0x3776AB)
        expectEqual(Int((c.redComponent * 255).rounded()), 0x37)
        expectEqual(Int((c.greenComponent * 255).rounded()), 0x76)
        expectEqual(Int((c.blueComponent * 255).rounded()), 0xAB)
    },
])
