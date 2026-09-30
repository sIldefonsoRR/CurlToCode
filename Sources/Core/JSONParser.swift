import Foundation

/// JSON value that preserves object key order (unlike JSONSerialization).
indirect enum JSONValue {
    case object([(String, JSONValue)])
    case array([JSONValue])
    case string(String)
    /// Kept as the original text so no precision or formatting is lost.
    case number(String)
    case bool(Bool)
    case null
}

/// Minimal recursive-descent JSON parser. Used instead of JSONSerialization so generated
/// code keeps the original key order.
struct JSONParser {
    private let s: [Unicode.Scalar]
    private var i = 0

    private init(_ text: String) {
        s = Array(text.unicodeScalars)
    }

    /// The parsed value, or nil if `text` isn't exactly one valid JSON document.
    static func parse(_ text: String) -> JSONValue? {
        var p = JSONParser(text)
        p.skipWhitespace()
        guard let value = p.parseValue() else { return nil }
        p.skipWhitespace()
        return p.i == p.s.count ? value : nil
    }

    private mutating func skipWhitespace() {
        while i < s.count, [" ", "\n", "\r", "\t"].contains(s[i]) { i += 1 }
    }

    private mutating func parseValue() -> JSONValue? {
        guard i < s.count else { return nil }
        switch s[i] {
        case "{": return parseObject()
        case "[": return parseArray()
        case "\"": return parseString().map { .string($0) }
        case "t": return literal("true", .bool(true))
        case "f": return literal("false", .bool(false))
        case "n": return literal("null", .null)
        default: return parseNumber()
        }
    }

    private mutating func literal(_ word: String, _ value: JSONValue) -> JSONValue? {
        let w = Array(word.unicodeScalars)
        guard i + w.count <= s.count, Array(s[i..<i + w.count]) == w else { return nil }
        i += w.count
        return value
    }

    private mutating func parseObject() -> JSONValue? {
        i += 1
        var items: [(String, JSONValue)] = []
        skipWhitespace()
        if i < s.count && s[i] == "}" {
            i += 1
            return .object([])
        }
        while true {
            skipWhitespace()
            guard i < s.count, s[i] == "\"", let key = parseString() else { return nil }
            skipWhitespace()
            guard i < s.count, s[i] == ":" else { return nil }
            i += 1
            skipWhitespace()
            guard let value = parseValue() else { return nil }
            items.append((key, value))
            skipWhitespace()
            guard i < s.count else { return nil }
            if s[i] == "," { i += 1; continue }
            if s[i] == "}" { i += 1; return .object(items) }
            return nil
        }
    }

    private mutating func parseArray() -> JSONValue? {
        i += 1
        var items: [JSONValue] = []
        skipWhitespace()
        if i < s.count && s[i] == "]" {
            i += 1
            return .array([])
        }
        while true {
            skipWhitespace()
            guard let value = parseValue() else { return nil }
            items.append(value)
            skipWhitespace()
            guard i < s.count else { return nil }
            if s[i] == "," { i += 1; continue }
            if s[i] == "]" { i += 1; return .array(items) }
            return nil
        }
    }

    private mutating func parseString() -> String? {
        i += 1 // opening quote
        var out = String.UnicodeScalarView()
        while i < s.count {
            let c = s[i]
            i += 1
            if c == "\"" { return String(out) }
            if c == "\\" {
                guard i < s.count else { return nil }
                let e = s[i]
                i += 1
                switch e {
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                case "/": out.append("/")
                case "b": out.append("\u{08}")
                case "f": out.append("\u{0C}")
                case "n": out.append("\n")
                case "r": out.append("\r")
                case "t": out.append("\t")
                case "u":
                    guard let hi = parseHex4() else { return nil }
                    if (0xD800...0xDBFF).contains(hi), i + 1 < s.count, s[i] == "\\", s[i + 1] == "u" {
                        let save = i
                        i += 2
                        if let lo = parseHex4(), (0xDC00...0xDFFF).contains(lo),
                           let scalar = Unicode.Scalar(0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)) {
                            out.append(scalar)
                        } else {
                            i = save
                            out.append("\u{FFFD}")
                        }
                    } else {
                        out.append(Unicode.Scalar(hi) ?? "\u{FFFD}")
                    }
                default:
                    return nil
                }
            } else if c.value < 0x20 {
                return nil
            } else {
                out.append(c)
            }
        }
        return nil
    }

    private mutating func parseHex4() -> UInt32? {
        guard i + 4 <= s.count else { return nil }
        var hex = String.UnicodeScalarView()
        hex.append(contentsOf: s[i..<i + 4])
        guard let value = UInt32(String(hex), radix: 16) else { return nil }
        i += 4
        return value
    }

    private mutating func parseNumber() -> JSONValue? {
        let start = i
        while i < s.count, "-+.eE0123456789".unicodeScalars.contains(s[i]) { i += 1 }
        var raw = String.UnicodeScalarView()
        raw.append(contentsOf: s[start..<i])
        let text = String(raw)
        guard text.range(of: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#, options: .regularExpression) != nil else {
            return nil
        }
        return .number(text)
    }
}
