import Foundation

enum ShellTokenizerError: LocalizedError {
    case unterminatedQuote(Character)

    var errorDescription: String? {
        switch self {
        case .unterminatedQuote(let q): return "Unterminated \(q) quote in command."
        }
    }
}

/// Splits a shell command line into arguments, following bash quoting rules:
/// single quotes, double quotes, $'ANSI-C' quotes, backslash escapes and
/// backslash-newline line continuations.
enum ShellTokenizer {
    static func tokenize(_ input: String) throws -> [String] {
        let chars = Array(input.replacingOccurrences(of: "\r\n", with: "\n"))
        var tokens: [String] = []
        var current = ""
        var inToken = false
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if c == "\\" {
                if i + 1 < chars.count {
                    let next = chars[i + 1]
                    i += 2
                    if next == "\n" { continue } // line continuation
                    current.append(next)
                    inToken = true
                } else {
                    i += 1
                }
                continue
            }

            if c == " " || c == "\t" || c == "\n" {
                if inToken {
                    tokens.append(current)
                    current = ""
                    inToken = false
                }
                i += 1
                continue
            }

            if c == "#" && !inToken {
                // Comment (e.g. a shebang or note in a loaded .sh file) runs to end of line
                while i < chars.count && chars[i] != "\n" { i += 1 }
                continue
            }

            if c == "'" {
                inToken = true
                i += 1
                while i < chars.count && chars[i] != "'" {
                    current.append(chars[i])
                    i += 1
                }
                guard i < chars.count else { throw ShellTokenizerError.unterminatedQuote("'") }
                i += 1
                continue
            }

            if c == "$" && i + 1 < chars.count && chars[i + 1] == "'" {
                inToken = true
                i += 2
                var closed = false
                while i < chars.count {
                    let d = chars[i]
                    if d == "'" {
                        closed = true
                        i += 1
                        break
                    }
                    if d == "\\" && i + 1 < chars.count {
                        i += 1
                        current.append(contentsOf: readANSIEscape(chars, &i))
                        continue
                    }
                    current.append(d)
                    i += 1
                }
                guard closed else { throw ShellTokenizerError.unterminatedQuote("'") }
                continue
            }

            if c == "\"" {
                inToken = true
                i += 1
                var closed = false
                while i < chars.count {
                    let d = chars[i]
                    if d == "\"" {
                        closed = true
                        i += 1
                        break
                    }
                    if d == "\\" && i + 1 < chars.count {
                        let e = chars[i + 1]
                        if e == "\n" {
                            i += 2
                            continue
                        }
                        if "\"\\$`".contains(e) {
                            current.append(e)
                            i += 2
                            continue
                        }
                    }
                    current.append(d)
                    i += 1
                }
                guard closed else { throw ShellTokenizerError.unterminatedQuote("\"") }
                continue
            }

            current.append(c)
            inToken = true
            i += 1
        }

        if inToken { tokens.append(current) }
        return tokens
    }

    /// Reads the escape sequence starting at `i` (just after the backslash) inside $'...'.
    private static func readANSIEscape(_ chars: [Character], _ i: inout Int) -> String {
        let e = chars[i]
        i += 1
        switch e {
        case "n": return "\n"
        case "t": return "\t"
        case "r": return "\r"
        case "a": return "\u{07}"
        case "b": return "\u{08}"
        case "e", "E": return "\u{1B}"
        case "f": return "\u{0C}"
        case "v": return "\u{0B}"
        case "\\": return "\\"
        case "'": return "'"
        case "\"": return "\""
        case "?": return "?"
        case "x": return readHexScalar(chars, &i, maxDigits: 2) ?? "\\x"
        case "u": return readHexScalar(chars, &i, maxDigits: 4) ?? "\\u"
        case "U": return readHexScalar(chars, &i, maxDigits: 8) ?? "\\U"
        default: return "\\" + String(e)
        }
    }

    private static func readHexScalar(_ chars: [Character], _ i: inout Int, maxDigits: Int) -> String? {
        var digits = ""
        while digits.count < maxDigits, i < chars.count, chars[i].isHexDigit {
            digits.append(chars[i])
            i += 1
        }
        guard let value = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(value) else { return nil }
        return String(Character(scalar))
    }
}
