import Foundation

/// PHP using the curl extension.
enum PHPGenerator {
    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.php
        var lines: [String] = []
        func opt(_ name: String, _ value: String) { lines.append("curl_setopt($ch, CURLOPT_\(name), \(value));") }

        lines.append("$ch = curl_init();")
        opt("URL", str(r.url))
        opt("RETURNTRANSFER", "true")

        if r.method == "HEAD" {
            opt("NOBODY", "true")
        } else if r.method != "GET" && !(r.method == "POST" && r.hasBody) {
            opt("CUSTOMREQUEST", str(r.method))
        }

        if !r.headers.isEmpty {
            let items = r.headers.map { "    " + str("\($0.0): \($0.1)") + "," }
            opt("HTTPHEADER", "[\n" + items.joined(separator: "\n") + "\n]")
        }
        if let cookie = r.cookieHeader { opt("COOKIE", str(cookie)) }
        if let auth = r.auth { opt("USERPWD", str("\(auth.user):\(auth.password)")) }

        switch r.body {
        case .none:
            break
        case .json(let value):
            let json = Literals.jsonText(value)
            if json.split(separator: "\n").contains(where: { $0.trimmingCharacters(in: .whitespaces) == "JSON" }) {
                opt("POSTFIELDS", str(json))
            } else {
                opt("POSTFIELDS", "<<<'JSON'\n\(json)\nJSON")
            }
        case .form(let pairs, let encoded):
            let keys = pairs.map { $0.0 }
            if Set(keys).count == keys.count {
                let items = pairs.map { "    \(str($0.0)) => \(str($0.1))," }
                opt("POSTFIELDS", "http_build_query([\n" + items.joined(separator: "\n") + "\n])")
            } else {
                opt("POSTFIELDS", str(encoded))
            }
        case .raw(let text):
            opt("POSTFIELDS", str(text))
        case .file(let path):
            opt("POSTFIELDS", "file_get_contents(\(str(path)))")
        }

        if !r.formFields.isEmpty {
            let items = r.formFields.map { field -> String in
                switch field {
                case .text(let name, let value): return "    \(str(name)) => \(str(value)),"
                case .file(let name, let path): return "    \(str(name)) => new CURLFile(\(str(path))),"
                case .fileContents(let name, let path): return "    \(str(name)) => file_get_contents(\(str(path))),"
                }
            }
            opt("POSTFIELDS", "[\n" + items.joined(separator: "\n") + "\n]")
        }

        if let proxy = r.proxy { opt("PROXY", str(proxy)) }
        if let timeout = r.timeout { opt("TIMEOUT_MS", String(Int(timeout * 1000))) }
        if r.insecure {
            opt("SSL_VERIFYPEER", "false")
            opt("SSL_VERIFYHOST", "0")
        }

        lines.append("")
        lines.append("$response = curl_exec($ch);")
        lines.append("if ($response === false) {")
        lines.append("    die(curl_error($ch));")
        lines.append("}")
        if options.includePrint {
            lines.append("echo curl_getinfo($ch, CURLINFO_HTTP_CODE) . PHP_EOL;")
            lines.append("echo $response . PHP_EOL;")
        }
        lines.append("curl_close($ch);")

        return "<?php\n\n" + CodeGenerator.noteComments(r.notes, prefix: "//")
            + lines.joined(separator: "\n") + "\n"
    }
}
