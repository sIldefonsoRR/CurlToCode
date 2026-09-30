import Foundation

private func rust(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    RustGenerator.generate(r, options: options)
}

let rustGeneratorTests = TestSuite("RustGenerator", [
    Test("simple GET") {
        let code = rust(makeRequest())
        expectContains(code, "// reqwest = { version = \"0.12\", features = [\"blocking\"] }")
        expectContains(code, "fn main() -> Result<(), Box<dyn std::error::Error>> {")
        expectContains(code, "let client = reqwest::blocking::Client::new();")
        expectContains(code, "let response = client\n        .get(\"https://api.example.com/items\")\n        .send()?;")
        expectContains(code, "println!(\"{}\", response.text()?);\n    Ok(())\n}")
    },
    Test("without printing the response binding is prefixed with _") {
        let code = rust(makeRequest(), printOff)
        expectContains(code, "let _response = client")
        expectNotContains(code, "println!")
    },
    Test("OPTIONS and custom methods use request()") {
        expectContains(rust(makeRequest("OPTIONS")), ".request(reqwest::Method::OPTIONS, \"https://api.example.com/items\")")
        expectContains(rust(makeRequest("PURGE")), ".request(reqwest::Method::from_bytes(b\"PURGE\")?, ")
        expectContains(rust(makeRequest("DELETE")), ".delete(")
    },
    Test("client options use the builder") {
        let code = rust(makeRequest { $0.insecure = true; $0.proxy = "http://px:1"; $0.timeout = 30 })
        expectContains(code, "reqwest::blocking::Client::builder()\n        .danger_accept_invalid_certs(true)\n        .proxy(reqwest::Proxy::all(\"http://px:1\")?)\n        .timeout(std::time::Duration::from_secs(30))\n        .build()?;")
        expectContains(rust(makeRequest { $0.timeout = 2.5 }), "Duration::from_secs_f64(2.5)")
    },
    Test("headers and basic auth") {
        let code = rust(makeRequest { $0.headers = [("Accept", "*/*")]; $0.auth = ("u", "p") })
        expectContains(code, ".header(\"Accept\", \"*/*\")")
        expectContains(code, ".basic_auth(\"u\", Some(\"p\"))")
    },
    Test("JSON uses a raw string with enough #s") {
        expectContains(rust(makeRequest("POST") { $0.body = .json(sampleJSON()) }), ".body(r#\"\n")
        let clash = rust(makeRequest("POST") { $0.body = .json(jsonWithString("a\"#b")) })
        expectContains(clash, ".body(r##\"\n")
        expectContains(clash, "\"##)")
    },
    Test("file bodies and multipart") {
        expectContains(rust(makeRequest("POST") { $0.body = .file("b.bin") }), ".body(std::fs::read(\"b.bin\")?)")
        let code = rust(makeRequest("POST") {
            $0.formFields = [.text(name: "t", value: "v"), .file(name: "f", path: "p.jpg"), .fileContents(name: "g", path: "n.txt")]
        })
        expectContains(code, "features = [\"blocking\", \"multipart\"]")
        expectContains(code, "let form = reqwest::blocking::multipart::Form::new()\n        .text(\"t\", \"v\")\n        .file(\"f\", \"p.jpg\")?\n        .text(\"g\", std::fs::read_to_string(\"n.txt\")?);")
        expectContains(code, ".multipart(form)")
    },
])
