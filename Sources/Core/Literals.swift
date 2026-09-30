import Foundation

/// String-literal escaping and JSON rendering shared by the language generators.
enum Literals {
    /// Python-style: single quotes unless the text has ' but no ".
    static func python(_ s: String) -> String {
        let quote: Character = s.contains("'") && !s.contains("\"") ? "\"" : "'"
        return quoted(s, quote: quote) { String(format: "\\x%02x", $0) }
    }

    /// JavaScript single-quoted string.
    static func javaScript(_ s: String) -> String {
        var out = quoted(s, quote: "'") { String(format: "\\x%02x", $0) }
        out = out.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        return out.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    /// Double-quoted string for C-family languages. `control` renders other control characters.
    static func doubleQuoted(_ s: String, control: (UInt32) -> String) -> String {
        quoted(s, quote: "\"", control: control)
    }

    static func cSharp(_ s: String) -> String { doubleQuoted(s) { String(format: "\\u%04x", $0) } }
    static func go(_ s: String) -> String { doubleQuoted(s) { String(format: "\\x%02x", $0) } }
    static func json(_ s: String) -> String { doubleQuoted(s) { String(format: "\\u%04x", $0) } }
    static func rust(_ s: String) -> String { doubleQuoted(s) { String(format: "\\u{%x}", $0) } }
    static func swift(_ s: String) -> String { doubleQuoted(s) { String(format: "\\u{%x}", $0) } }
    /// Java: octal escapes, since \u escapes are processed before lexing.
    static func java(_ s: String) -> String { doubleQuoted(s) { String(format: "\\%03o", $0) } }

    /// Ruby/PHP: single quotes when possible (no interpolation), otherwise escaped double quotes.
    static func ruby(_ s: String) -> String {
        if !hasControl(s) { return "'" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'" }
        return doubleQuoted(s) { String(format: "\\x%02x", $0) }.replacingOccurrences(of: "#", with: "\\#")
    }

    static func php(_ s: String) -> String {
        if !hasControl(s) { return "'" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") + "'" }
        return doubleQuoted(s) { String(format: "\\x%02x", $0) }.replacingOccurrences(of: "$", with: "\\$")
    }

    static func hasControl(_ s: String) -> Bool {
        s.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F }
    }

    private static func quoted(_ s: String, quote: Character, control: (UInt32) -> String) -> String {
        var out = String(quote)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if Character(scalar) == quote {
                    out += "\\" + String(quote)
                } else if scalar.value < 0x20 || scalar.value == 0x7F {
                    out += control(scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out.append(quote)
        return out
    }

    /// How to spell a JSON value as a native literal.
    struct Style {
        var string: (String) -> String
        var key: (String) -> String
        var separator = ": "
        var trueLiteral = "true"
        var falseLiteral = "false"
        var nullLiteral = "null"
        var indentUnit = "  "
        var trailingComma = true
    }

    static let jsonStyle = Style(string: json, key: json, trailingComma: false)

    static func render(_ value: JSONValue, style: Style, indent: Int = 0) -> String {
        let pad = String(repeating: style.indentUnit, count: indent)
        let inner = pad + style.indentUnit
        let comma = style.trailingComma ? "," : ""
        func block(_ open: String, _ close: String, _ lines: [String]) -> String {
            open + "\n" + lines.map { inner + $0 }.joined(separator: ",\n") + comma + "\n" + pad + close
        }
        switch value {
        case .object(let items):
            if items.isEmpty { return "{}" }
            return block("{", "}", items.map { style.key($0.0) + style.separator + render($0.1, style: style, indent: indent + 1) })
        case .array(let items):
            if items.isEmpty { return "[]" }
            return block("[", "]", items.map { render($0, style: style, indent: indent + 1) })
        case .string(let s): return style.string(s)
        case .number(let n): return n
        case .bool(let b): return b ? style.trueLiteral : style.falseLiteral
        case .null: return style.nullLiteral
        }
    }

    /// Pretty-printed JSON text.
    static func jsonText(_ value: JSONValue) -> String {
        render(value, style: jsonStyle)
    }

    /// Indents every line of `text` by `prefix`.
    static func indent(_ text: String, _ prefix: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { prefix + $0 }.joined(separator: "\n")
    }

    /// Timeout seconds as a number literal ("30" rather than "30.0" when whole).
    static func number(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }
}
