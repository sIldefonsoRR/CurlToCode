import Foundation

/// Ruby using the standard library's `Net::HTTP`.
enum RubyGenerator {
    private static let methodClasses: [String: String] = [
        "GET": "Get", "POST": "Post", "PUT": "Put", "PATCH": "Patch",
        "DELETE": "Delete", "HEAD": "Head", "OPTIONS": "Options",
    ]

    private static let style = Literals.Style(
        string: Literals.ruby, key: Literals.ruby, separator: " => ", nullLiteral: "nil")

    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.ruby
        var requires = ["net/http"]
        var lines: [String] = []

        lines.append("uri = URI(\(str(r.url)))")
        if let cls = methodClasses[r.method] {
            lines.append("req = Net::HTTP::\(cls).new(uri)")
        } else {
            lines.append("req = Net::HTTPGenericRequest.new(\(str(r.method)), true, true, uri)")
        }
        for (name, value) in r.explicitHeaders {
            lines.append("req[\(str(name))] = \(str(value))")
        }
        if let auth = r.auth {
            lines.append("req.basic_auth(\(str(auth.user)), \(str(auth.password)))")
        }

        switch r.body {
        case .none:
            break
        case .json(let value):
            requires.append("json")
            lines.append("req.body = " + Literals.render(value, style: style) + ".to_json")
        case .form(let pairs, _):
            let keys = pairs.map { $0.0 }
            if Set(keys).count == keys.count {
                lines.append("req.body = URI.encode_www_form(\n" + pairs.map { "  \(str($0.0)) => \(str($0.1))," }.joined(separator: "\n") + "\n)")
            } else {
                lines.append("req.body = URI.encode_www_form([\n" + pairs.map { "  [\(str($0.0)), \(str($0.1))]," }.joined(separator: "\n") + "\n])")
            }
        case .raw(let text):
            lines.append("req.body = \(str(text))")
        case .file(let path):
            lines.append("req.body = File.binread(\(str(path)))")
        }

        if !r.formFields.isEmpty {
            let fields = r.formFields.map { field -> String in
                switch field {
                case .text(let name, let value): return "  [\(str(name)), \(str(value))],"
                case .file(let name, let path): return "  [\(str(name)), File.open(\(str(path)))],"
                case .fileContents(let name, let path): return "  [\(str(name)), File.read(\(str(path)))],"
                }
            }
            lines.append("req.set_form([\n" + fields.joined(separator: "\n") + "\n], 'multipart/form-data')")
        }

        lines.append("")
        if let proxy = r.proxy {
            lines.append("proxy = URI(\(str(proxy)))")
            lines.append("http = Net::HTTP.new(uri.hostname, uri.port, proxy.hostname, proxy.port, proxy.user, proxy.password)")
        } else {
            lines.append("http = Net::HTTP.new(uri.hostname, uri.port)")
        }
        lines.append("http.use_ssl = uri.scheme == 'https'")
        if r.insecure {
            requires.append("openssl")
            lines.append("http.verify_mode = OpenSSL::SSL::VERIFY_NONE")
        }
        if let timeout = r.timeout {
            let t = Literals.number(timeout)
            lines.append("http.open_timeout = \(t)")
            lines.append("http.read_timeout = \(t)")
        }
        lines.append("res = http.request(req)")
        if options.includePrint {
            lines.append("")
            lines.append("puts res.code")
            lines.append("puts res.body")
        }

        return CodeGenerator.noteComments(r.notes, prefix: "#")
            + requires.map { "require '\($0)'" }.joined(separator: "\n") + "\n\n"
            + lines.joined(separator: "\n") + "\n"
    }
}
