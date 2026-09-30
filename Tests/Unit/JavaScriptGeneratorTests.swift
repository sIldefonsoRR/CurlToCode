import Foundation

private func js(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    JavaScriptGenerator.generate(r, options: options)
}

let javaScriptGeneratorTests = TestSuite("JavaScriptGenerator", [
    Test("simple GET has no options object") {
        expectEqual(js(makeRequest(), printOff), "const response = await fetch('https://api.example.com/items');\n")
    },
    Test("prints status and text") {
        expectContains(js(makeRequest()), "console.log(response.status);\nconsole.log(await response.text());")
    },
    Test("JSON bodies use JSON.stringify with bare keys where possible") {
        let r = makeRequest("POST") { $0.body = .json(sampleJSON()) }
        expectContains(js(r), "method: 'POST',")
        expectContains(js(r), "body: JSON.stringify({\n    name: 'x',\n    ok: true,\n    none: null,\n  }),")
        let quoted = makeRequest("POST") { $0.body = .json(.object([("content-type", .number("1"))])) }
        expectContains(js(quoted), "'content-type': 1,")
    },
    Test("headers include cookies and basic auth") {
        let r = makeRequest {
            $0.headers = [("Accept", "*/*")]
            $0.cookies = [("s", "1")]
            $0.auth = ("u", "p")
        }
        expectContains(js(r), "headers: {\n    'Accept': '*/*',\n    'Cookie': 's=1',\n    'Authorization': 'Basic ' + btoa('u:p'),\n  },")
    },
    Test("form bodies use URLSearchParams, which sets its own Content-Type") {
        let r = makeRequest("POST") { $0.body = .form([("a", "1")], encoded: "a=1") }
        expectContains(js(r), "body: new URLSearchParams({\n    a: '1',\n  }),")
        expectNotContains(js(r), "Content-Type")
        let dup = makeRequest("POST") { $0.body = .form([("k", "1"), ("k", "2")], encoded: "k=1&k=2") }
        expectContains(js(dup), "new URLSearchParams([\n    ['k', '1'],\n    ['k', '2'],\n  ])")
    },
    Test("file bodies and uploads import fs") {
        let file = js(makeRequest("POST") { $0.body = .file("b.bin") })
        expectTrue(file.hasPrefix("import fs from 'node:fs';"))
        expectContains(file, "body: fs.readFileSync('b.bin'),")
        let upload = js(makeRequest("POST") { $0.formFields = [.file(name: "f", path: "dir/p.jpg"), .text(name: "t", value: "v")] })
        expectContains(upload, "const form = new FormData();")
        expectContains(upload, "form.append('f', new Blob([fs.readFileSync('dir/p.jpg')]), 'p.jpg');")
        expectContains(upload, "form.append('t', 'v');")
        expectContains(upload, "body: form,")
    },
    Test("timeout becomes an AbortSignal in milliseconds") {
        expectContains(js(makeRequest { $0.timeout = 2.5 }), "signal: AbortSignal.timeout(2500),")
    },
    Test("insecure and proxy are explained in notes") {
        let code = js(makeRequest { $0.insecure = true; $0.proxy = "http://px:1" })
        expectContains(code, "// Note: fetch can't skip TLS verification")
        expectContains(code, "// Note: Proxy http://px:1 not applied")
    },
])
