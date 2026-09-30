import Foundation

private func python(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    PythonGenerator.generate(r, options: options)
}

let pythonGeneratorTests = TestSuite("PythonGenerator", [
    Test("simple GET with printing") {
        expectEqual(python(makeRequest()), """
        import requests

        response = requests.get('https://api.example.com/items')

        print(response.status_code)
        print(response.text)

        """)
    },
    Test("printing can be turned off") {
        expectNotContains(python(makeRequest(), printOff), "print(")
    },
    Test("uses requests.request for non-standard methods") {
        expectContains(python(makeRequest("PURGE")), "requests.request('PURGE', 'https://api.example.com/items')")
    },
    Test("splits the query string into params when asked") {
        let r = makeRequest(url: "https://e.com/s?q=1") {
            $0.baseURL = "https://e.com/s"
            $0.queryPairs = [("q", "1")]
        }
        expectContains(python(r), "params = {\n    'q': '1',\n}")
        expectContains(python(r), "requests.get('https://e.com/s', params=params)")
        let kept = python(r, GeneratorOptions(splitQueryParams: false, includePrint: true))
        expectContains(kept, "requests.get('https://e.com/s?q=1')")
    },
    Test("repeated param keys become a list of tuples") {
        let r = makeRequest { $0.getPairs = [("k", "1"), ("k", "2")] }
        expectContains(python(r), "params = [\n    ('k', '1'),\n    ('k', '2'),\n]")
    },
    Test("cookies and headers are separate dicts") {
        let r = makeRequest {
            $0.cookies = [("s", "1")]
            $0.headers = [("Accept", "text/html")]
        }
        expectContains(python(r), "cookies = {\n    's': '1',\n}")
        expectContains(python(r), "headers = {\n    'Accept': 'text/html',\n}")
        expectContains(python(r), "    cookies=cookies,\n    headers=headers,\n")
    },
    Test("JSON bodies become a dict") {
        let r = makeRequest("POST") { $0.body = .json(sampleJSON()) }
        expectContains(python(r), "json_data = {\n    'name': 'x',\n    'ok': True,\n    'none': None,\n}")
        expectContains(python(r), "json=json_data")
    },
    Test("form bodies become a dict") {
        let r = makeRequest("POST") { $0.body = .form([("a", "1")], encoded: "a=1") }
        expectContains(python(r), "data = {\n    'a': '1',\n}")
    },
    Test("non-ASCII raw bodies are encoded") {
        expectContains(python(makeRequest("POST") { $0.body = .raw("olá") }), "data = 'olá'.encode()")
        expectContains(python(makeRequest("POST") { $0.body = .raw("hi") }), "data = 'hi'\n")
    },
    Test("file bodies are read in binary mode") {
        let r = makeRequest("POST") { $0.body = .file("b.bin") }
        expectContains(python(r), "with open('b.bin', 'rb') as f:\n    data = f.read()")
    },
    Test("multipart fields go into files") {
        let r = makeRequest("POST") {
            $0.formFields = [.file(name: "f", path: "p.jpg"), .fileContents(name: "g", path: "n.txt"), .text(name: "h", value: "v")]
        }
        expectContains(python(r), "files = {\n    'f': open('p.jpg', 'rb'),\n    'g': (None, open('n.txt').read()),\n    'h': (None, 'v'),\n}")
    },
    Test("auth, proxy, timeout and insecure become arguments") {
        let r = makeRequest {
            $0.auth = ("u", "p")
            $0.proxy = "http://px:1"
            $0.timeout = 30
            $0.insecure = true
        }
        let code = python(r)
        expectContains(code, "auth=('u', 'p')")
        expectContains(code, "proxies = {\n    'http': 'http://px:1',\n    'https': 'http://px:1',\n}")
        expectContains(code, "timeout=30,")
        expectContains(code, "verify=False,")
    },
    Test("long calls put one argument per line") {
        let r = makeRequest { $0.headers = [("A", "b")]; $0.auth = ("user", "password"); $0.insecure = true }
        expectContains(python(r), "response = requests.get(\n    'https://api.example.com/items',\n    headers=headers,\n")
    },
    Test("notes come first, as comments") {
        let code = python(makeRequest { $0.notes = ["heads up"] })
        expectTrue(code.hasPrefix("# Note: heads up\n\nimport requests"))
    },
])
