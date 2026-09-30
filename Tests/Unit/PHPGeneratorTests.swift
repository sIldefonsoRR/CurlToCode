import Foundation

private func php(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    PHPGenerator.generate(r, options: options)
}

let phpGeneratorTests = TestSuite("PHPGenerator", [
    Test("simple GET") {
        let code = php(makeRequest())
        expectTrue(code.hasPrefix("<?php\n\n$ch = curl_init();"))
        expectContains(code, "curl_setopt($ch, CURLOPT_URL, 'https://api.example.com/items');")
        expectNotContains(code, "CURLOPT_CUSTOMREQUEST")
        expectContains(code, "echo curl_getinfo($ch, CURLINFO_HTTP_CODE) . PHP_EOL;")
        expectNotContains(php(makeRequest(), printOff), "echo ")
    },
    Test("notes come after the opening tag") {
        expectTrue(php(makeRequest { $0.notes = ["x"] }).hasPrefix("<?php\n\n// Note: x\n\n"))
    },
    Test("sets CUSTOMREQUEST only when needed") {
        expectNotContains(php(makeRequest("POST") { $0.body = .raw("x") }), "CUSTOMREQUEST")
        expectContains(php(makeRequest("POST")), "CURLOPT_CUSTOMREQUEST, 'POST'")
        expectContains(php(makeRequest("PUT") { $0.body = .raw("x") }), "CURLOPT_CUSTOMREQUEST, 'PUT'")
        expectContains(php(makeRequest("HEAD")), "CURLOPT_NOBODY, true")
    },
    Test("headers, cookies and credentials") {
        let code = php(makeRequest { $0.headers = [("Accept", "*/*")]; $0.cookies = [("s", "1")]; $0.auth = ("u", "p") })
        expectContains(code, "CURLOPT_HTTPHEADER, [\n    'Accept: */*',\n]);")
        expectContains(code, "CURLOPT_COOKIE, 's=1'")
        expectContains(code, "CURLOPT_USERPWD, 'u:p'")
    },
    Test("JSON bodies use a nowdoc") {
        expectContains(php(makeRequest("POST") { $0.body = .json(sampleJSON()) }), "CURLOPT_POSTFIELDS, <<<'JSON'\n{\n  \"name\": \"x\",")
    },
    Test("form bodies use http_build_query unless keys repeat") {
        expectContains(php(makeRequest("POST") { $0.body = .form([("a", "1")], encoded: "a=1") }),
                       "http_build_query([\n    'a' => '1',\n])")
        expectContains(php(makeRequest("POST") { $0.body = .form([("k", "1"), ("k", "2")], encoded: "k=1&k=2") }),
                       "CURLOPT_POSTFIELDS, 'k=1&k=2'")
    },
    Test("files and multipart") {
        expectContains(php(makeRequest("POST") { $0.body = .file("b.bin") }), "file_get_contents('b.bin')")
        expectContains(php(makeRequest("POST") { $0.formFields = [.file(name: "f", path: "p.jpg")] }), "'f' => new CURLFile('p.jpg'),")
    },
    Test("proxy, timeout and insecure") {
        let code = php(makeRequest { $0.proxy = "http://px:1"; $0.timeout = 2.5; $0.insecure = true })
        expectContains(code, "CURLOPT_PROXY, 'http://px:1'")
        expectContains(code, "CURLOPT_TIMEOUT_MS, 2500")
        expectContains(code, "CURLOPT_SSL_VERIFYPEER, false")
        expectContains(code, "CURLOPT_SSL_VERIFYHOST, 0")
    },
])
