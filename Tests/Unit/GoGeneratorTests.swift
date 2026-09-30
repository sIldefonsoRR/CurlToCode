import Foundation

private func go(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    GoGenerator.generate(r, options: options)
}

let goGeneratorTests = TestSuite("GoGenerator", [
    Test("simple GET imports only what it uses") {
        let quiet = go(makeRequest(), printOff)
        expectContains(quiet, "import (\n\t\"net/http\"\n)")
        expectContains(quiet, "req, err := http.NewRequest(\"GET\", \"https://api.example.com/items\", nil)")
        expectContains(quiet, "defer resp.Body.Close()\n}")
        let printing = go(makeRequest())
        expectContains(printing, "import (\n\t\"fmt\"\n\t\"io\"\n\t\"net/http\"\n)")
        expectContains(printing, "fmt.Println(string(respBody))")
    },
    Test("JSON uses a backtick string unless it contains a backtick") {
        let code = go(makeRequest("POST") { $0.body = .json(sampleJSON()) })
        expectContains(code, "body := strings.NewReader(`{")
        expectContains(code, "\"strings\"")
        let clash = go(makeRequest("POST") { $0.body = .json(jsonWithString("a`b")) })
        expectNotContains(clash, "NewReader(`")
    },
    Test("raw text is always an escaped string") {
        expectContains(go(makeRequest("POST") { $0.body = .raw("a\nb") }), "body := strings.NewReader(\"a\\nb\")")
    },
    Test("file bodies are opened and closed") {
        let code = go(makeRequest("POST") { $0.body = .file("b.bin") })
        expectContains(code, "body, err := os.Open(\"b.bin\")")
        expectContains(code, "defer body.Close()")
    },
    Test("multipart uses a writer and its content type") {
        let code = go(makeRequest("POST") { $0.formFields = [.text(name: "t", value: "v"), .file(name: "f", path: "d/p.jpg")] })
        expectContains(code, "writer := multipart.NewWriter(body)")
        expectContains(code, "writer.WriteField(\"t\", \"v\")")
        expectContains(code, "writer.CreateFormFile(\"f\", \"p.jpg\")")
        expectContains(code, "req.Header.Set(\"Content-Type\", writer.FormDataContentType())")
        for pkg in ["bytes", "io", "mime/multipart", "os"] { expectContains(code, "\t\"\(pkg)\"\n") }
    },
    Test("headers, Host and basic auth") {
        let code = go(makeRequest { $0.headers = [("Accept", "*/*"), ("Host", "h.example")]; $0.auth = ("u", "p") })
        expectContains(code, "req.Header.Set(\"Accept\", \"*/*\")")
        expectContains(code, "req.Host = \"h.example\"")
        expectContains(code, "req.SetBasicAuth(\"u\", \"p\")")
    },
    Test("client fields are gofmt-aligned") {
        let code = go(makeRequest { $0.proxy = "http://px:1"; $0.insecure = true; $0.timeout = 30 })
        expectContains(code, "\t\tTimeout:   30 * time.Second,\n\t\tTransport: &http.Transport{")
        expectContains(code, "\t\t\tProxy:           http.ProxyURL(proxyURL),\n\t\t\tTLSClientConfig: &tls.Config{InsecureSkipVerify: true},")
        expectContains(go(makeRequest { $0.timeout = 2.5 }), "Timeout: time.Duration(2.5 * float64(time.Second)),")
    },
])
