import Foundation

/// Why a command couldn't be parsed; the descriptions are shown in the app's status bar.
enum CurlParseError: LocalizedError {
    case empty
    case notCurl(String)
    case missingValue(String)
    case noURL

    var errorDescription: String? {
        switch self {
        case .empty: return "Paste a cURL command to convert."
        case .notCurl(let first): return "Command must start with \"curl\" (found \"\(first)\")."
        case .missingValue(let flag): return "Option \(flag) needs a value."
        case .noURL: return "No URL found in the cURL command."
        }
    }
}

/// A curl command as written: options collected verbatim, before any interpretation.
/// `ResolvedRequest.resolve` turns it into the request that is actually sent.
struct CurlRequest {
    /// Which option supplied a body part: -d/--data-ascii, --data-raw (and --json),
    /// --data-binary or --data-urlencode. Decides whether a leading @ reads a file.
    enum DataKind { case normal, raw, binary, urlencode }

    struct DataPart {
        var kind: DataKind
        var value: String
    }

    struct FormPart {
        var name: String
        var value: String
        /// --form-string: never treat a leading @ or < as a file reference
        var literal: Bool
    }

    var url = ""
    var method: String?
    var headers: [(String, String)] = []
    var dataParts: [DataPart] = []
    var isJSON = false
    var formParts: [FormPart] = []
    var user: String?
    var cookie: String?
    var insecure = false
    var head = false
    var forceGet = false
    var proxy: String?
    var timeout: String?
    /// Options that were ignored or couldn't be handled; surfaced as `Note:` comments.
    var warnings: [String] = []
}

/// Parses a curl command line (as copied from a terminal or browser) into a `CurlRequest`.
enum CurlParser {
    /// Long options that consume a value. Ones we don't translate are still listed
    /// so that their value isn't mistaken for the URL.
    private static let valueOptions: Set<String> = [
        "request", "header", "data", "data-raw", "data-binary", "data-ascii", "data-urlencode",
        "json", "form", "form-string", "user", "cookie", "user-agent", "referer", "proxy",
        "max-time", "connect-timeout", "url", "oauth2-bearer",
        "output", "write-out", "cookie-jar", "upload-file", "cert", "key", "cacert", "capath",
        "config", "range", "retry", "retry-delay", "retry-max-time", "resolve", "interface",
        "limit-rate", "proxy-user", "continue-at", "speed-limit", "speed-time", "time-cond",
        "max-redirs", "max-filesize", "dns-servers", "connect-to", "local-port", "trace",
        "trace-ascii", "stderr", "cert-type", "key-type", "pass", "ciphers", "aws-sigv4",
        "unix-socket", "abstract-unix-socket", "request-target", "variable", "expect100-timeout",
    ]

    private static let shortOptions: [Character: String] = [
        "X": "request", "H": "header", "d": "data", "F": "form", "u": "user", "b": "cookie",
        "A": "user-agent", "e": "referer", "x": "proxy", "m": "max-time", "o": "output",
        "w": "write-out", "T": "upload-file", "c": "cookie-jar", "K": "config", "E": "cert",
        "r": "range", "U": "proxy-user", "C": "continue-at", "y": "speed-time", "Y": "speed-limit",
        "z": "time-cond",
        "k": "insecure", "L": "location", "I": "head", "G": "get", "s": "silent", "S": "show-error",
        "v": "verbose", "i": "include", "f": "fail", "N": "no-buffer", "g": "globoff",
        "0": "http1.0", "4": "ipv4", "6": "ipv6", "O": "remote-name", "J": "remote-header-name",
        "q": "disable", "#": "progress-bar", "Z": "parallel", "l": "list-only", "n": "netrc",
        "j": "junk-session-cookies", "R": "remote-time", "B": "use-ascii", "p": "proxytunnel",
    ]

    /// Flags with no effect on the generated request — dropped silently.
    private static let ignoredFlags: Set<String> = [
        "location", "silent", "show-error", "verbose", "include", "fail", "no-buffer", "globoff",
        "compressed", "http1.0", "http1.1", "http2", "http2-prior-knowledge", "http3", "ipv4", "ipv6",
        "progress-bar", "no-progress-meter", "output", "write-out", "remote-name", "remote-header-name",
        "disable", "location-trusted", "fail-with-body", "no-keepalive", "tcp-nodelay", "path-as-is",
        "max-redirs", "retry", "retry-delay", "retry-max-time", "stderr", "trace", "trace-ascii",
    ]

    /// Tokenizes `input` with shell rules and collects curl's options.
    /// Accepts a leading `$ ` prompt and `curl`, `curl.exe` or a path ending in `/curl`.
    static func parse(_ input: String) throws -> CurlRequest {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("$ ") { text.removeFirst(2) }
        guard !text.isEmpty else { throw CurlParseError.empty }

        let tokens = try ShellTokenizer.tokenize(text)
        guard let first = tokens.first else { throw CurlParseError.empty }
        guard first == "curl" || first == "curl.exe" || first.hasSuffix("/curl") else {
            throw CurlParseError.notCurl(first)
        }

        var req = CurlRequest()
        var i = 1
        var onlyURLs = false

        func nextValue(_ flag: String) throws -> String {
            i += 1
            guard i < tokens.count else { throw CurlParseError.missingValue(flag) }
            return tokens[i]
        }

        while i < tokens.count {
            let token = tokens[i]

            if onlyURLs || !token.hasPrefix("-") || token == "-" {
                setURL(token, &req)
            } else if token == "--" {
                onlyURLs = true
            } else if token.hasPrefix("--") {
                var name = String(token.dropFirst(2))
                var inline: String?
                if let eq = name.firstIndex(of: "=") {
                    inline = String(name[name.index(after: eq)...])
                    name = String(name[..<eq])
                }
                if valueOptions.contains(name) {
                    let value = try inline ?? nextValue(token)
                    apply(name, value, &req)
                } else {
                    applyFlag(name, &req)
                }
            } else {
                // Short options, possibly combined: -sSL, -XPOST, -H'Accept: x'
                let chars = Array(token.dropFirst())
                var j = 0
                while j < chars.count {
                    let f = chars[j]
                    guard let name = shortOptions[f] else {
                        req.warnings.append("Unknown option -\(f) ignored.")
                        j += 1
                        continue
                    }
                    if valueOptions.contains(name) {
                        let rest = String(chars[(j + 1)...])
                        let value = try rest.isEmpty ? nextValue("-\(f)") : rest
                        apply(name, value, &req)
                        break
                    }
                    applyFlag(name, &req)
                    j += 1
                }
            }
            i += 1
        }

        guard !req.url.isEmpty else { throw CurlParseError.noURL }
        return req
    }

    private static func setURL(_ value: String, _ req: inout CurlRequest) {
        if req.url.isEmpty {
            req.url = value
        } else {
            req.warnings.append("Extra URL \(value) ignored; only the first URL is converted.")
        }
    }

    private static func apply(_ name: String, _ value: String, _ req: inout CurlRequest) {
        switch name {
        case "request":
            req.method = value.uppercased()
        case "header":
            if let colon = value.firstIndex(of: ":") {
                let key = value[..<colon].trimmingCharacters(in: .whitespaces)
                let val = value[value.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if !key.isEmpty { req.headers.append((key, val)) }
            } else if value.hasSuffix(";") {
                req.headers.append((String(value.dropLast()).trimmingCharacters(in: .whitespaces), ""))
            } else {
                req.warnings.append("Header \"\(value)\" has no ':' and was ignored.")
            }
        case "data", "data-ascii":
            req.dataParts.append(.init(kind: .normal, value: value))
        case "data-raw":
            req.dataParts.append(.init(kind: .raw, value: value))
        case "data-binary":
            req.dataParts.append(.init(kind: .binary, value: value))
        case "data-urlencode":
            req.dataParts.append(.init(kind: .urlencode, value: value))
        case "json":
            req.isJSON = true
            req.dataParts.append(.init(kind: value.hasPrefix("@") ? .binary : .raw, value: value))
        case "form", "form-string":
            if let eq = value.firstIndex(of: "=") {
                req.formParts.append(.init(
                    name: String(value[..<eq]),
                    value: String(value[value.index(after: eq)...]),
                    literal: name == "form-string"
                ))
            } else {
                req.warnings.append("Form field \"\(value)\" has no '=' and was ignored.")
            }
        case "user":
            req.user = value
        case "cookie":
            req.cookie = value
        case "user-agent":
            req.headers.append(("User-Agent", value))
        case "referer":
            req.headers.append(("Referer", value))
        case "oauth2-bearer":
            req.headers.append(("Authorization", "Bearer \(value)"))
        case "proxy":
            req.proxy = value
        case "max-time":
            req.timeout = value
        case "connect-timeout":
            if req.timeout == nil { req.timeout = value }
        case "url":
            setURL(value, &req)
        default:
            if !ignoredFlags.contains(name) {
                req.warnings.append("Option --\(name) is not supported and was ignored.")
            }
        }
    }

    private static func applyFlag(_ name: String, _ req: inout CurlRequest) {
        switch name {
        case "insecure": req.insecure = true
        case "head": req.head = true
        case "get": req.forceGet = true
        default:
            if !ignoredFlags.contains(name) && !name.hasPrefix("no-") {
                req.warnings.append("Option --\(name) is not supported and was ignored.")
            }
        }
    }
}
