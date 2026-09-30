# cURL to Code: User Guide

cURL to Code turns a `curl` command into ready-to-run code in nine languages. Paste a
command, pick a language, copy the result.

- [Installing](#installing)
- [The window](#the-window)
- [Converting a command](#converting-a-command)
- [Languages](#languages)
- [Options](#options)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Supported curl options](#supported-curl-options)
- [What gets changed or left out](#what-gets-changed-or-left-out)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)

## Installing

You need macOS 13 Ventura or later. The app runs natively on Apple silicon and Intel Macs.

You can install it two ways:

| File | How |
|---|---|
| `CurlToCode-<version>.pkg` | Double-click and follow the Installer. It installs **cURL to Code** into `/Applications` and asks for an administrator password. |
| `CurlToCode-<version>.dmg` | Double-click to open the disk image, then drag **cURL to Code** onto the **Applications** shortcut. |

**"cURL to Code can't be opened" / "unidentified developer".** Unless your copy was signed
with an Apple Developer ID and notarized, macOS blocks it the first time. Right-click (or
Control-click) the app in Applications, choose **Open**, then **Open** again. Or go to
**System Settings ▸ Privacy & Security** and click **Open Anyway**. You only need to do
this once.

## The window

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●  [icon] cURL to Code          (Python)(JavaScript)(C#)(Ruby)…(Swift)     │  header
│ ┌─ cURL command ─── [Open…][Paste][×] ┐    ┌─ Python · requests ── [Save…][Copy] ┐
│ │ 1  curl 'https://…' \               │ →  │ 1  import requests                  │
│ │ 2    -H 'Accept: …'                 │    │ 2                                   │
│ └─────────────────────────────────────┘    └─────────────────────────────────────┘
│ (✓ Converted to Python) (2 notes)          ☑ Query string → params ☑ Print response │  status bar
└────────────────────────────────────────────────────────────────────────────────┘
```

- **Language chips** (top right): the output language. The selected chip is filled in
  that language's colour. Your choice is remembered next time.
- **cURL command** (left): where the command goes. It has line numbers and colours
  `curl`, options, quoted text and URLs. The subtitle shows the line count, or the file
  name if you opened one.
  - **Open…** loads a command from a file.
  - **Paste** replaces the input with the clipboard.
  - **×** clears it.
  
  In a narrow window these buttons become icons only.
- **Output card** (right): the generated code, with line numbers and syntax colouring.
  The subtitle shows the library used and the number of lines. The code updates as you
  type.
  - **Copy** puts the code on the clipboard. It briefly changes to *Copied*.
  - **Save…** writes it to a file with the right extension, such as `request.py`,
    `Main.java`, `main.rs` or `Program.cs`.
- **Arrow** between the cards: turns the language's colour when the conversion succeeds.
- **Status bar**:
  - *Converted to …* when the conversion works.
  - *N notes* when some parts couldn't be converted exactly. Details are in `Note:`
    comments at the top of the code.
  - The error message when conversion fails.
  - *Waiting for input* when the input is empty.

**Empty input** shows a welcome panel in the output card with **Paste**, **Open File…**
and **Try an Example** (loads a sample command).

**A command that can't be parsed** (for example one with an unclosed quote) shows
*Can't convert this yet* and the reason.

A splash screen appears for about two seconds at launch. Click it to skip.

## Converting a command

1. Get a curl command:
   - **From a browser:** open the developer tools (⌥⌘I in Chrome, Edge and Firefox;
     in Safari, enable *Show features for web developers* first). Go to the
     **Network** tab, right-click a request and choose
     **Copy ▸ Copy as cURL (bash)**. On Windows builds of Chrome, pick the *bash* variant,
     not *cmd*.
   - **From documentation or a terminal:** copy it as is. A leading `$ ` prompt is fine.
2. Paste it into the left pane (⌘V, or ⇧⌘V to replace everything), or use
   **File ▸ Open cURL File…** (⌘O).
3. Pick a language with the chips or ⌘1–⌘9.
4. **Copy** (⇧⌘C) or **Save…** (⌘S).

### Loading from a file

**File ▸ Open cURL File…** accepts any text file, such as `.txt`, `.sh` or `.curl`, up to
5 MB. Shell comments (`#` to end of line, including a `#!/bin/bash` shebang) are ignored,
so a script that holds one curl command loads cleanly. Only the first curl command is
converted: extra URLs are reported in a note.

## Languages

| # | Language | Library / API | Requirements for the generated code |
|---|---|---|---|
| ⌘1 | Python | `requests` | `pip install requests` |
| ⌘2 | JavaScript | `fetch` | Node.js 18+ or a browser. The code uses top-level `await` and `import`, so save it as an ES module (`.mjs`, which Save… uses). |
| ⌘3 | C# | `HttpClient` | .NET 6+ with top-level statements. JSON bodies use C# 11 raw string literals (.NET 7+). |
| ⌘4 | Ruby | `Net::HTTP` | Standard library only |
| ⌘5 | Java | `java.net.http` | Java 15+ (text blocks). Save as `Main.java` and run `java Main.java`. |
| ⌘6 | Rust | `reqwest` (blocking) | Add the crate with the features listed in the comment at the top, e.g. `reqwest = { version = "0.12", features = ["blocking"] }` (plus `"multipart"` for form uploads). |
| ⌘7 | Go | `net/http` | Standard library only |
| ⌘8 | PHP | curl extension | `ext-curl`. JSON bodies use nowdoc syntax, which needs PHP 7.3+. |
| ⌘9 | Swift | `URLSession` | Swift 5.7+ script (`main.swift`, top-level `await`) |

JSON bodies become native data where that's natural: a Python `dict`, a JavaScript object
passed to `JSON.stringify`, a Ruby hash with `.to_json`. Elsewhere they become a formatted
JSON string. Key order always matches the original.

## Options

In the status bar:

- **Query string → params** (Python only; greyed out for other languages): moves the
  URL's query string into a `params` dict (`?q=1&page=2` → `params = {'q': '1', 'page': '2'}`).
  Repeated keys become a list of tuples so none are lost.
- **Print response**: ends the code by printing the status code and the response body.
  Turn it off to get just the request.

Both settings are remembered.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘O | Open a curl command from a file |
| ⇧⌘V | Replace the input with the clipboard |
| ⇧⌘C | Copy the generated code |
| ⌘S | Save the generated code |
| ⌘1 … ⌘9 | Switch output language (order as in the table above) |
| ⌘? | Open the Help window |

The **Language** menu lists every language with a checkmark on the current one. The
**Help** menu opens **cURL to Code Help**, a summary of this guide.

## Supported curl options

| Area | Options |
|---|---|
| Method | `-X/--request`, `-I/--head`, `-G/--get` |
| Headers | `-H/--header`, `-A/--user-agent`, `-e/--referer`, `--oauth2-bearer` |
| Body | `-d/--data`, `--data-ascii`, `--data-raw`, `--data-binary`, `--data-urlencode`, `--json`; `@file` reads the body from a file (except with `--data-raw`) |
| Multipart forms | `-F/--form` (`name=value`, `name=@file` upload, `name=<file` file contents as text), `--form-string` |
| Cookies | `-b/--cookie "a=1; b=2"`, or a `Cookie:` header |
| Auth | `-u/--user user:password` (HTTP Basic) |
| Network | `-k/--insecure`, `-x/--proxy`, `-m/--max-time`, `--connect-timeout` |
| URL | positional URL or `--url`; a URL without a scheme gets `http://`, as with curl |

Also understood:
- Combined short flags (`-sSL`) and attached values (`-XPOST`, `-HAccept:x`).
- `--option=value`.
- Single and double quotes, `$'…'` ANSI-C quotes (what browsers produce), backslash line
  continuations and Windows line endings.

Options that don't change the request are dropped silently: `-s`, `-S`, `-v`, `-L`, `-i`,
`-o`, `--compressed`, `-w`, and similar. Other unsupported options are dropped with a note.

How curl's behaviour is reproduced:
- `-d` implies POST and a `Content-Type: application/x-www-form-urlencoded` header when
  none is given.
- Several `-d` values are joined with `&`.
- `-G` moves the data into the query string.
- `--json` adds JSON `Content-Type` and `Accept` headers.

## What gets changed or left out

Everything below is also stated in a `Note:` comment at the top of the generated code.

**Always left out:**
- `Accept-Encoding` and `Content-Length`. Every HTTP library sets these itself, and
  copying a browser's `Accept-Encoding: gzip, br, zstd` can produce compressed responses
  the library doesn't decode.
- A `Content-Type: multipart/form-data; boundary=…` header when `-F` fields are present.
  The library generates its own boundary, and a copied one wouldn't match.

**Not supported in some languages:**

| Feature | Not applied in | What to do |
|---|---|---|
| `-F` multipart uploads | Java | Use OkHttp or Apache HttpClient |
| `-k/--insecure` | Java, Swift, JavaScript | Java: custom `SSLContext`. Swift: a `URLSessionDelegate`. Node: `NODE_TLS_REJECT_UNAUTHORIZED=0` (unsafe). |
| `-x/--proxy` | Swift, JavaScript | Swift: `connectionProxyDictionary`. Node: undici `ProxyAgent`. |
| `Host`, `Connection`, `Expect`, `Upgrade` headers | Java | `java.net.http` refuses to set them |
| `-b cookies.txt` (cookie *file*) | all | Load the file in code if needed |

## Troubleshooting

| Problem | Fix |
|---|---|
| *Command must start with "curl"* | Make sure you copied the whole command. Remove anything before `curl` apart from a `$ ` prompt. |
| *Unterminated ' quote in command* | The command was cut off, or contains a `'` inside single quotes. Check the end of the paste. |
| *No URL found* | The URL is missing, or it was swallowed as the value of an option. Check for an option missing its value. |
| Browser copy converts but the request fails | You probably copied *Copy as cURL (cmd)* or *(PowerShell)*. Use the **bash** variant. |
| Garbled response in the generated code | Make sure you didn't add an `Accept-Encoding` header back by hand. |
| App won't open the first time | See [Installing](#installing) (right-click ▸ Open). |

## Uninstalling

Drag **cURL to Code** from Applications to the Trash. If you installed from the `.pkg`
and want to clear the installer's record too, run:

```bash
sudo pkgutil --forget com.example.curltocode
```

Your saved preferences (language and options) are in the
`com.example.curltocode` defaults domain. Remove them with
`defaults delete com.example.curltocode`.
