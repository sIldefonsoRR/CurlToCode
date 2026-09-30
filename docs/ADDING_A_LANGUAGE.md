# Adding a language

A generator only decides how to express a `ResolvedRequest` in the target language. curl
parsing and semantics are already done (see [ARCHITECTURE.md](ARCHITECTURE.md)). This
walkthrough uses Kotlin (OkHttp) as the example.

## 1. Register the language (`Sources/Core/Language.swift`)

Add a case and fill in every `switch` (the compiler flags any you miss):

```swift
enum Language: String, CaseIterable, Identifiable {
    case python, javascript, csharp, ruby, java, rust, go, php, swift, kotlin
```

| Property | Example | Notes |
|---|---|---|
| `displayName` | `"Kotlin"` | Chip and menu label |
| `library` | `"OkHttp"` | Shown under the card title |
| `fileExtension` | `"kt"` | Used by Save… |
| `defaultFileName` | `"Main.kt"` | Only if `request.<ext>` isn't a good default |
| `lineComment` | `"//"` | Used for `Note:` comments and highlighting |
| `keywords` | `["import", "val", "fun", …]` | Highlighted in the output pane |
| `supportsParamsSplit` | `false` | Only Python supports the params option |

The raw value (`"kotlin"`) is persisted in UserDefaults, so don't rename it later.

Then route it in `CodeGenerator.generate`:

```swift
case .kotlin: return KotlinGenerator.generate(request, options: options)
```

**Shortcuts:** the Language menu gives ⌘1–⌘9 to the first nine cases. A tenth language
appears in the menu and chips without a number shortcut
(`KeyEquivalent(Character("10"))` isn't valid). Change `LanguageMenuItems` in
`CurlToCodeApp.swift` if you want one, for example ⌘0.

## 2. Write the generator (`Sources/Core/Generators/KotlinGenerator.swift`)

```swift
import Foundation

/// Kotlin using OkHttp.
enum KotlinGenerator {
    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.java              // Kotlin strings escape like Java's; or add Literals.kotlin
        var notes = r.notes
        var lines: [String] = []

        lines.append("val client = OkHttpClient()")

        // Body
        var body = "null"
        switch r.body {
        case .none: break
        case .json(let value):
            body = "\(str(Literals.jsonText(value))).toRequestBody()"
        case .form(_, let encoded):
            body = "\(str(encoded)).toRequestBody()"
        case .raw(let text):
            body = "\(str(text)).toRequestBody()"
        case .file(let path):
            body = "File(\(str(path))).asRequestBody()"
        }
        if !r.formFields.isEmpty {
            notes.append("Multipart form data not generated yet for Kotlin.")
        }

        // Request
        lines.append("val request = Request.Builder()")
        lines.append("    .url(\(str(r.url)))")
        for (name, value) in r.explicitHeaders {     // cookies + implied Content-Type included
            lines.append("    .header(\(str(name)), \(str(value)))")
        }
        if let token = r.basicAuthToken {
            lines.append("    .header(\"Authorization\", \(str("Basic " + token)))")
        }
        lines.append("    .method(\(str(r.method)), \(body))")
        lines.append("    .build()")

        lines.append("")
        lines.append("client.newCall(request).execute().use { response ->")
        if options.includePrint {
            lines.append("    println(response.code)")
            lines.append("    println(response.body?.string())")
        }
        lines.append("}")

        if r.insecure { notes.append("-k/--insecure not applied.") }
        if let proxy = r.proxy { notes.append("Proxy \(proxy) not applied.") }
        if r.timeout != nil { notes.append("Timeout not applied.") }

        return CodeGenerator.noteComments(notes, prefix: "//")
            + "import okhttp3.*\n\n" + lines.joined(separator: "\n") + "\n"
    }
}
```

Guidelines, all followed by the existing generators:

- **Handle every `Body` case and `formFields`.** If the language can't express
  something, add a note instead of dropping it silently.
- **Use `explicitHeaders`** unless the library has dedicated cookie/param/form APIs you
  use instead, as Python does with `cookies`, `headers` and `urlAndParams`.
- **Escape every string literal** with the matching `Literals` function. Add one to
  `Literals.swift` if the language's escaping differs; watch for interpolation (`$`,
  `#{}`, `\(`) and for escapes processed before lexing, like Java's `\u`.
- **For JSON bodies,** prefer native data (`Literals.render` with a `Literals.Style`) or a
  raw multi-line string of `Literals.jsonText(value)`. Fall back to an escaped string
  when the text would clash with the raw delimiter.
- **Respect `options.includePrint`,** and keep the output compilable without it (Go
  refuses unused variables and imports).
- **Only add imports that are used.**

## 3. App colour (`Sources/App/Theme.swift`)

Add the brand colour to `Language.color`:

```swift
case .kotlin: return Color(nsColor: NSColor(hex: 0x7F52FF))
```

If the colour is light, update `onColor` so chip text stays readable (JavaScript's yellow
uses black text).

## 4. Tests

- **Unit:** add `Tests/Unit/KotlinGeneratorTests.swift`, modelled on an existing generator
  suite, and register it in `Tests/Unit/main.swift`. Cover at least:
  - a simple GET
  - a JSON body
  - form data
  - multipart (or its note)
  - basic auth
  - a custom method
  - HEAD
  - escaping of quotes, backslashes and `$`
  - `includePrint: false`
- **Integration:** `Tests/Integration/main.swift` generates every sample for every
  `Language.allCases` automatically. Add a `.kotlin: [sampleName: [snippets]]` entry to
  `expectations` for the key idioms.
- **Syntax check:** in `test.sh`, add a block like the others, e.g.
  `if command -v kotlinc …; then check_each kotlin kt kotlinc_check; else skip kotlin kotlinc; fi`.

Run `./test.sh` and make sure the new language's files are reported as valid.

## 5. Docs and help

- `Sources/App/HelpView.swift`: the language list is generated from `Language.allCases`,
  so only update the "Turn curl commands into code for nine languages" wording.
- `Sources/App/SplashView.swift`: the chips are generated automatically.
- `Installer/welcome.html`: add the language chip.
- `README.md` and `docs/USER_GUIDE.md`: add the language to the tables, including
  requirements and any unsupported features.
- `CHANGELOG.md`: add an entry.
