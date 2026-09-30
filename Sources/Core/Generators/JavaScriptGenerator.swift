import Foundation

/// JavaScript using `fetch` (browsers and Node.js 18+, as an ES module).
enum JavaScriptGenerator {
    private static let style = Literals.Style(string: Literals.javaScript, key: key)

    private static func key(_ s: String) -> String {
        s.range(of: #"^[A-Za-z_$][A-Za-z0-9_$]*$"#, options: .regularExpression) != nil ? s : Literals.javaScript(s)
    }

    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.javaScript
        var notes = r.notes
        var preamble: [String] = []
        var props: [String] = []
        var usesFS = false

        if r.method != "GET" { props.append("method: \(str(r.method))") }

        var headers = r.explicitHeaders
        if case .form = r.body {
            // URLSearchParams sets the form Content-Type itself.
            headers.removeAll { $0.0.lowercased() == "content-type" && $0.1 == "application/x-www-form-urlencoded" }
        }
        var headerLines = headers.map { "    \(str($0.0)): \(str($0.1))," }
        if let auth = r.auth {
            headerLines.append("    'Authorization': 'Basic ' + btoa(\(str("\(auth.user):\(auth.password)"))),")
        }
        if !headerLines.isEmpty {
            props.append("headers: {\n" + headerLines.joined(separator: "\n") + "\n  }")
        }

        switch r.body {
        case .none:
            break
        case .json(let value):
            props.append("body: JSON.stringify(\(Literals.render(value, style: style, indent: 1)))")
        case .form(let pairs, _):
            let keys = pairs.map { $0.0 }
            if Set(keys).count == keys.count {
                props.append("body: new URLSearchParams({\n" + pairs.map { "    \(key($0.0)): \(str($0.1))," }.joined(separator: "\n") + "\n  })")
            } else {
                props.append("body: new URLSearchParams([\n" + pairs.map { "    [\(str($0.0)), \(str($0.1))]," }.joined(separator: "\n") + "\n  ])")
            }
        case .raw(let text):
            props.append("body: \(str(text))")
        case .file(let path):
            usesFS = true
            props.append("body: fs.readFileSync(\(str(path)))")
        }

        if !r.formFields.isEmpty {
            var lines = ["const form = new FormData();"]
            for field in r.formFields {
                switch field {
                case .text(let name, let value):
                    lines.append("form.append(\(str(name)), \(str(value)));")
                case .file(let name, let path):
                    usesFS = true
                    lines.append("form.append(\(str(name)), new Blob([fs.readFileSync(\(str(path)))]), \(str(ResolvedRequest.fileName(path))));")
                case .fileContents(let name, let path):
                    usesFS = true
                    lines.append("form.append(\(str(name)), fs.readFileSync(\(str(path)), 'utf8'));")
                }
            }
            preamble.append(lines.joined(separator: "\n"))
            props.append("body: form")
        }

        if let timeout = r.timeout {
            props.append("signal: AbortSignal.timeout(\(Int(timeout * 1000)))")
        }
        if r.insecure {
            notes.append("fetch can't skip TLS verification per request; in Node.js run with NODE_TLS_REJECT_UNAUTHORIZED=0 (unsafe).")
        }
        if let proxy = r.proxy {
            notes.append("Proxy \(proxy) not applied; in Node.js use undici's ProxyAgent as the dispatcher option.")
        }

        var out = CodeGenerator.noteComments(notes, prefix: "//")
        if usesFS { out += "import fs from 'node:fs';\n\n" }
        if !preamble.isEmpty { out += preamble.joined(separator: "\n\n") + "\n\n" }

        if props.isEmpty {
            out += "const response = await fetch(\(str(r.url)));\n"
        } else {
            out += "const response = await fetch(\(str(r.url)), {\n"
            out += props.map { "  \($0)," }.joined(separator: "\n")
            out += "\n});\n"
        }
        if options.includePrint {
            out += "\nconsole.log(response.status);\nconsole.log(await response.text());\n"
        }
        return out
    }
}
