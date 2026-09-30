import Foundation

/// Rust using `reqwest`'s blocking client.
enum RustGenerator {
    private static let builderMethods: Set<String> = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"]

    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.rust
        var features = ["blocking"]
        var lines: [String] = []

        // Client
        var clientOptions: [String] = []
        if r.insecure { clientOptions.append(".danger_accept_invalid_certs(true)") }
        if let proxy = r.proxy { clientOptions.append(".proxy(reqwest::Proxy::all(\(str(proxy)))?)") }
        if let timeout = r.timeout { clientOptions.append(".timeout(\(duration(timeout)))") }
        if clientOptions.isEmpty {
            lines.append("let client = reqwest::blocking::Client::new();")
        } else {
            lines.append("let client = reqwest::blocking::Client::builder()")
            lines += clientOptions.map { "    \($0)" }
            lines.append("    .build()?;")
        }

        // Multipart form
        if !r.formFields.isEmpty {
            features.append("multipart")
            var form = ["let form = reqwest::blocking::multipart::Form::new()"]
            for field in r.formFields {
                switch field {
                case .text(let name, let value):
                    form.append("    .text(\(str(name)), \(str(value)))")
                case .file(let name, let path):
                    form.append("    .file(\(str(name)), \(str(path)))?")
                case .fileContents(let name, let path):
                    form.append("    .text(\(str(name)), std::fs::read_to_string(\(str(path)))?)")
                }
            }
            form[form.count - 1] += ";"
            lines.append("")
            lines += form
        }

        // Request
        lines.append("")
        var chain = ["let response = client"]
        if builderMethods.contains(r.method) {
            chain.append("    .\(r.method.lowercased())(\(str(r.url)))")
        } else if r.method == "OPTIONS" {
            chain.append("    .request(reqwest::Method::OPTIONS, \(str(r.url)))")
        } else {
            chain.append("    .request(reqwest::Method::from_bytes(b\(str(r.method)))?, \(str(r.url)))")
        }
        for (name, value) in r.explicitHeaders {
            chain.append("    .header(\(str(name)), \(str(value)))")
        }
        if let auth = r.auth {
            chain.append("    .basic_auth(\(str(auth.user)), Some(\(str(auth.password))))")
        }
        switch r.body {
        case .none: break
        case .json(let value): chain.append("    .body(\(rawString(Literals.jsonText(value), indent: "    ")))")
        case .form(_, let encoded): chain.append("    .body(\(str(encoded)))")
        case .raw(let text): chain.append("    .body(\(str(text)))")
        case .file(let path): chain.append("    .body(std::fs::read(\(str(path)))?)")
        }
        if !r.formFields.isEmpty { chain.append("    .multipart(form)") }
        chain.append("    .send()?;")
        lines += chain

        if options.includePrint {
            lines.append("")
            lines.append("println!(\"{}\", response.status());")
            lines.append("println!(\"{}\", response.text()?);")
        } else {
            lines[lines.count - chain.count] = "let _response = client"
        }
        lines.append("Ok(())")

        let featureList = features.map { "\"\($0)\"" }.joined(separator: ", ")
        var out = CodeGenerator.noteComments(r.notes, prefix: "//")
        out += "// Cargo.toml:\n// [dependencies]\n// reqwest = { version = \"0.12\", features = [\(featureList)] }\n\n"
        out += "fn main() -> Result<(), Box<dyn std::error::Error>> {\n"
        out += lines.map { $0.isEmpty ? "" : "    " + $0 }.joined(separator: "\n") + "\n}\n"
        return out
    }

    private static func duration(_ seconds: Double) -> String {
        seconds == seconds.rounded()
            ? "std::time::Duration::from_secs(\(Int(seconds)))"
            : "std::time::Duration::from_secs_f64(\(seconds))"
    }

    /// r#"..."# raw string with enough #s to not clash with the content.
    private static func rawString(_ text: String, indent: String) -> String {
        var hashes = "#"
        while text.contains("\"" + hashes) { hashes += "#" }
        let body = Literals.indent(text, indent + "    ")
        return "r\(hashes)\"\n\(body)\n\(indent)\"\(hashes)"
    }
}
