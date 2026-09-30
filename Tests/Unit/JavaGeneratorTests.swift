import Foundation

private func java(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    JavaGenerator.generate(r, options: options)
}

let javaGeneratorTests = TestSuite("JavaGenerator", [
    Test("simple GET inside class Main") {
        let code = java(makeRequest())
        expectContains(code, "public class Main {\n    public static void main(String[] args) throws Exception {")
        expectContains(code, "HttpClient client = HttpClient.newHttpClient();")
        expectContains(code, ".uri(URI.create(\"https://api.example.com/items\"))\n            .build();")
        expectContains(code, "System.out.println(response.statusCode());")
        expectNotContains(code, ".GET()")
    },
    Test("printing can be turned off") {
        expectNotContains(java(makeRequest(), printOff), "System.out")
    },
    Test("picks the right builder method") {
        expectContains(java(makeRequest("DELETE")), ".DELETE()")
        expectContains(java(makeRequest("POST") { $0.body = .raw("x") }), ".POST(HttpRequest.BodyPublishers.ofString(\"x\"))")
        expectContains(java(makeRequest("PUT") { $0.body = .raw("x") }), ".PUT(HttpRequest.BodyPublishers.ofString(\"x\"))")
        expectContains(java(makeRequest("PATCH") { $0.body = .raw("x") }), ".method(\"PATCH\", HttpRequest.BodyPublishers.ofString(\"x\"))")
        expectContains(java(makeRequest("HEAD")), ".method(\"HEAD\", HttpRequest.BodyPublishers.noBody())")
    },
    Test("JSON uses a text block with backslashes escaped") {
        let code = java(makeRequest("POST") { $0.body = .json(jsonWithString(#"a\b"#)) })
        expectContains(code, ".POST(HttpRequest.BodyPublishers.ofString(\"\"\"\n")
        expectContains(code, #""v": "a\\\\b""#)
        expectContains(code, "}\"\"\"))")
    },
    Test("form bodies send the encoded string, files use ofFile") {
        expectContains(java(makeRequest("POST") { $0.body = .form([("a", "1")], encoded: "a=1") }), "ofString(\"a=1\")")
        let file = java(makeRequest("POST") { $0.body = .file("b.bin") })
        expectContains(file, "HttpRequest.BodyPublishers.ofFile(Path.of(\"b.bin\"))")
        expectContains(file, "import java.nio.file.Path;")
    },
    Test("restricted headers are removed with a note") {
        let code = java(makeRequest { $0.headers = [("Host", "x"), ("Accept", "*/*")] })
        expectNotContains(code, ".header(\"Host\"")
        expectContains(code, ".header(\"Accept\", \"*/*\")")
        expectContains(code, "// Note: Header Host removed")
    },
    Test("basic auth uses Base64") {
        let code = java(makeRequest { $0.auth = ("u", "p") })
        expectContains(code, "import java.util.Base64;")
        expectContains(code, "Base64.getEncoder().encodeToString(\"u:p\".getBytes())")
    },
    Test("proxy and timeout configure the client") {
        let code = java(makeRequest { $0.proxy = "http://px:8080"; $0.timeout = 2.5 })
        expectContains(code, ".proxy(ProxySelector.of(new InetSocketAddress(\"px\", 8080)))")
        expectContains(code, ".connectTimeout(Duration.ofMillis(2500))")
        expectContains(code, ".timeout(Duration.ofMillis(2500))")
        expectContains(java(makeRequest { $0.proxy = "http://px" }), "new InetSocketAddress(\"px\", 1080)")
    },
    Test("unsupported features are noted") {
        let code = java(makeRequest("POST") { $0.insecure = true; $0.formFields = [.text(name: "a", value: "b")] })
        expectContains(code, "// Note: -k/--insecure not applied")
        expectContains(code, "// Note: Multipart form data (-F) is not built into java.net.http")
    },
])
