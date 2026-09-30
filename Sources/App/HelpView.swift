import SwiftUI

/// Help window opened from Help ▸ cURL to Code Help.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("cURL to Code Help").font(.title.bold())
                        Text("Turn curl commands into code for nine languages.")
                            .foregroundStyle(.secondary)
                    }
                }

                section("Getting started", items: [
                    "Paste a curl command into the **cURL command** pane on the left, or load one with **File ▸ Open cURL File…** (⌘O).",
                    "The code appears on the right as you type. Pick the output language with the chips at the top of the window, or from the **Language** menu (⌘1–⌘9).",
                    "**Copy** (⇧⌘C) puts the code on the clipboard. **Save…** (⌘S) writes it to a file.",
                    "Tip: in Chrome, Edge, Safari or Firefox developer tools, right-click a request ▸ **Copy ▸ Copy as cURL (bash)** and paste it here.",
                ])

                VStack(alignment: .leading, spacing: 8) {
                    Text("Languages").font(.title3.bold())
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        ForEach(Array(Language.allCases.enumerated()), id: \.element) { index, language in
                            GridRow {
                                Text("⌘\(index + 1)").monospaced().foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Circle().fill(language.color).frame(width: 8, height: 8)
                                    Text(language.displayName).bold()
                                }
                                Text(language.library).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                section("Supported curl options", items: [
                    "**Method:** `-X/--request`, `-I/--head`, `-G/--get`",
                    "**Headers:** `-H`, `-A/--user-agent`, `-e/--referer`, `--oauth2-bearer`",
                    "**Body:** `-d/--data`, `--data-raw`, `--data-binary`, `--data-urlencode`, `--json`, and `@file` to read a body from a file",
                    "**Multipart forms:** `-F/--form` (with `@file` uploads and `<file` contents), `--form-string`",
                    "**Cookies:** `-b/--cookie` or a `Cookie:` header",
                    "**Auth and network:** `-u/--user`, `-k/--insecure`, `-x/--proxy`, `-m/--max-time`, `--connect-timeout`",
                    "Shell quoting: single and double quotes, `$'…'`, backslash line continuations and `#` comments.",
                ])

                section("Good to know", items: [
                    "Anything that can't be converted is listed as a **Note** comment at the top of the generated code.",
                    "JSON bodies become native objects where the language makes that natural (Python dicts, JavaScript objects, Ruby hashes); elsewhere they become a formatted JSON string.",
                    "`Accept-Encoding` and `Content-Length` headers are left out, because every HTTP library sets them itself.",
                    "**Query string → params** (Python only) moves the URL's query string into a `params` dict.",
                    "**Print response** adds lines that print the status code and response body.",
                    "Rust code needs the `reqwest` crate; the features to enable are listed in a comment at the top of the code.",
                ])

                section("Keyboard shortcuts", items: [
                    "**⌘O** Open a curl command from a file",
                    "**⇧⌘V** Replace the input with the clipboard",
                    "**⇧⌘C** Copy the generated code",
                    "**⌘S** Save the generated code",
                    "**⌘1–⌘9** Switch output language",
                    "**⌘?** Show this help",
                ])
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private func section(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold())
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").foregroundStyle(.secondary)
                    Text(LocalizedStringKey(item))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
