import Foundation

/// Go using the standard library's `net/http`.
enum GoGenerator {
    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.go
        var imports: Set<String> = ["net/http"]
        var lines: [String] = []
        let check = ["if err != nil {", "\tpanic(err)", "}"]
        var bodyVar = "nil"
        var multipartWriter = false

        switch r.body {
        case .none:
            break
        case .json(let value):
            imports.insert("strings")
            lines.append("body := strings.NewReader(\(goString(Literals.jsonText(value))))")
            bodyVar = "body"
        case .form(_, let encoded):
            imports.insert("strings")
            lines.append("body := strings.NewReader(\(str(encoded)))")
            bodyVar = "body"
        case .raw(let text):
            imports.insert("strings")
            lines.append("body := strings.NewReader(\(str(text)))")
            bodyVar = "body"
        case .file(let path):
            imports.insert("os")
            lines.append("body, err := os.Open(\(str(path)))")
            lines += check
            lines.append("defer body.Close()")
            bodyVar = "body"
        }

        if !r.formFields.isEmpty {
            imports.formUnion(["bytes", "mime/multipart"])
            multipartWriter = true
            lines.append("body := &bytes.Buffer{}")
            lines.append("writer := multipart.NewWriter(body)")
            for field in r.formFields {
                switch field {
                case .text(let name, let value):
                    lines.append("if err := writer.WriteField(\(str(name)), \(str(value))); err != nil {")
                    lines += ["\tpanic(err)", "}"]
                case .file(let name, let path):
                    imports.formUnion(["io", "os"])
                    lines.append("{")
                    lines.append("\tfile, err := os.Open(\(str(path)))")
                    lines += check.map { "\t" + $0 }
                    lines.append("\tpart, err := writer.CreateFormFile(\(str(name)), \(str(ResolvedRequest.fileName(path))))")
                    lines += check.map { "\t" + $0 }
                    lines.append("\tif _, err := io.Copy(part, file); err != nil {")
                    lines += ["\t\tpanic(err)", "\t}"]
                    lines.append("\tfile.Close()")
                    lines.append("}")
                case .fileContents(let name, let path):
                    imports.insert("os")
                    lines.append("{")
                    lines.append("\tdata, err := os.ReadFile(\(str(path)))")
                    lines += check.map { "\t" + $0 }
                    lines.append("\tif err := writer.WriteField(\(str(name)), string(data)); err != nil {")
                    lines += ["\t\tpanic(err)", "\t}"]
                    lines.append("}")
                }
            }
            lines.append("if err := writer.Close(); err != nil {")
            lines += ["\tpanic(err)", "}"]
            bodyVar = "body"
        }

        if !lines.isEmpty { lines.append("") }
        lines.append("req, err := http.NewRequest(\(str(r.method)), \(str(r.url)), \(bodyVar))")
        lines += check
        for (name, value) in r.explicitHeaders {
            if name.lowercased() == "host" {
                lines.append("req.Host = \(str(value))")
            } else {
                lines.append("req.Header.Set(\(str(name)), \(str(value)))")
            }
        }
        if multipartWriter {
            lines.append("req.Header.Set(\"Content-Type\", writer.FormDataContentType())")
        }
        if let auth = r.auth {
            lines.append("req.SetBasicAuth(\(str(auth.user)), \(str(auth.password)))")
        }

        // Client
        lines.append("")
        var transport: [(String, String)] = []
        if let proxy = r.proxy {
            imports.insert("net/url")
            lines.append("proxyURL, err := url.Parse(\(str(proxy)))")
            lines += check
            transport.append(("Proxy", "http.ProxyURL(proxyURL)"))
        }
        if r.insecure {
            imports.insert("crypto/tls")
            transport.append(("TLSClientConfig", "&tls.Config{InsecureSkipVerify: true}"))
        }
        var clientFields: [(String, String)] = []
        if let timeout = r.timeout {
            imports.insert("time")
            let value = timeout == timeout.rounded()
                ? "\(Int(timeout)) * time.Second"
                : "time.Duration(\(timeout) * float64(time.Second))"
            clientFields.append(("Timeout", value))
        }
        if !transport.isEmpty {
            clientFields.append(("Transport", "&http.Transport{\n" + aligned(transport, indent: "\t\t") + "\n\t}"))
        }
        if clientFields.isEmpty {
            lines.append("client := &http.Client{}")
        } else {
            lines.append("client := &http.Client{")
            lines.append(aligned(clientFields, indent: "\t"))
            lines.append("}")
        }
        lines.append("resp, err := client.Do(req)")
        lines += check
        lines.append("defer resp.Body.Close()")

        if options.includePrint {
            imports.formUnion(["fmt", "io"])
            lines.append("")
            lines.append("respBody, err := io.ReadAll(resp.Body)")
            lines += check
            lines.append("fmt.Println(resp.StatusCode)")
            lines.append("fmt.Println(string(respBody))")
        }

        var out = CodeGenerator.noteComments(r.notes, prefix: "//")
        out += "package main\n\nimport (\n"
        out += imports.sorted().map { "\t\"\($0)\"" }.joined(separator: "\n")
        out += "\n)\n\nfunc main() {\n"
        out += lines.map { $0.isEmpty ? "" : Literals.indent($0, "\t") }.joined(separator: "\n")
        out += "\n}\n"
        return out
    }

    /// Raw `backtick` string when possible, otherwise an interpreted string.
    /// Only used for JSON, where the indentation added inside it is insignificant.
    private static func goString(_ text: String) -> String {
        if text.contains("\n") && !text.contains("`") && !text.contains("\r") { return "`" + text + "`" }
        return Literals.go(text)
    }

    /// gofmt-style aligned `Key: value,` lines for a composite literal.
    private static func aligned(_ fields: [(String, String)], indent: String) -> String {
        let width = fields.map { $0.0.count }.max() ?? 0
        return fields.map { key, value in
            indent + key + ":" + String(repeating: " ", count: width - key.count + 1) + value + ","
        }.joined(separator: "\n")
    }
}
