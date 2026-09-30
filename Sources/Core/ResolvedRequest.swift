import Foundation

/// Language-neutral description of the HTTP request a curl command performs.
/// Every language generator is built on top of this.
struct ResolvedRequest {
    enum Body {
        case none
        case json(JSONValue)
        /// Decoded pairs plus the URL-encoded body string curl would send.
        case form([(String, String)], encoded: String)
        case raw(String)
        case file(String)
    }

    enum FormField {
        case text(name: String, value: String)
        /// Upload a file (`-F name=@path`).
        case file(name: String, path: String)
        /// Send a file's contents as a text field (`-F name=<path`).
        case fileContents(name: String, path: String)
    }

    var method = "GET"
    /// Scheme-qualified URL without fragment, including the query string.
    var originalURL = ""
    /// `originalURL` minus the query string, and that query string decoded (nil when it can't be decoded).
    var baseURL = ""
    var queryPairs: [(String, String)]?
    /// Data moved into the query string by `-G`.
    var getPairs: [(String, String)] = []

    /// Headers as given, minus Cookie (see `cookies`) and headers the HTTP libraries compute themselves.
    var headers: [(String, String)] = []
    var cookies: [(String, String)] = []
    var body = Body.none
    var formFields: [FormField] = []
    var auth: (user: String, password: String)?
    var proxy: String?
    var timeout: Double?
    var insecure = false
    var notes: [String] = []

    var hasBody: Bool {
        if case .none = body { return !formFields.isEmpty }
        return true
    }

    /// Full URL to request, with `-G` data appended to the query string.
    var url: String {
        guard !getPairs.isEmpty else { return originalURL }
        let separator = originalURL.contains("?") ? "&" : "?"
        return originalURL + separator + Self.encodeForm(getPairs)
    }

    /// URL and query parameters for libraries that take a params mapping.
    func urlAndParams(split: Bool) -> (String, [(String, String)]) {
        if split, let pairs = queryPairs { return (baseURL, pairs + getPairs) }
        return (originalURL, getPairs)
    }

    func header(_ name: String) -> String? {
        headers.last { $0.0.lowercased() == name.lowercased() }?.1
    }

    var cookieHeader: String? {
        cookies.isEmpty ? nil : cookies.map { "\($0.0)=\($0.1)" }.joined(separator: "; ")
    }

    /// Headers for clients that send exactly what they're told: cookies are merged
    /// back in, and curl's implicit form Content-Type is made explicit.
    var explicitHeaders: [(String, String)] {
        var result = headers
        if let cookie = cookieHeader { result.append(("Cookie", cookie)) }
        if header("content-type") == nil, formFields.isEmpty {
            switch body {
            case .none, .json: break
            case .form, .raw, .file: result.append(("Content-Type", "application/x-www-form-urlencoded"))
            }
        }
        return result
    }

    var basicAuthToken: String? {
        guard let auth else { return nil }
        return Data("\(auth.user):\(auth.password)".utf8).base64EncodedString()
    }

    /// Filename part of a path, as used for multipart uploads.
    static func fileName(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

    private static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func percentEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s
    }

    static func encodeForm(_ pairs: [(String, String)]) -> String {
        pairs.map { "\(percentEncode($0.0))=\(percentEncode($0.1))" }.joined(separator: "&")
    }
}

extension ResolvedRequest {
    /// Headers that every client library sets itself; copying them causes bugs
    /// (wrong lengths, compressed responses that aren't decoded).
    private static let droppedHeaders: Set<String> = ["content-length", "accept-encoding"]

    /// Interprets curl's options the way curl would: default scheme, method inference,
    /// body classification (JSON / form / raw / file), -G query data, cookies and auth.
    static func resolve(_ req: CurlRequest) -> ResolvedRequest {
        var r = ResolvedRequest()
        r.notes = req.warnings

        // URL
        var url = req.url
        if !url.contains("://") { url = "http://" + url }
        if let hash = url.firstIndex(of: "#") { url = String(url[..<hash]) }
        r.originalURL = url
        r.baseURL = url
        if let q = url.firstIndex(of: "?") {
            if let pairs = parseForm(String(url[url.index(after: q)...])) {
                r.baseURL = String(url[..<q])
                r.queryPairs = pairs
            }
        }

        // Headers and cookies
        for (name, value) in req.headers {
            let lower = name.lowercased()
            if lower == "cookie", let parsed = parseCookies(value) {
                r.cookies += parsed
            } else if droppedHeaders.contains(lower) {
                r.notes.append("Header \(name) removed; the HTTP library sets it automatically.")
            } else if lower == "content-type" && value.lowercased().hasPrefix("multipart/") && !req.formParts.isEmpty {
                r.notes.append("Content-Type multipart header removed; the library adds it with the right boundary.")
            } else {
                r.headers.append((name, value))
            }
        }
        if let cookie = req.cookie {
            if let parsed = parseCookies(cookie) {
                r.cookies += parsed
            } else {
                r.notes.append("Cookie file \"\(cookie)\" ignored.")
            }
        }
        if req.isJSON {
            if r.header("content-type") == nil { r.headers.append(("Content-Type", "application/json")) }
            if r.header("accept") == nil { r.headers.append(("Accept", "application/json")) }
        }

        // Body
        var pieces: [String] = []
        var fileRef: String?
        for part in req.dataParts {
            switch part.kind {
            case .raw:
                pieces.append(part.value)
            case .normal, .binary:
                if part.value.hasPrefix("@") {
                    if fileRef == nil && req.dataParts.count == 1 {
                        fileRef = String(part.value.dropFirst())
                    } else {
                        r.notes.append("Data file \(part.value) combined with other data is not supported; it was ignored.")
                    }
                } else {
                    pieces.append(part.value)
                }
            case .urlencode:
                pieces.append(urlencodeData(part.value, notes: &r.notes))
            }
        }
        let bodyText = pieces.joined(separator: "&")

        if req.forceGet {
            for piece in pieces {
                if let pairs = parseForm(piece) {
                    r.getPairs += pairs
                } else {
                    r.getPairs.append((piece, ""))
                }
            }
            if let file = fileRef { r.notes.append("Data file @\(file) ignored with -G.") }
        } else if let file = fileRef {
            r.body = .file(file)
        } else if !req.dataParts.isEmpty {
            let contentType = r.header("content-type")?.lowercased()
            if req.isJSON || contentType?.contains("json") == true, let json = JSONParser.parse(bodyText) {
                r.body = .json(json)
            } else if contentType == nil || contentType!.contains("x-www-form-urlencoded"),
                      let form = parseForm(bodyText) {
                r.body = .form(form, encoded: bodyText)
            } else {
                r.body = .raw(bodyText)
            }
        }

        // Multipart
        for part in req.formParts {
            var value = part.value
            if !part.literal && value.hasPrefix("@") {
                value.removeFirst()
                if let semi = value.firstIndex(of: ";") { value = String(value[..<semi]) }
                r.formFields.append(.file(name: part.name, path: value))
            } else if !part.literal && value.hasPrefix("<") {
                value.removeFirst()
                r.formFields.append(.fileContents(name: part.name, path: value))
            } else {
                r.formFields.append(.text(name: part.name, value: value))
            }
        }

        // Method
        if let m = req.method {
            r.method = m
        } else if req.head {
            r.method = "HEAD"
        } else if req.forceGet {
            r.method = "GET"
        } else if !req.dataParts.isEmpty || !req.formParts.isEmpty {
            r.method = "POST"
        }

        // Options
        if let user = req.user {
            if let colon = user.firstIndex(of: ":") {
                r.auth = (String(user[..<colon]), String(user[user.index(after: colon)...]))
            } else {
                r.auth = (user, "")
                r.notes.append("No password given for -u; fill it in below.")
            }
        }
        if let proxy = req.proxy {
            r.proxy = proxy.contains("://") ? proxy : "http://" + proxy
        }
        if let timeout = req.timeout {
            if let seconds = Double(timeout) {
                r.timeout = seconds
            } else {
                r.notes.append("Timeout \"\(timeout)\" is not a number and was ignored.")
            }
        }
        r.insecure = req.insecure
        return r
    }

    /// Parses `a=1&b=2` into decoded pairs; nil if it doesn't look like form data.
    static func parseForm(_ text: String) -> [(String, String)]? {
        guard !text.isEmpty, !text.contains("\n") else { return nil }
        var pairs: [(String, String)] = []
        for piece in text.split(separator: "&", omittingEmptySubsequences: true) {
            guard let eq = piece.firstIndex(of: "=") else { return nil }
            guard let key = formDecode(String(piece[..<eq])), !key.isEmpty,
                  let value = formDecode(String(piece[piece.index(after: eq)...])) else { return nil }
            pairs.append((key, value))
        }
        return pairs.isEmpty ? nil : pairs
    }

    private static func formDecode(_ s: String) -> String? {
        s.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }

    private static func parseCookies(_ text: String) -> [(String, String)]? {
        guard text.contains("=") else { return nil }
        var pairs: [(String, String)] = []
        for piece in text.split(separator: ";") {
            let trimmed = piece.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            guard let eq = trimmed.firstIndex(of: "=") else { return nil }
            pairs.append((String(trimmed[..<eq]), String(trimmed[trimmed.index(after: eq)...])))
        }
        return pairs.isEmpty ? nil : pairs
    }

    /// Mirrors curl's --data-urlencode forms: "content", "=content", "name=content".
    private static func urlencodeData(_ value: String, notes: inout [String]) -> String {
        if let eq = value.firstIndex(of: "=") {
            let name = String(value[..<eq])
            let content = percentEncode(String(value[value.index(after: eq)...]))
            return name.isEmpty ? content : name + "=" + content
        }
        if value.contains("@") {
            notes.append("--data-urlencode file reference \"\(value)\" sent as literal text.")
        }
        return percentEncode(value)
    }
}
