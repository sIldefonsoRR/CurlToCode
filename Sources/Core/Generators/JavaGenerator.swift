import Foundation

/// Java 15+ using `java.net.http.HttpClient`.
enum JavaGenerator {
    /// Headers java.net.http refuses to set.
    private static let restrictedHeaders: Set<String> = ["host", "connection", "content-length", "expect", "upgrade"]

    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.java
        var notes = r.notes
        var imports: Set<String> = ["java.net.URI", "java.net.http.HttpClient", "java.net.http.HttpRequest", "java.net.http.HttpResponse"]
        let ind = "        "
        var body: [String] = []

        // Client
        var clientOptions: [String] = []
        if let proxy = r.proxy, let comps = URLComponents(string: proxy), let host = comps.host {
            imports.formUnion(["java.net.InetSocketAddress", "java.net.ProxySelector"])
            clientOptions.append(".proxy(ProxySelector.of(new InetSocketAddress(\(str(host)), \(comps.port ?? 1080))))")
        }
        if let timeout = r.timeout {
            imports.insert("java.time.Duration")
            clientOptions.append(".connectTimeout(Duration.ofMillis(\(Int(timeout * 1000))))")
        }
        if r.insecure {
            notes.append("-k/--insecure not applied; java.net.http needs a custom SSLContext to skip certificate checks.")
        }
        if clientOptions.isEmpty {
            body.append("HttpClient client = HttpClient.newHttpClient();")
        } else {
            body.append("HttpClient client = HttpClient.newBuilder()")
            body += clientOptions.map { "    \($0)" }
            body.append("    .build();")
        }
        body.append("")

        // Body publisher
        var publisher: String?
        switch r.body {
        case .none:
            break
        case .json(let value):
            publisher = "HttpRequest.BodyPublishers.ofString(\(textBlock(Literals.jsonText(value), indent: ind + "    ")))"
        case .form(_, let encoded):
            publisher = "HttpRequest.BodyPublishers.ofString(\(str(encoded)))"
        case .raw(let text):
            publisher = "HttpRequest.BodyPublishers.ofString(\(str(text)))"
        case .file(let path):
            imports.insert("java.nio.file.Path")
            publisher = "HttpRequest.BodyPublishers.ofFile(Path.of(\(str(path))))"
        }
        if !r.formFields.isEmpty {
            notes.append("Multipart form data (-F) is not built into java.net.http; use a library such as OkHttp or Apache HttpClient.")
        }

        // Request
        var builder = ["HttpRequest request = HttpRequest.newBuilder()", "    .uri(URI.create(\(str(r.url))))"]
        for (name, value) in r.explicitHeaders {
            if restrictedHeaders.contains(name.lowercased()) {
                notes.append("Header \(name) removed; java.net.http does not allow setting it.")
                continue
            }
            builder.append("    .header(\(str(name)), \(str(value)))")
        }
        if let auth = r.auth {
            imports.insert("java.util.Base64")
            builder.append("    .header(\"Authorization\", \"Basic \" + Base64.getEncoder().encodeToString(\(str("\(auth.user):\(auth.password)")).getBytes()))")
        }
        switch (r.method, publisher) {
        case ("GET", nil): break
        case ("DELETE", nil): builder.append("    .DELETE()")
        case ("POST", let p?): builder.append("    .POST(\(p))")
        case ("PUT", let p?): builder.append("    .PUT(\(p))")
        case (let m, let p): builder.append("    .method(\(str(m)), \(p ?? "HttpRequest.BodyPublishers.noBody()"))")
        }
        if let timeout = r.timeout {
            builder.append("    .timeout(Duration.ofMillis(\(Int(timeout * 1000))))")
        }
        builder.append("    .build();")
        body += builder
        body.append("")
        body.append("HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());")
        if options.includePrint {
            body.append("System.out.println(response.statusCode());")
            body.append("System.out.println(response.body());")
        }

        var out = CodeGenerator.noteComments(notes, prefix: "//")
        out += imports.sorted().map { "import \($0);" }.joined(separator: "\n") + "\n\n"
        out += "public class Main {\n"
        out += "    public static void main(String[] args) throws Exception {\n"
        out += body.map { $0.isEmpty ? "" : ind + $0 }.joined(separator: "\n") + "\n"
        out += "    }\n}\n"
        return out
    }

    /// Java text block. Backslashes and \"\"\" must be escaped inside it.
    private static func textBlock(_ text: String, indent: String) -> String {
        guard !Literals.hasControl(text.replacingOccurrences(of: "\n", with: "")) else { return Literals.java(text) }
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"\"\"", with: "\\\"\"\"")
        return "\"\"\"\n" + Literals.indent(escaped, indent) + "\"\"\""
    }
}
