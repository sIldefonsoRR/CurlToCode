import Foundation

/// C# (.NET 6+, top-level statements) using `HttpClient`.
enum CSharpGenerator {
    private static let standardMethods: [String: String] = [
        "GET": "Get", "POST": "Post", "PUT": "Put", "PATCH": "Patch",
        "DELETE": "Delete", "HEAD": "Head", "OPTIONS": "Options",
    ]

    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.cSharp
        var usings: Set<String> = ["System", "System.Net.Http"]
        var lines: [String] = []

        // Client
        let headers = r.explicitHeaders
        let hasCookie = headers.contains { $0.0.lowercased() == "cookie" }
        var handlerProps: [String] = []
        if hasCookie { handlerProps.append("UseCookies = false,") }
        if r.insecure {
            handlerProps.append("ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator,")
        }
        if let proxy = r.proxy {
            usings.insert("System.Net")
            handlerProps.append("Proxy = new WebProxy(\(str(proxy))),")
        }
        if handlerProps.isEmpty {
            lines.append("using var client = new HttpClient();")
        } else {
            lines.append("var handler = new HttpClientHandler\n{\n" + handlerProps.map { "    \($0)" }.joined(separator: "\n") + "\n};")
            lines.append("using var client = new HttpClient(handler);")
        }
        if let timeout = r.timeout {
            lines.append("client.Timeout = TimeSpan.FromSeconds(\(Literals.number(timeout)));")
        }
        lines.append("")

        // Request
        let method = standardMethods[r.method].map { "HttpMethod.\($0)" } ?? "new HttpMethod(\(str(r.method)))"
        lines.append("using var request = new HttpRequestMessage(\(method), \(str(r.url)));")

        var contentHeaders: [(String, String)] = []
        for (name, value) in headers {
            if name.lowercased().hasPrefix("content-") && r.hasBody {
                contentHeaders.append((name, value))
            } else {
                lines.append("request.Headers.TryAddWithoutValidation(\(str(name)), \(str(value)));")
            }
        }
        if let auth = r.auth {
            usings.insert("System.Net.Http.Headers")
            usings.insert("System.Text")
            lines.append("request.Headers.Authorization = new AuthenticationHeaderValue(\"Basic\", Convert.ToBase64String(Encoding.UTF8.GetBytes(\(str("\(auth.user):\(auth.password)")))));")
        }

        // Body
        switch r.body {
        case .none:
            break
        case .json(let value):
            lines.append("request.Content = new StringContent(\(multiline(Literals.jsonText(value))));")
        case .form(let pairs, _):
            let keys = pairs.map { $0.0 }
            if Set(keys).count == keys.count {
                lines.append("request.Content = new FormUrlEncodedContent(new Dictionary<string, string>\n{\n"
                    + pairs.map { "    [\(str($0.0))] = \(str($0.1))," }.joined(separator: "\n") + "\n});")
            } else {
                lines.append("request.Content = new FormUrlEncodedContent(new[]\n{\n"
                    + pairs.map { "    new KeyValuePair<string, string>(\(str($0.0)), \(str($0.1)))," }.joined(separator: "\n") + "\n});")
            }
            usings.insert("System.Collections.Generic")
        case .raw(let text):
            lines.append("request.Content = new StringContent(\(str(text)));")
        case .file(let path):
            usings.insert("System.IO")
            lines.append("request.Content = new ByteArrayContent(File.ReadAllBytes(\(str(path))));")
        }

        if !r.formFields.isEmpty {
            lines.append("var content = new MultipartFormDataContent();")
            for field in r.formFields {
                switch field {
                case .text(let name, let value):
                    lines.append("content.Add(new StringContent(\(str(value))), \(str(name)));")
                case .file(let name, let path):
                    usings.insert("System.IO")
                    lines.append("content.Add(new ByteArrayContent(File.ReadAllBytes(\(str(path)))), \(str(name)), \(str(ResolvedRequest.fileName(path))));")
                case .fileContents(let name, let path):
                    usings.insert("System.IO")
                    lines.append("content.Add(new StringContent(File.ReadAllText(\(str(path)))), \(str(name)));")
                }
            }
            lines.append("request.Content = content;")
        }

        for (name, value) in contentHeaders {
            if name.lowercased() == "content-type" {
                usings.insert("System.Net.Http.Headers")
                lines.append("request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(\(str(value)));")
            } else {
                lines.append("request.Content.Headers.TryAddWithoutValidation(\(str(name)), \(str(value)));")
            }
        }

        lines.append("")
        lines.append("using var response = await client.SendAsync(request);")
        if options.includePrint {
            lines.append("Console.WriteLine((int)response.StatusCode);")
            lines.append("Console.WriteLine(await response.Content.ReadAsStringAsync());")
        }

        return CodeGenerator.noteComments(r.notes, prefix: "//")
            + usings.sorted().map { "using \($0);" }.joined(separator: "\n") + "\n\n"
            + lines.joined(separator: "\n") + "\n"
    }

    /// C# 11 raw string literal (falls back to an escaped string if the text contains """).
    private static func multiline(_ text: String) -> String {
        guard !text.contains("\"\"\"") else { return Literals.cSharp(text) }
        return "\"\"\"\n" + Literals.indent(text, "    ") + "\n    \"\"\""
    }
}
