# Development

## Requirements

- macOS 13 or later
- Swift 5.9+: either the **Command Line Tools** (`xcode-select --install`) or Xcode.
  The project is plain `swiftc` + shell scripts, so Xcode is not required.
- Optional, for syntax-checking generated code: `python3`, `node`, `ruby`, `cargo`,
  `dotnet`, `php`, `gofmt`, `javac` (missing ones are skipped)

## Build and run

```bash
./build.sh             # -> build/CurlToCode.app
open build/CurlToCode.app
./build.sh --install   # also copies the app to /Applications
```

`build.sh`:
1. Compiles `Sources/Core` and `Sources/App` with `swiftc -O -parse-as-library` for
   `arm64` and `x86_64` (minimum macOS 13), then merges them with `lipo` into a universal
   binary.
2. Renders the app icon with `Scripts/make-icon.swift` and converts it with `iconutil`.
3. Writes `Info.plist` (bundle id `com.example.curltocode`; the version is set in the
   script).
4. Ad-hoc signs the bundle (`codesign --sign -`).

You can also launch `build/CurlToCode.app/Contents/MacOS/CurlToCode` directly; the app
delegate makes it a regular foreground app.

## UI snapshots

```bash
./Scripts/snapshot.sh   # -> build/snapshots/*.png
```

Renders the main window (light and dark; Python, Rust, empty and error states), the
splash screen and the Help window offscreen with `NSHostingView.cacheDisplay`. It needs
no screen-recording permission, so it's useful for checking UI changes from the command
line. It compiles every app source except `CurlToCodeApp.swift` together with
`Scripts/snapshot.swift`, which has its own `@main`. Run `./build.sh` first so it can
borrow the real app icon.

## Packaging

```bash
./Scripts/package.sh    # -> dist/CurlToCode-<version>.pkg and .dmg
```

- **`.pkg`:** `pkgbuild` builds a component with `BundleIsRelocatable = false`, so it
  always installs to `/Applications` rather than to wherever an older copy lives. Then
  `productbuild` wraps it with a distribution file:
  - `Installer/welcome.html` and `Installer/conclusion.html` pages
  - light/dark background art from `Scripts/make-installer-art.swift`
  - a macOS 13 minimum, and arm64 + x86_64 host architectures
- **`.dmg`:** the app plus an `Applications` symlink, with a custom volume icon,
  compressed as UDZO.

Extended attributes are stripped before packaging. (`com.apple.provenance` is
system-managed and can't be removed; Installer restores it as an attribute, so the `._`
entries it leaves in the pkg payload are harmless.)

**Signing for distribution.** Set these before running the script:

```bash
export DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
export DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"
export NOTARY_PROFILE=my-profile   # xcrun notarytool store-credentials my-profile …
```

The app is then signed with the hardened runtime, the pkg is signed, and both artifacts
are notarized and stapled. Without these, everything is ad-hoc signed: fine locally,
blocked by Gatekeeper on other Macs until the user chooses right-click ▸ Open.

To change the version, edit `CFBundleShortVersionString` / `CFBundleVersion` in
`build.sh`. `package.sh` reads it from the built app.

## Testing

XCTest and Swift Testing ship only with full Xcode, not with the Command Line Tools. So
the project uses a tiny XCTest-style kit that builds with plain `swiftc`.

```
Tests/
  Support/TestKit.swift       test kit: suites, expect… assertions, runner
  Unit/main.swift             registers every suite and runs them
  Unit/<Component>Tests.swift unit tests per component
  Integration/main.swift      end-to-end curl → code cases for every language
```

- **Unit tests** cover each component in isolation:
  - `ShellTokenizer`, `JSONParser`, `CurlParser`, `ResolvedRequest`, `Literals`,
    `Language`
  - each language generator, fed a hand-built `ResolvedRequest` (`makeRequest` in
    `GeneratorTestSupport.swift`) so it's tested without the parser
  - `ConverterModel`, `SyntaxHighlighter` and `Theme` (app layer). The model takes a
    throwaway `UserDefaults` suite, so tests never change your real settings.

  Assertions are `expectEqual`, `expectTrue`, `expectFalse`, `expectNil`,
  `expectContains`, `expectNotContains`, `expectPairs` (ordered key/value pairs) and
  `expectThrows`; `unwrap` returns an optional's value or stops the test, and `fail`
  records a failure. Failures report `file:line`.
- **Integration tests** convert a set of representative commands into every language:
  - JSON, forms, multipart, cookies, auth, proxy, timeouts
  - custom methods, HEAD, `-G`
  - tricky quoting and Unicode
  
  They check key snippets and write every output to `build/test-output/<language>/`.
  `test.sh` then checks those files with the real toolchains:

  | Language | Check |
  |---|---|
  | Python | `ast.parse` |
  | JavaScript | `node --check` |
  | Ruby | `ruby -c` |
  | Swift | `swiftc -typecheck` |
  | Rust | `cargo check` against reqwest, all files as bins of one project |
  | C# | `dotnet build` of a scratch console project |
  | PHP | `php -l` |
  | Go | `gofmt -e` |
  | Java | `javac` |

  Missing toolchains are reported as skipped.

```bash
./test.sh                    # unit tests, then integration + syntax checks
./test.sh --unit             # unit tests only (fast)
./build/unit-tests Literals  # after a run: only suites whose name contains "Literals"
```

`test.sh` exits non-zero if any test or syntax check fails. Set `REQUIRE_ALL_TOOLCHAINS=1`
to make a missing toolchain fail the run instead of being skipped.

### Continuous integration

`.github/workflows/tests.yml` runs on every push to `main`, on pull requests, and on demand
(**Actions ▸ Tests ▸ Run workflow**). It uses a `macos-15` runner and two jobs:

- **Unit + integration tests:** installs Python, Node, Go, Java (JDK 21), .NET 8 and PHP
  (Ruby and Rust come with the runner), then runs `./test.sh` with
  `REQUIRE_ALL_TOOLCHAINS=1`. So in CI the generated code is checked for **all nine**
  languages, including Go (`go build`), PHP and Java, which may be skipped locally. If it
  fails, the generated files are uploaded as the `generated-code` artifact.
- **Build app and installers:** runs `Scripts/package.sh` and uploads the `.pkg` and `.dmg`
  as the `installers` artifact (kept 14 days).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Editor shows "Cannot find 'X' in scope" everywhere | SourceKit has no project file describing the module. Harmless: `swiftc` sees all files together. |
| `ld: warning: ignoring file …libswiftCompatibilityPacks.a: fat file missing arch 'x86_64'` | The Command Line Tools ship that library for arm64 only. Harmless for this app: the x86_64 slice doesn't need it. |
| `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found` | You used `@State` (or another SwiftUI macro). Its plugin isn't in the Command Line Tools. Use `ObservableObject` + `@StateObject`/`@ObservedObject`, as `ConverterModel` does. |
| `xattr: option -r not recognized` / printed help in `package.sh` | A pyenv or Homebrew `xattr` shadows the system one. The script calls `/usr/bin/xattr`; do the same in your own commands. |
| `swift test` fails ("Could not initialize build system" / "no such module XCTest") | Expected with the Command Line Tools only. Use `./test.sh`. |
| Can't screenshot the running app from a script | Use `./Scripts/snapshot.sh` instead; it needs no screen-recording permission. |
