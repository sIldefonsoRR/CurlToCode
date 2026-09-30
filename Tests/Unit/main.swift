import Foundation

// Unit test runner. Usage: build/unit-tests [suite-name-filter]

let suites: [TestSuite] = [
    shellTokenizerTests,
    jsonParserTests,
    curlParserTests,
    resolvedRequestTests,
    literalsTests,
    languageTests,
    pythonGeneratorTests,
    javaScriptGeneratorTests,
    cSharpGeneratorTests,
    rubyGeneratorTests,
    javaGeneratorTests,
    rustGeneratorTests,
    goGeneratorTests,
    phpGeneratorTests,
    swiftGeneratorTests,
    converterModelTests,
    syntaxHighlighterTests,
    themeTests,
]

exit(TestRunner.run(suites, filter: CommandLine.arguments.dropFirst().first))
