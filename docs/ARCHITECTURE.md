# Architecture

cURL to Code is a native SwiftUI/AppKit app built from plain Swift files with `swiftc`
(no Xcode project). The conversion logic (`Sources/Core`) has no UI dependencies. The app
(`Sources/App`) is a thin layer on top of it.

## Conversion pipeline

```
 "curl 'https://…' -H 'A: b' -d x=1"
            │
            ▼
 ┌──────────────────────┐   bash quoting rules: '…', "…", $'…', \ escapes,
 │ ShellTokenizer       │   \⏎ continuations, # comments
 └──────────┬───────────┘
            │ [String] tokens
            ▼
 ┌──────────────────────┐   curl option table: short/long flags, combined -sSL,
 │ CurlParser           │   attached values -XPOST, --opt=value
 └──────────┬───────────┘
            │ CurlRequest  (options as written, + warnings)
            ▼
 ┌──────────────────────┐   curl semantics: default scheme, method inference,
 │ ResolvedRequest      │   JSON / form / raw / file body, -G, cookies, auth,
 │   .resolve()         │   dropped headers, multipart fields  (uses JSONParser)
 └──────────┬───────────┘
            │ ResolvedRequest  (language-neutral request + notes)
            ▼
 ┌──────────────────────┐   PythonGenerator, JavaScriptGenerator, CSharpGenerator,
 │ <Language>Generator  │   RubyGenerator, JavaGenerator, RustGenerator,
 │   .generate()        │   GoGenerator, PHPGenerator, SwiftGenerator  (use Literals)
 └──────────┬───────────┘
            ▼
       source code (String)
```

`CodeGenerator.generate(_:language:options:)` in `Language.swift` runs the whole chain
and is the only entry point the app uses.

## Folder map

```
Sources/Core/
  ShellTokenizer.swift      command line → tokens
  CurlParser.swift          tokens → CurlRequest; CurlParseError
  JSONParser.swift          order-preserving JSON → JSONValue
  ResolvedRequest.swift     CurlRequest → ResolvedRequest (curl semantics)
  Literals.swift            per-language string escaping, JSON → native literal rendering
  Language.swift            Language enum (names, extensions, keywords…), GeneratorOptions,
                            CodeGenerator entry point
  Generators/               one file per language, each `enum XGenerator { static func generate }`
Sources/App/
  CurlToCodeApp.swift       @main App: main Window, Help Window, menu commands, AppDelegate
  ConverterModel.swift      ObservableObject with the app state and actions
  ContentView.swift         main window layout, LanguageChips, StatusPill, empty/error states
  CodeTextView.swift        NSTextView wrapper, LineNumberRuler, SyntaxHighlighter
  Theme.swift               CodeTheme colours/fonts, Language.color, Card, IconBadge
  SplashView.swift          launch splash overlay
  HelpView.swift            Help window content
```

## Core types

| Type | Responsibility |
|---|---|
| `ShellTokenizer` | Splits a command line like bash does. Throws `ShellTokenizerError.unterminatedQuote`. |
| `CurlRequest` | The parsed command: URL, method, headers, data parts (with which option supplied each), form parts, user, cookie, flags, warnings. Nothing is interpreted yet. |
| `CurlParser` | Knows curl's option table: `valueOptions` (take an argument), `shortOptions` (letter → long name), `ignoredFlags` (dropped silently). Unknown options become warnings. |
| `JSONValue` / `JSONParser` | JSON as an enum whose objects are `[(String, JSONValue)]`, so key order survives. Numbers are kept as the original text. |
| `ResolvedRequest` | The request curl would actually send, in a form every generator can use. See below. |
| `Literals` | String escaping for each language and `render(_:style:)`, which prints a `JSONValue` as a Python dict, JavaScript object, Ruby hash or JSON text. |
| `Language` | Display name, library, file extension, default file name, comment prefix, highlight keywords, `supportsParamsSplit`. |
| `GeneratorOptions` | `splitQueryParams` (Python) and `includePrint`. |

### ResolvedRequest

`resolve(_:)` reproduces curl's behaviour once, so no generator has to:

- **URL:** adds `http://` if there's no scheme and strips the `#fragment`. The query string
  is decoded into `queryPairs` when possible, and `-G` data goes into `getPairs`. `url`
  gives the full URL. `urlAndParams(split:)` gives a base URL plus params, for Python.
- **Method:** `-X` wins, then `-I` → HEAD, `-G` → GET, any body → POST, otherwise GET.
- **Body** (`Body` enum):
  - `.json(JSONValue)` when the Content-Type mentions json (or `--json` was used) and the
    data parses as JSON.
  - `.form(pairs, encoded:)` when there's no Content-Type (or it's urlencoded) and the
    data looks like `a=1&b=2`.
  - `.file(path)` for `-d @file`.
  - `.raw(text)` otherwise.
- **Multipart:** `formFields` holds `.text`, `.file` (`@path`) and `.fileContents`
  (`<path`) entries.
- **Headers:** `Cookie` headers and `-b` go into `cookies`. `Accept-Encoding` and
  `Content-Length` are dropped, and so is a multipart `Content-Type` when `-F` is used.
  Each drop adds a note.
- **`explicitHeaders`:** `headers`, plus a merged `Cookie` header, plus curl's implied
  `application/x-www-form-urlencoded` Content-Type. For clients that send only what
  they're told (fetch, HttpClient, reqwest, net/http…).
- **`notes`:** the parser's warnings plus resolution notes. Generators add
  language-specific ones and print them as `Note:` comments.

## Design decisions

- **Language-neutral middle layer.** curl semantics live in one place (`ResolvedRequest`),
  so each generator only decides how to express the request idiomatically. Adding a
  language doesn't touch the parser.
- **Python uses the structure, others use explicit headers.** `requests` has dedicated
  `params=`, `cookies=`, `json=` and `data=` arguments, so the Python generator reads
  `cookies`/`headers`/`urlAndParams` directly. The other generators use `explicitHeaders`
  and the full `url`.
- **Order-preserving JSON.** `JSONSerialization` loses key order, which makes the output
  differ from what users pasted. `JSONParser` is ~200 lines and keeps it.
- **Escaping per language** (`Literals`):
  - Python and JavaScript use single quotes, switching to double quotes when the text
    contains `'` but no `"` (like Python's `repr`).
  - Ruby and PHP use single quotes (no interpolation) unless there are control
    characters. Then they use escaped double quotes, with `#` and `$` escaped.
  - Java escapes control characters as **octal**. Java processes `\uXXXX` escapes before
    lexing, so `\u000a` inside a string literal would become a real newline and break
    the code.
- **Multi-line JSON bodies use each language's raw strings:**

  | Language | Form |
  |---|---|
  | C# | `"""…"""` raw literal |
  | Java | text block (backslashes and `"""` escaped) |
  | Rust | `r#"…"#` with enough `#`s |
  | Go | backticks (JSON only; raw text bodies stay escaped because indentation would change them) |
  | PHP | `<<<'JSON'` nowdoc |
  | Swift | `#"""…"""#` |

  Each falls back to an escaped string if the text would clash with the delimiter.
- **Output stays syntactically valid.** Every generator's output is compiled or parsed by
  the real toolchain in the integration tests (see [DEVELOPMENT.md](DEVELOPMENT.md)).

## App layer

- **`ConverterModel`** (ObservableObject) holds the input, language, options, splash and
  "copied" state, and the actions (paste, copy, open, save, load example). The code is
  computed from it on each render; conversion is cheap. Preferences go to `UserDefaults`
  (`language`, `splitQueryParams`, `includePrint`). It's an `ObservableObject` shared via
  `@StateObject`/`environmentObject`, not `@State`: in recent SDKs `@State` is a macro
  whose compiler plugin ships only with Xcode, not with the Command Line Tools this
  project builds with.
- **`CodeTextView`** wraps `NSTextView` instead of SwiftUI's `TextEditor` so smart quotes,
  smart dashes and text replacement can be turned off. Those would silently corrupt pasted
  shell commands. It re-highlights on every edit and keeps the selection when the text is
  replaced.
- **`LineNumberRuler`** (`NSRulerView`) draws only the numbers for visible lines. It
  overrides `draw(_:)` so AppKit's default ruler border can't bleed outside the gutter.
- **`SyntaxHighlighter`** applies small regex rule sets (cached per language), one set for
  the curl input and one per output language. Generated code only has whole-line
  comments, so only those are matched as comments, and `#` or `//` inside strings and
  URLs stay intact.
- **`Theme.swift`**:
  - `CodeTheme` holds adaptive light/dark editor colours modelled on Xcode.
  - `Language.color` gives the brand colours used for chips, badges and the arrow.
  - `Card` and `IconBadge` are the rounded card and header badge.
- **Windows and menus:**
  - The main `Window` uses `.windowStyle(.hiddenTitleBar)`. The header leaves room on the
    left for the red/yellow/green window buttons.
  - A separate `Window` holds Help.
  - Commands: File ▸ Open (⌘O) and Save (⌘S), Edit ▸ Paste cURL (⇧⌘V) and Copy Code
    (⇧⌘C), a **Language** menu (⌘1–⌘9) and Help (⌘?).
  - Menu items that need the environment (`openWindow`) or live state are small `View`s.
- **Splash:** `SplashView` is an overlay in `ContentView`. It fades after 2 s or on click.
