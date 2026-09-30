import Foundation

private func cs(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    CSharpGenerator.generate(r, options: options)
}

let cSharpGeneratorTests = TestSuite("CSharpGenerator", [
    Test("simple GET") {
        let code = cs(makeRequest())
        expectTrue(code.hasPrefix("using System;\nusing System.Net.Http;\n\n"), "only the needed usings")
        expectContains(code, "using var client = new HttpClient();")
        expectContains(code, "using var request = new HttpRequestMessage(HttpMethod.Get, \"https://api.example.com/items\");")
        expectContains(code, "Console.WriteLine((int)response.StatusCode);")
    },
    Test("printing can be turned off") {
        expectNotContains(cs(makeRequest(), printOff), "Console.WriteLine")
    },
    Test("non-standard methods use new HttpMethod") {
        expectContains(cs(makeRequest("PURGE")), "new HttpMethod(\"PURGE\")")
        expectContains(cs(makeRequest("PATCH")), "HttpMethod.Patch")
    },
    Test("a handler is created for cookies, insecure and proxy") {
        let code = cs(makeRequest {
            $0.cookies = [("s", "1")]
            $0.insecure = true
            $0.proxy = "http://px:1"
        })
        expectContains(code, "UseCookies = false,")
        expectContains(code, "HttpClientHandler.DangerousAcceptAnyServerCertificateValidator,")
        expectContains(code, "Proxy = new WebProxy(\"http://px:1\"),")
        expectContains(code, "using System.Net;")
        expectContains(code, "using var client = new HttpClient(handler);")
        expectContains(code, "request.Headers.TryAddWithoutValidation(\"Cookie\", \"s=1\");")
    },
    Test("timeout is set on the client") {
        expectContains(cs(makeRequest { $0.timeout = 2.5 }), "client.Timeout = TimeSpan.FromSeconds(2.5);")
    },
    Test("JSON uses a raw string and content headers go on the content") {
        let code = cs(makeRequest("POST") {
            $0.headers = [("Content-Type", "application/json"), ("Content-Language", "en")]
            $0.body = .json(sampleJSON())
        })
        expectContains(code, "request.Content = new StringContent(\"\"\"\n    {\n      \"name\": \"x\",")
        expectContains(code, "\n    \"\"\");")
        expectContains(code, "request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(\"application/json\");")
        expectContains(code, "request.Content.Headers.TryAddWithoutValidation(\"Content-Language\", \"en\");")
        expectNotContains(code, "request.Headers.TryAddWithoutValidation(\"Content-Type\"")
    },
    Test("form bodies use FormUrlEncodedContent") {
        let unique = cs(makeRequest("POST") { $0.body = .form([("a", "1")], encoded: "a=1") })
        expectContains(unique, "new FormUrlEncodedContent(new Dictionary<string, string>\n{\n    [\"a\"] = \"1\",\n});")
        let dup = cs(makeRequest("POST") { $0.body = .form([("k", "1"), ("k", "2")], encoded: "k=1&k=2") })
        expectContains(dup, "new KeyValuePair<string, string>(\"k\", \"2\"),")
    },
    Test("multipart and file bodies read files") {
        let code = cs(makeRequest("POST") { $0.formFields = [.file(name: "f", path: "d/p.jpg"), .text(name: "t", value: "v")] })
        expectContains(code, "content.Add(new ByteArrayContent(File.ReadAllBytes(\"d/p.jpg\")), \"f\", \"p.jpg\");")
        expectContains(code, "content.Add(new StringContent(\"v\"), \"t\");")
        expectContains(code, "using System.IO;")
        expectContains(cs(makeRequest("POST") { $0.body = .file("b.bin") }), "new ByteArrayContent(File.ReadAllBytes(\"b.bin\"))")
    },
    Test("basic auth sets the Authorization header") {
        expectContains(cs(makeRequest { $0.auth = ("u", "p") }),
                       "new AuthenticationHeaderValue(\"Basic\", Convert.ToBase64String(Encoding.UTF8.GetBytes(\"u:p\")))")
    },
])
