import AppKit
import Foundation

/// A model backed by a throwaway defaults suite, so tests never touch the real settings.
private func freshModel() -> (ConverterModel, UserDefaults) {
    let name = "CurlToCodeTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return (ConverterModel(defaults: defaults), defaults)
}

let converterModelTests = TestSuite("ConverterModel", [
    Test("starts with the example, Python and both options on") {
        let (model, _) = freshModel()
        expectEqual(model.curlText, ConverterModel.example)
        expectEqual(model.language, .python)
        expectTrue(model.splitQueryParams)
        expectTrue(model.includePrint)
        expectTrue(model.showSplash)
        expectNil(model.loadedFileName)
    },
    Test("remembers language and options in its defaults") {
        let (model, defaults) = freshModel()
        model.language = .rust
        model.splitQueryParams = false
        model.includePrint = false
        let reloaded = ConverterModel(defaults: defaults)
        expectEqual(reloaded.language, .rust)
        expectFalse(reloaded.splitQueryParams)
        expectFalse(reloaded.includePrint)
    },
    Test("ignores an unknown stored language") {
        let (_, defaults) = freshModel()
        defaults.set("cobol", forKey: "language")
        expectEqual(ConverterModel(defaults: defaults).language, .python)
    },
    Test("the example converts in every language") {
        let (model, _) = freshModel()
        for language in Language.allCases {
            model.language = language
            expectContains(model.code, "httpbin.org", language.displayName)
        }
    },
    Test("options change the generated code") {
        let (model, _) = freshModel()
        expectContains(model.code, "print(response.status_code)")
        expectContains(model.code, "params=params")
        model.includePrint = false
        model.splitQueryParams = false
        expectNotContains(model.code, "print(")
        expectContains(model.code, "'https://httpbin.org/post?source=app'")
    },
    Test("invalid input gives an error and no code") {
        let (model, _) = freshModel()
        model.curlText = "curl 'unterminated"
        expectEqual(model.code, "")
        guard case .failure(let error) = model.conversion else { return fail("expected a failure") }
        expectContains(error.localizedDescription, "Unterminated")
    },
    Test("inputIsEmpty ignores whitespace") {
        let (model, _) = freshModel()
        model.curlText = "  \n\t"
        expectTrue(model.inputIsEmpty)
        model.curlText = "curl x"
        expectFalse(model.inputIsEmpty)
    },
    Test("clear and loadExample reset the loaded file name") {
        let (model, _) = freshModel()
        model.loadedFileName = "a.sh"
        model.clear()
        expectEqual(model.curlText, "")
        expectNil(model.loadedFileName)
        model.loadedFileName = "b.sh"
        model.loadExample()
        expectEqual(model.curlText, ConverterModel.example)
        expectNil(model.loadedFileName)
    },
    Test("load reads a UTF-8 file and remembers its name") {
        let (model, _) = freshModel()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("req-\(UUID().uuidString).sh")
        defer { try? FileManager.default.removeItem(at: url) }
        try "#!/bin/sh\ncurl https://e.com/olá".write(to: url, atomically: true, encoding: .utf8)
        model.load(url)
        expectEqual(model.curlText, "#!/bin/sh\ncurl https://e.com/olá")
        expectEqual(model.loadedFileName, url.lastPathComponent)
        expectContains(model.code, "https://e.com/olá")
    },
])
