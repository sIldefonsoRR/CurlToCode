import Foundation

/// A request to https://api.example.com/items, customised by `configure`.
/// Generator tests build requests directly so they don't depend on the parser.
func makeRequest(
    _ method: String = "GET",
    url: String = "https://api.example.com/items",
    _ configure: (inout ResolvedRequest) -> Void = { _ in }
) -> ResolvedRequest {
    var r = ResolvedRequest()
    r.method = method
    r.originalURL = url
    r.baseURL = url
    configure(&r)
    return r
}

let printOff = GeneratorOptions(splitQueryParams: true, includePrint: false)

/// {"name": "x", "ok": true, "none": null}
func sampleJSON() -> JSONValue {
    JSONParser.parse(#"{"name":"x","ok":true,"none":null}"#)!
}

/// A JSON body containing `text` as a string value.
func jsonWithString(_ text: String) -> JSONValue {
    .object([("v", .string(text))])
}
