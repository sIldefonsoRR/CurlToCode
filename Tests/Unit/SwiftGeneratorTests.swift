import Foundation

private func swiftCode(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    SwiftGenerator.generate(r, options: options)
}

let swiftGeneratorTests = TestSuite("SwiftGenerator", [
    Test("simple GET") {
        let code = swiftCode(makeRequest())
        expectTrue(code.hasPrefix("import Foundation\n\nvar request = URLRequest(url: URL(string: \"https://api.example.com/items\")!)"))
        expectNotContains(code, "httpMethod")
        expectContains(code, "let (data, response) = try await URLSession.shared.data(for: request)")
    },
    Test("without printing the result is discarded") {
        expectContains(swiftCode(makeRequest(), printOff), "let (_, _) = try await URLSession.shared.data(for: request)")
    },
    Test("method, headers and basic auth") {
        let code = swiftCode(makeRequest("PUT") { $0.headers = [("Accept", "*/*")]; $0.auth = ("u", "p") })
        expectContains(code, "request.httpMethod = \"PUT\"")
        expectContains(code, "request.setValue(\"*/*\", forHTTPHeaderField: \"Accept\")")
        expectContains(code, "Data(\"u:p\".utf8).base64EncodedString()")
    },
    Test("JSON uses a raw multi-line string") {
        let code = swiftCode(makeRequest("POST") { $0.body = .json(sampleJSON()) })
        expectContains(code, "request.httpBody = Data(#\"\"\"\n    {\n      \"name\": \"x\",")
        expectContains(code, "\n    \"\"\"#.utf8)")
    },
    Test("form, raw and file bodies") {
        expectContains(swiftCode(makeRequest("POST") { $0.body = .form([("a", "1")], encoded: "a=1") }), "request.httpBody = Data(\"a=1\".utf8)")
        expectContains(swiftCode(makeRequest("POST") { $0.body = .file("b.bin") }),
                       "request.httpBody = try Data(contentsOf: URL(fileURLWithPath: \"b.bin\"))")
    },
    Test("multipart builds the body by hand") {
        let code = swiftCode(makeRequest("POST") { $0.formFields = [.text(name: "a\"b", value: "v"), .file(name: "f", path: "d/p.jpg")] })
        expectContains(code, "let boundary = \"Boundary-\\(UUID().uuidString)\"")
        expectContains(code, "name=\\\"a%22b\\\"", "quotes in field names are percent-encoded")
        expectContains(code, "filename=\\\"p.jpg\\\"")
        expectContains(code, "request.httpBody = body")
    },
    Test("timeout, and notes for unsupported options") {
        let code = swiftCode(makeRequest { $0.timeout = 2.5; $0.insecure = true; $0.proxy = "http://px:1" })
        expectContains(code, "request.timeoutInterval = 2.5")
        expectContains(code, "// Note: -k/--insecure not applied")
        expectContains(code, "// Note: Proxy http://px:1 not applied")
    },
])
