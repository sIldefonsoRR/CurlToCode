# cURL to Code

[![Tests](https://github.com/sIldefonsoRR/CurlToCode/actions/workflows/tests.yml/badge.svg)](https://github.com/sIldefonsoRR/CurlToCode/actions/workflows/tests.yml)

A native macOS app that turns a `curl` command into ready-to-run code in nine languages.
Paste a command (or open a file), pick a language, and copy or save the result. The code
updates as you type.

| Language | Library / API |
|---|---|
| Python | `requests` |
| JavaScript | `fetch` (browsers, Node 18+) |
| C# | `HttpClient` (.NET 6+) |
| Ruby | `Net::HTTP` |
| Java | `java.net.http` (Java 15+) |
| Rust | `reqwest` (blocking) |
| Go | `net/http` |
| PHP | curl extension |
| Swift | `URLSession` |

It handles what browsers produce with **Copy as cURL (bash)**:
- headers, cookies, JSON and form bodies
- multipart uploads, basic auth, proxy, timeouts
- `$'…'` quoting and line continuations

## Download

Latest version: **[2.0](https://github.com/sIldefonsoRR/CurlToCode/releases/tag/v2.0)**. Needs macOS 13 or later; runs natively on Apple silicon and Intel.

| Download | How to install |
|---|---|
| [**CurlToCode-2.0.pkg**](https://github.com/sIldefonsoRR/CurlToCode/releases/download/v2.0/CurlToCode-2.0.pkg) | Installer wizard that puts the app in Applications |
| [**CurlToCode-2.0.dmg**](https://github.com/sIldefonsoRR/CurlToCode/releases/download/v2.0/CurlToCode-2.0.dmg) | Open it and drag **cURL to Code** onto Applications |

[SHA-256 checksums](https://github.com/sIldefonsoRR/CurlToCode/releases/download/v2.0/SHA256SUMS.txt) · [All releases](https://github.com/sIldefonsoRR/CurlToCode/releases)

> [!IMPORTANT]
> The app isn't signed with an Apple Developer ID, so macOS blocks it the first time. Right-click the
> installer (or the app, after installing) and choose **Open**, or allow it in
> **System Settings ▸ Privacy & Security**.

## Build from source

Needs the Command Line Tools or Xcode:

```bash
./build.sh                 # -> build/CurlToCode.app (universal)
open build/CurlToCode.app
./test.sh                  # unit + integration tests, syntax-checks generated code
./Scripts/package.sh       # -> dist/*.pkg and dist/*.dmg
```

## Documentation

| Document | For |
|---|---|
| [User Guide](docs/USER_GUIDE.md) | Using the app: window, languages, options, shortcuts, supported curl options, limitations, troubleshooting |
| [Architecture](docs/ARCHITECTURE.md) | How the conversion pipeline and the app are built, and why |
| [Development](docs/DEVELOPMENT.md) | Building, testing, UI snapshots, packaging, signing, troubleshooting |
| [Adding a Language](docs/ADDING_A_LANGUAGE.md) | Step-by-step guide for a new generator |
| [Changelog](CHANGELOG.md) | Release history |

## Project layout

```
Sources/Core/             curl → code conversion (no UI): tokenizer, parser, JSON,
                          ResolvedRequest, Literals, Language
Sources/Core/Generators/  one generator per language
Sources/App/              SwiftUI/AppKit app: windows, editor, theme, splash, help
Tests/                    unit tests, integration tests, test kit
Scripts/                  icon / installer art generators, package.sh, snapshot.sh
Installer/                welcome and finish pages for the .pkg
docs/                     documentation
```
