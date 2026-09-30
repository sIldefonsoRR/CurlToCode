import Foundation

/// An output language. The raw value is persisted in UserDefaults, so don't rename cases.
enum Language: String, CaseIterable, Identifiable {
    case python, javascript, csharp, ruby, java, rust, go, php, swift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .csharp: return "C#"
        case .ruby: return "Ruby"
        case .java: return "Java"
        case .rust: return "Rust"
        case .go: return "Go"
        case .php: return "PHP"
        case .swift: return "Swift"
        }
    }

    /// Library or API the generated code uses.
    var library: String {
        switch self {
        case .python: return "requests"
        case .javascript: return "fetch"
        case .csharp: return "HttpClient"
        case .ruby: return "Net::HTTP"
        case .java: return "java.net.http"
        case .rust: return "reqwest"
        case .go: return "net/http"
        case .php: return "ext-curl"
        case .swift: return "URLSession"
        }
    }

    var fileExtension: String {
        switch self {
        case .python: return "py"
        case .javascript: return "mjs"
        case .csharp: return "cs"
        case .ruby: return "rb"
        case .java: return "java"
        case .rust: return "rs"
        case .go: return "go"
        case .php: return "php"
        case .swift: return "swift"
        }
    }

    var defaultFileName: String {
        switch self {
        case .java: return "Main.java"
        case .rust: return "main.rs"
        case .go: return "main.go"
        case .swift: return "main.swift"
        case .csharp: return "Program.cs"
        default: return "request.\(fileExtension)"
        }
    }

    var lineComment: String {
        switch self {
        case .python, .ruby: return "#"
        default: return "//"
        }
    }

    /// Whether the "query string → params" option applies.
    var supportsParamsSplit: Bool { self == .python }

    var keywords: [String] {
        switch self {
        case .python: return ["import", "from", "as", "with", "True", "False", "None", "print", "open"]
        case .javascript: return ["import", "from", "const", "let", "await", "new", "true", "false", "null"]
        case .csharp: return ["using", "var", "new", "await", "true", "false", "null", "string"]
        case .ruby: return ["require", "do", "end", "true", "false", "nil", "puts"]
        case .java: return ["import", "public", "class", "static", "void", "throws", "new", "true", "false", "null", "String"]
        case .rust: return ["use", "fn", "let", "mut", "Ok", "Some", "true", "false"]
        case .go: return ["package", "import", "func", "if", "err", "nil", "defer", "true", "false", "return"]
        case .php: return ["new", "true", "false", "null", "echo", "if", "die"]
        case .swift: return ["import", "let", "var", "try", "await", "as", "true", "false", "nil"]
        }
    }
}

struct GeneratorOptions {
    /// Python: move the URL query string into a `params` dict.
    var splitQueryParams = true
    /// Print the response status and body at the end.
    var includePrint = true
}

/// Entry point: curl command in, source code out.
enum CodeGenerator {
    /// Throws `CurlParseError` or `ShellTokenizerError` when the command can't be parsed.
    static func generate(_ curl: String, language: Language, options: GeneratorOptions = .init()) throws -> String {
        let request = ResolvedRequest.resolve(try CurlParser.parse(curl))
        switch language {
        case .python: return PythonGenerator.generate(request, options: options)
        case .javascript: return JavaScriptGenerator.generate(request, options: options)
        case .csharp: return CSharpGenerator.generate(request, options: options)
        case .ruby: return RubyGenerator.generate(request, options: options)
        case .java: return JavaGenerator.generate(request, options: options)
        case .rust: return RustGenerator.generate(request, options: options)
        case .go: return GoGenerator.generate(request, options: options)
        case .php: return PHPGenerator.generate(request, options: options)
        case .swift: return SwiftGenerator.generate(request, options: options)
        }
    }

    /// Notes rendered as comments, followed by a blank line.
    static func noteComments(_ notes: [String], prefix: String) -> String {
        notes.isEmpty ? "" : notes.map { "\(prefix) Note: \($0)" }.joined(separator: "\n") + "\n\n"
    }
}
