import Foundation

/// Swift using Foundation's `URLSession` (async/await, as a main.swift script).
enum SwiftGenerator {
    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.swift
        var notes = r.notes
        var lines: [String] = []

        lines.append("var request = URLRequest(url: URL(string: \(str(r.url)))!)")
        if r.method != "GET" { lines.append("request.httpMethod = \(str(r.method))") }
        for (name, value) in r.explicitHeaders {
            lines.append("request.setValue(\(str(value)), forHTTPHeaderField: \(str(name)))")
        }
        if let auth = r.auth {
            lines.append("request.setValue(\"Basic \" + Data(\(str("\(auth.user):\(auth.password)")).utf8).base64EncodedString(), forHTTPHeaderField: \"Authorization\")")
        }

        switch r.body {
        case .none:
            break
        case .json(let value):
            lines.append("request.httpBody = Data(\(multiline(Literals.jsonText(value))).utf8)")
        case .form(_, let encoded):
            lines.append("request.httpBody = Data(\(str(encoded)).utf8)")
        case .raw(let text):
            lines.append("request.httpBody = Data(\(str(text)).utf8)")
        case .file(let path):
            lines.append("request.httpBody = try Data(contentsOf: URL(fileURLWithPath: \(str(path))))")
        }

        if !r.formFields.isEmpty {
            lines.append("")
            lines.append("let boundary = \"Boundary-\\(UUID().uuidString)\"")
            lines.append("request.setValue(\"multipart/form-data; boundary=\\(boundary)\", forHTTPHeaderField: \"Content-Type\")")
            lines.append("var body = Data()")
            for field in r.formFields {
                switch field {
                case .text(let name, let value):
                    lines.append("body.append(Data(\"--\\(boundary)\\r\\nContent-Disposition: form-data; name=\\\"\(escapedHeaderValue(name))\\\"\\r\\n\\r\\n\".utf8))")
                    lines.append("body.append(Data(\(str(value)).utf8))")
                case .file(let name, let path):
                    let file = escapedHeaderValue(ResolvedRequest.fileName(path))
                    lines.append("body.append(Data(\"--\\(boundary)\\r\\nContent-Disposition: form-data; name=\\\"\(escapedHeaderValue(name))\\\"; filename=\\\"\(file)\\\"\\r\\nContent-Type: application/octet-stream\\r\\n\\r\\n\".utf8))")
                    lines.append("body.append(try Data(contentsOf: URL(fileURLWithPath: \(str(path)))))")
                case .fileContents(let name, let path):
                    lines.append("body.append(Data(\"--\\(boundary)\\r\\nContent-Disposition: form-data; name=\\\"\(escapedHeaderValue(name))\\\"\\r\\n\\r\\n\".utf8))")
                    lines.append("body.append(try Data(contentsOf: URL(fileURLWithPath: \(str(path)))))")
                }
                lines.append("body.append(Data(\"\\r\\n\".utf8))")
            }
            lines.append("body.append(Data(\"--\\(boundary)--\\r\\n\".utf8))")
            lines.append("request.httpBody = body")
        }

        if let timeout = r.timeout { lines.append("request.timeoutInterval = \(Literals.number(timeout))") }
        if r.insecure {
            notes.append("-k/--insecure not applied; URLSession needs a URLSessionDelegate to accept invalid certificates.")
        }
        if let proxy = r.proxy {
            notes.append("Proxy \(proxy) not applied; set connectionProxyDictionary on a URLSessionConfiguration.")
        }

        lines.append("")
        if options.includePrint {
            lines.append("let (data, response) = try await URLSession.shared.data(for: request)")
            lines.append("print((response as! HTTPURLResponse).statusCode)")
            lines.append("print(String(decoding: data, as: UTF8.self))")
        } else {
            lines.append("let (_, _) = try await URLSession.shared.data(for: request)")
        }

        return CodeGenerator.noteComments(notes, prefix: "//")
            + "import Foundation\n\n" + lines.joined(separator: "\n") + "\n"
    }

    /// Text safe inside a Swift string literal and a quoted multipart header value.
    private static func escapedHeaderValue(_ s: String) -> String {
        let inner = Literals.swift(s.replacingOccurrences(of: "\"", with: "%22"))
        return String(inner.dropFirst().dropLast())
    }

    /// Multi-line raw string `#""" ... """#` (escaped single-line string if the text clashes).
    private static func multiline(_ text: String) -> String {
        guard !text.contains("\"\"\"#") else { return Literals.swift(text) }
        return "#\"\"\"\n" + Literals.indent(text, "    ") + "\n    \"\"\"#"
    }
}
