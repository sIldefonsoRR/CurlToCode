# Changelog

## 2.0 — 2026-09-29

Renamed from **cURL to Python** to **cURL to Code**.

### Added
- Output in nine languages:

  | Language | Library / API |
  |---|---|
  | Python | `requests` |
  | JavaScript | `fetch` |
  | C# | `HttpClient` |
  | Ruby | `Net::HTTP` |
  | Java | `java.net.http` |
  | Rust | `reqwest` |
  | Go | `net/http` |
  | PHP | curl extension |
  | Swift | `URLSession` |

- Language chips in the window header and a **Language** menu (⌘1–⌘9). The choice is
  remembered.
- **File ▸ Open cURL File…** (⌘O) loads a command from a text or shell file. `#` comments
  and shebangs are ignored.
- Splash screen at launch (click to skip).
- **Help ▸ cURL to Code Help** (⌘?) window.
- Installers: a `.pkg` (Installer wizard with welcome and finish pages) and a `.dmg`
  (drag to Applications), built by `Scripts/package.sh`, with optional Developer ID
  signing and notarization.
- Unit and integration test suites. Generated code is syntax-checked with each
  language's own toolchain.

### Changed
- Redesigned interface:
  - rounded input and output cards, with an arrow between them in the language colour
  - line numbers and Xcode-style highlighting, including the curl input, in light and
    dark mode
  - status pills with a count of notes
  - empty-state panel with **Paste**, **Open File…** and **Try an Example**
  - error panel explaining why a command can't be converted
  - hidden title bar
- `Accept-Encoding` and `Content-Length` headers are now left out, and so is a copied
  multipart `Content-Type` when `-F` is used. Each removal is explained in a `Note:`
  comment.
- The shell tokenizer now ignores `#` comments.

## 1.0 — 2026-09-29

First release as **cURL to Python**.

- Converts curl commands to Python `requests` code as you type.
- Supports:
  - methods, headers, cookies
  - JSON (key order preserved), form, raw and file bodies
  - multipart forms, `-G`, basic auth, `-k`, proxy and timeouts
- Handles bash quoting (`'…'`, `"…"`, `$'…'`), line continuations, combined short flags
  and `--opt=value`.
- Options: query string → `params` dict, print response.
- Copy (⇧⌘C), Save as `.py` (⌘S) and Paste (⇧⌘V).
