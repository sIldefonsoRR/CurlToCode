import Foundation

let literalsTests = TestSuite("Literals", [
    Test("python picks the quote that avoids escaping") {
        expectEqual(Literals.python("plain"), "'plain'")
        expectEqual(Literals.python("it's"), "\"it's\"")
        expectEqual(Literals.python("it's \"x\""), #"'it\'s "x"'"#)
    },
    Test("python escapes backslashes and control characters") {
        expectEqual(Literals.python("a\\b\n\t\r\u{01}"), #"'a\\b\n\t\r\x01'"#)
        expectEqual(Literals.python("olá"), "'olá'")
    },
    Test("javaScript escapes quotes and line separators") {
        expectEqual(Literals.javaScript("it's"), #"'it\'s'"#)
        expectEqual(Literals.javaScript("a\u{2028}b"), "'a" + "\\" + "u2028b'")
    },
    Test("double-quoted languages escape control characters their own way") {
        let s = "\"\u{01}"
        expectEqual(Literals.cSharp(s), #""\"\u0001""#)
        expectEqual(Literals.json(s), #""\"\u0001""#)
        expectEqual(Literals.go(s), #""\"\x01""#)
        expectEqual(Literals.rust(s), #""\"\u{1}""#)
        expectEqual(Literals.swift(s), #""\"\u{1}""#)
    },
    Test("java uses octal escapes, never \\u") {
        expectEqual(Literals.java("\u{01}\u{1F}"), #""\001\037""#)
        let backslash = "\\"
        expectEqual(Literals.java(backslash + "u0041"), "\"" + backslash + backslash + "u0041\"")
    },
    Test("ruby and php use single quotes when there are no control characters") {
        expectEqual(Literals.ruby(#"a'b\c #{x}"#), #"'a\'b\\c #{x}'"#)
        expectEqual(Literals.php(#"a'b\c $x"#), #"'a\'b\\c $x'"#)
    },
    Test("ruby and php escape interpolation in double quotes") {
        expectEqual(Literals.ruby("#{x}\n"), ##""\#{x}\n""##)
        expectEqual(Literals.php("$x\n"), #""\$x\n""#)
    },
    Test("hasControl") {
        expectTrue(Literals.hasControl("a\nb"))
        expectTrue(Literals.hasControl("\u{7F}"))
        expectFalse(Literals.hasControl("é ✓"))
    },
    Test("render uses the style's literals and trailing commas") {
        let value = try unwrap(JSONParser.parse(#"{"a":[true,null],"b":{}}"#))
        let python = Literals.Style(string: Literals.python, key: Literals.python,
                                    trueLiteral: "True", falseLiteral: "False", nullLiteral: "None", indentUnit: "    ")
        expectEqual(Literals.render(value, style: python), """
        {
            'a': [
                True,
                None,
            ],
            'b': {},
        }
        """)
    },
    Test("jsonText is valid JSON that round-trips") {
        let source = #"{"s":"q\"\\\n","n":-1.5e3,"a":[[],{}],"z":false}"#
        let value = try unwrap(JSONParser.parse(source))
        let text = Literals.jsonText(value)
        expectNotContains(text, ",\n}")
        let reparsed = try unwrap(JSONParser.parse(text), "jsonText output should parse")
        expectEqual(compactJSON(reparsed), compactJSON(value))
    },
    Test("indent prefixes every line") {
        expectEqual(Literals.indent("a\n\nb", "  "), "  a\n  \n  b")
    },
    Test("number drops .0 for whole values") {
        expectEqual(Literals.number(30), "30")
        expectEqual(Literals.number(2.5), "2.5")
    },
])
