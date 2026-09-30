import Foundation

/// Compact, deterministic rendering used to compare parsed values.
func compactJSON(_ value: JSONValue) -> String {
    switch value {
    case .object(let items): return "{" + items.map { "\(Literals.json($0.0)):\(compactJSON($0.1))" }.joined(separator: ",") + "}"
    case .array(let items): return "[" + items.map(compactJSON).joined(separator: ",") + "]"
    case .string(let s): return Literals.json(s)
    case .number(let n): return n
    case .bool(let b): return b ? "true" : "false"
    case .null: return "null"
    }
}

private func parsed(_ text: String) -> String? {
    JSONParser.parse(text).map(compactJSON)
}

let jsonParserTests = TestSuite("JSONParser", [
    Test("parses scalars") {
        expectEqual(parsed("true"), "true")
        expectEqual(parsed("false"), "false")
        expectEqual(parsed("null"), "null")
        expectEqual(parsed("\"hi\""), "\"hi\"")
    },
    Test("keeps numbers exactly as written") {
        expectEqual(parsed("-1.50e+3"), "-1.50e+3")
        expectEqual(parsed("0"), "0")
        expectEqual(parsed("12345678901234567890"), "12345678901234567890")
    },
    Test("preserves object key order") {
        expectEqual(parsed(#"{"z":1,"a":2,"m":3}"#), #"{"z":1,"a":2,"m":3}"#)
    },
    Test("parses nested structures") {
        expectEqual(parsed(#"{"a":[1,{"b":null},[]],"c":{}}"#), #"{"a":[1,{"b":null},[]],"c":{}}"#)
    },
    Test("tolerates whitespace everywhere") {
        expectEqual(parsed(" {\n \"a\" : [ 1 , 2 ] \r\n} \t"), #"{"a":[1,2]}"#)
    },
    Test("decodes string escapes") {
        let value = try unwrap(JSONParser.parse(#""a\"b\\c\/d\n\té""#))
        guard case .string(let s) = value else { return fail("not a string") }
        expectEqual(s, "a\"b\\c/d\n\té")
    },
    Test("decodes surrogate pairs") {
        let value = try unwrap(JSONParser.parse(#""😀""#))
        guard case .string(let s) = value else { return fail("not a string") }
        expectEqual(s, "😀")
    },
    Test("replaces a lone surrogate with U+FFFD") {
        let value = try unwrap(JSONParser.parse(#""\ud83dx""#))
        guard case .string(let s) = value else { return fail("not a string") }
        expectEqual(s, "\u{FFFD}x")
    },
    Test("rejects invalid documents") {
        for text in ["", "{", "[1,]", "{\"a\":1,}", "{'a':1}", "01", "1.", ".5", "tru", "\"a", "[1] x", "{\"a\" 1}", "\"tab\there\""] {
            expectNil(JSONParser.parse(text), "should reject \(text.debugDescription)")
        }
    },
])
