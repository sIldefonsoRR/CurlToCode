import Foundation

// Minimal test runner: compiled together with Sources/Core by test.sh.
// Every generated file is also written to build/test-output/<language>/ so
// test.sh can syntax-check it with the real toolchains.

var failures = 0
var caseNumber = 0
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : nil

func save(_ code: String, language: Language, name: String) {
    guard let dir = outputDir else { return }
    let folder = "\(dir)/\(language.rawValue)"
    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    try? code.write(toFile: "\(folder)/\(name).\(language.fileExtension)", atomically: true, encoding: .utf8)
}

func check(_ name: String, _ curl: String, options: GeneratorOptions = .init(), contains expected: [String], excludes: [String] = []) {
    caseNumber += 1
    do {
        let code = try CodeGenerator.generate(curl, language: .python, options: options)
        save(code, language: .python, name: "case_\(caseNumber)")
        var ok = true
        for e in expected where !code.contains(e) {
            print("FAIL [\(name)]: missing \(e.debugDescription)")
            ok = false
        }
        for e in excludes where code.contains(e) {
            print("FAIL [\(name)]: unexpected \(e.debugDescription)")
            ok = false
        }
        if ok {
            print("ok   \(name)")
        } else {
            failures += 1
            print("---- output ----\n\(code)----------------")
        }
    } catch {
        failures += 1
        print("FAIL [\(name)]: threw \(error.localizedDescription)")
    }
}

func checkThrows(_ name: String, _ curl: String) {
    do {
        _ = try CodeGenerator.generate(curl, language: .python)
        failures += 1
        print("FAIL [\(name)]: expected error")
    } catch {
        print("ok   \(name) (\(error.localizedDescription))")
    }
}

check("simple GET", "curl https://api.example.com/users",
      contains: ["import requests", "response = requests.get('https://api.example.com/users')"])

check("no scheme", "curl example.com",
      contains: ["requests.get('http://example.com')"])

check("chrome JSON POST", """
curl 'https://api.example.com/items' \\
  -H 'accept: application/json' \\
  -H 'content-type: application/json' \\
  --data-raw '{"name":"widget","tags":["a","b"],"active":true,"owner":null,"price":9.5}'
""", contains: [
    "headers = {\n    'accept': 'application/json',\n    'content-type': 'application/json',\n}",
    "json_data = {\n    'name': 'widget',\n    'tags': [\n        'a',\n        'b',\n    ],\n    'active': True,\n    'owner': None,\n    'price': 9.5,\n}",
    "response = requests.post(\n    'https://api.example.com/items',\n    headers=headers,\n    json=json_data,\n)",
])

check("form data", "curl -d 'a=1&b=hello%20world&c=x+y' https://example.com/form",
      contains: ["data = {\n    'a': '1',\n    'b': 'hello world',\n    'c': 'x y',\n}", "requests.post(", "data=data"])

check("multiple -d joined", "curl https://e.com -d a=1 -d b=2",
      contains: ["'a': '1'", "'b': '2'"])

check("raw text body", "curl https://e.com -H 'Content-Type: text/plain' -d 'hello there'",
      contains: ["data = 'hello there'"])

check("non-ascii body encoded", "curl https://e.com -H 'Content-Type: text/plain' -d 'olá'",
      contains: ["data = 'olá'.encode()"])

check("PUT with basic auth", "curl -X PUT -u alice:s3cret https://e.com/r/1",
      contains: ["requests.put('https://e.com/r/1', auth=('alice', 's3cret'))"])

check("custom method", "curl -X PURGE https://cdn.e.com/x",
      contains: ["requests.request('PURGE', 'https://cdn.e.com/x')"])

check("combined short flags", "curl -sSLk -XPOST https://e.com",
      contains: ["requests.post('https://e.com', verify=False)"], excludes: ["# Note"])

check("head", "curl -I https://e.com", contains: ["requests.head('https://e.com')"])

check("query params split", "curl 'https://e.com/search?q=swift+ui&page=2&tag=a&tag=b'",
      contains: ["params = [\n    ('q', 'swift ui'),\n    ('page', '2'),\n    ('tag', 'a'),\n    ('tag', 'b'),\n]",
                 "requests.get('https://e.com/search', params=params)"])

check("query params kept", "curl 'https://e.com/search?q=1'",
      options: GeneratorOptions(splitQueryParams: false, includePrint: false),
      contains: ["requests.get('https://e.com/search?q=1')"], excludes: ["params", "print("])

check("cookie header", "curl https://e.com -H 'Cookie: session=abc; theme=dark'",
      contains: ["cookies = {\n    'session': 'abc',\n    'theme': 'dark',\n}", "cookies=cookies"], excludes: ["headers ="])

check("-b cookies", "curl -b 'a=1' https://e.com", contains: ["cookies = {\n    'a': '1',\n}"])

check("-G moves data to params", "curl -G https://e.com/s -d q=test -d n=5",
      contains: ["params = {\n    'q': 'test',\n    'n': '5',\n}", "requests.get("], excludes: ["data="])

check("multipart form", "curl https://e.com/up -F 'file=@photo.jpg;type=image/jpeg' -F 'title=My pic' --form-string 'raw=@notafile'",
      contains: ["'file': open('photo.jpg', 'rb'),", "'title': (None, 'My pic'),", "'raw': (None, '@notafile'),", "files=files", "requests.post("])

check("data from file", "curl https://e.com -H 'Content-Type: application/json' -d @body.json",
      contains: ["with open('body.json', 'rb') as f:\n    data = f.read()", "data=data"])

check("--json flag", "curl --json '{\"x\": 1}' https://e.com",
      contains: ["'Content-Type': 'application/json'", "json_data = {\n    'x': 1,\n}", "requests.post("])

check("ANSI-C quoting", "curl https://e.com -H $'X-Test: it\\'s' --data-raw $'line1\\nline2' -H 'Content-Type: text/plain'",
      contains: ["'X-Test': \"it's\"", "data = 'line1\\nline2'"])

check("double quotes and escapes", "curl \"https://e.com\" -H \"Authorization: Bearer \\$TOKEN\"",
      contains: ["'Authorization': 'Bearer $TOKEN'"])

check("long option with =", "curl --request=DELETE --url=https://e.com/1",
      contains: ["requests.delete('https://e.com/1')"])

check("proxy and timeout", "curl -x proxy.local:8080 -m 30 https://e.com",
      contains: ["'http': 'http://proxy.local:8080'", "timeout=30"])

check("data-urlencode", "curl https://e.com --data-urlencode 'msg=a b&c'",
      contains: ["'msg': 'a b&c'"])

check("unsupported option noted", "curl --tlsv1.2 https://e.com",
      contains: ["# Note: Option --tlsv1.2 is not supported"])

check("long call wraps", "curl -X POST 'https://very-long-hostname.example.com/api/v1/resources/items' -H 'A: b' -d 'x=1' -u u:p -k",
      contains: ["response = requests.post(\n    'https://very-long-hostname.example.com/api/v1/resources/items',\n    headers=headers,"])

check("windows CRLF continuation", "curl https://e.com \\\r\n  -H 'A: b'", contains: ["'A': 'b'"])

check("script file with comments", "#!/bin/bash\n# fetch users\ncurl https://e.com/users#frag -H 'X-Tag: a#b' # trailing",
      contains: ["requests.get('https://e.com/users', headers=headers)", "'X-Tag': 'a#b'"])

check("prompt prefix", "$ curl https://e.com", contains: ["requests.get('https://e.com')"])

checkThrows("empty", "   ")
checkThrows("not curl", "wget https://e.com")
checkThrows("no url", "curl -H 'A: b'")
checkThrows("unterminated quote", "curl 'https://e.com")
checkThrows("missing value", "curl https://e.com -H")

// MARK: - All languages

/// Requests exercising every feature; each is generated for every language.
let samples: [(String, String)] = [
    ("get", "curl https://api.example.com/users"),
    ("json_post", """
    curl 'https://api.example.com/items?x=1' -H 'Accept: application/json' -H 'Content-Type: application/json' \\
      -H 'Cookie: session=abc; theme=dark' -H 'accept-encoding: gzip, br' -u alice:s3cret \\
      --data-raw '{"name":"widget \\"w\\" $x #{y}","tags":["a","b"],"n":{"ok":true,"none":null,"price":9.5,"empty":[]}}'
    """),
    ("form_options", "curl -k -x proxy.local:8080 -m 2.5 -d 'a=1&b=hello%20world' https://e.com/form"),
    ("form_duplicates", "curl -d 'k=1&k=2' https://e.com/form -m 30"),
    ("multipart", "curl https://e.com/up -H 'Content-Type: multipart/form-data; boundary=x' -F 'file=@photo.jpg' -F 'title=My \"pic\"' -F 'notes=<notes.txt'"),
    ("file_custom_method", "curl -X PURGE https://e.com/cache -H 'Content-Type: application/octet-stream' --data-binary @payload.bin"),
    ("head", "curl -I https://e.com"),
    ("tricky_strings", "curl -G https://e.com/search -d 'q=a b' -H $'X-Text: tab\\there \\'quoted\\' back\\\\slash $HOME `cmd` \\u00e9' -H 'Content-Type: text/plain' "),
    ("raw_body", "curl https://e.com -H 'Content-Type: text/plain' --data-raw $'line1\\nline2 \"q\" \\\\ ol\\u00e1'"),
    ("delete_options", "curl -X DELETE https://e.com/1 -X OPTIONS"),
]

/// Snippets each language's output must contain for a given sample.
let expectations: [Language: [String: [String]]] = [
    .javascript: [
        "json_post": ["method: 'POST'", "'Cookie': 'session=abc; theme=dark'", "btoa('alice:s3cret')", "body: JSON.stringify({\n    name:"],
        "form_options": ["body: new URLSearchParams({", "AbortSignal.timeout(2500)", "NODE_TLS_REJECT_UNAUTHORIZED"],
        "multipart": ["const form = new FormData();", "import fs from 'node:fs';"],
        "get": ["const response = await fetch('https://api.example.com/users');"],
    ],
    .csharp: [
        "json_post": ["HttpMethod.Post", "UseCookies = false", "new AuthenticationHeaderValue(\"Basic\"", "MediaTypeHeaderValue.Parse(\"application/json\")"],
        "form_options": ["DangerousAcceptAnyServerCertificateValidator", "new WebProxy(\"http://proxy.local:8080\")", "TimeSpan.FromSeconds(2.5)", "FormUrlEncodedContent"],
        "file_custom_method": ["new HttpMethod(\"PURGE\")", "File.ReadAllBytes(\"payload.bin\")"],
    ],
    .ruby: [
        "json_post": ["Net::HTTP::Post.new(uri)", "req.basic_auth('alice', 's3cret')", ".to_json", "'none' => nil"],
        "form_options": ["OpenSSL::SSL::VERIFY_NONE", "proxy = URI('http://proxy.local:8080')", "http.read_timeout = 2.5"],
        "file_custom_method": ["Net::HTTPGenericRequest.new('PURGE', true, true, uri)"],
    ],
    .java: [
        "json_post": [".POST(HttpRequest.BodyPublishers.ofString(\"\"\"", "Base64.getEncoder()"],
        "head": [".method(\"HEAD\", HttpRequest.BodyPublishers.noBody())"],
        "multipart": ["Multipart form data (-F) is not built into java.net.http"],
    ],
    .rust: [
        "json_post": [".post(\"https://api.example.com/items?x=1\")", ".basic_auth(\"alice\", Some(\"s3cret\"))", ".body(r#\""],
        "multipart": ["features = [\"blocking\", \"multipart\"]", ".file(\"file\", \"photo.jpg\")?"],
        "file_custom_method": ["reqwest::Method::from_bytes(b\"PURGE\")?"],
    ],
    .go: [
        "json_post": ["http.NewRequest(\"POST\"", "req.SetBasicAuth(\"alice\", \"s3cret\")"],
        "form_options": ["InsecureSkipVerify: true", "time.Duration(2.5 * float64(time.Second))"],
        "multipart": ["writer.FormDataContentType()", "\"mime/multipart\""],
    ],
    .php: [
        "json_post": ["CURLOPT_COOKIE, 'session=abc; theme=dark'", "CURLOPT_USERPWD, 'alice:s3cret'", "<<<'JSON'"],
        "multipart": ["new CURLFile('photo.jpg')"],
        "head": ["CURLOPT_NOBODY, true"],
    ],
    .swift: [
        "json_post": ["request.httpMethod = \"POST\"", "base64EncodedString()", "#\"\"\""],
        "multipart": ["multipart/form-data; boundary="],
    ],
]

for language in Language.allCases {
    for (name, curl) in samples {
        caseNumber += 1
        do {
            let code = try CodeGenerator.generate(curl, language: language)
            save(code, language: language, name: name)
            let noPrint = try CodeGenerator.generate(curl, language: language, options: GeneratorOptions(includePrint: false))
            save(noPrint, language: language, name: name + "_noprint")
            let missing = (expectations[language]?[name] ?? []).filter { !code.contains($0) }
            if missing.isEmpty {
                print("ok   \(language.displayName) \(name)")
            } else {
                failures += 1
                print("FAIL [\(language.displayName) \(name)]: missing \(missing)")
                print("---- output ----\n\(code)----------------")
            }
        } catch {
            failures += 1
            print("FAIL [\(language.displayName) \(name)]: threw \(error.localizedDescription)")
        }
    }
}

print(failures == 0 ? "\nAll tests passed." : "\n\(failures) test(s) failed.")
exit(failures == 0 ? 0 : 1)
