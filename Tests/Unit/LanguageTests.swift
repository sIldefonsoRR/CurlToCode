import Foundation

let languageTests = TestSuite("Language", [
    Test("has nine languages with unique names and extensions") {
        expectEqual(Language.allCases.count, 9)
        expectEqual(Set(Language.allCases.map(\.displayName)).count, 9)
        expectEqual(Set(Language.allCases.map(\.fileExtension)).count, 9)
    },
    Test("default file names use the language's extension") {
        for language in Language.allCases {
            expectTrue(language.defaultFileName.hasSuffix(".\(language.fileExtension)"), language.displayName)
        }
    },
    Test("only Python supports splitting query params") {
        expectEqual(Language.allCases.filter(\.supportsParamsSplit), [.python])
    },
    Test("every language has a library and highlight keywords") {
        for language in Language.allCases {
            expectFalse(language.library.isEmpty, language.displayName)
            expectFalse(language.keywords.isEmpty, language.displayName)
        }
    },
    Test("notes are written as comments in the language's syntax") {
        for language in Language.allCases {
            let code = try CodeGenerator.generate("curl --tlsv1.3 https://e.com", language: language)
            expectContains(code, "\(language.lineComment) Note: Option --tlsv1.3", language.displayName)
        }
    },
    Test("every language generates code for a basic request") {
        for language in Language.allCases {
            expectContains(try CodeGenerator.generate("curl https://e.com/x", language: language), "https://e.com/x", language.displayName)
        }
    },
    Test("generator errors come from the parser") {
        expectThrows(try CodeGenerator.generate("wget x", language: .go))
    },
    Test("noteComments is empty without notes") {
        expectEqual(CodeGenerator.noteComments([], prefix: "#"), "")
        expectEqual(CodeGenerator.noteComments(["a", "b"], prefix: "//"), "// Note: a\n// Note: b\n\n")
    },
])
