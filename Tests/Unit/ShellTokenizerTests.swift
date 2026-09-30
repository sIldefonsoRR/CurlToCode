import Foundation

let shellTokenizerTests = TestSuite("ShellTokenizer", [
    Test("splits on spaces, tabs and newlines") {
        expectEqual(try ShellTokenizer.tokenize("a  b\tc\nd"), ["a", "b", "c", "d"])
    },
    Test("returns no tokens for blank input") {
        expectEqual(try ShellTokenizer.tokenize("   \n\t "), [])
    },
    Test("single quotes keep everything literally") {
        expectEqual(try ShellTokenizer.tokenize(#"'a \n $HOME "b"'"#), [#"a \n $HOME "b""#])
    },
    Test("double quotes unescape only \\\" \\\\ \\$ and \\`") {
        expectEqual(try ShellTokenizer.tokenize(#""q\" b\\ d\$ t\` n\n""#), [#"q" b\ d$ t` n\n"#])
    },
    Test("double quotes don't expand variables") {
        expectEqual(try ShellTokenizer.tokenize(#""$HOME""#), ["$HOME"])
    },
    Test("$'…' decodes ANSI-C escapes") {
        expectEqual(try ShellTokenizer.tokenize(#"$'a\nb\tc\\d\'e'"#), ["a\nb\tc\\d'e"])
    },
    Test("$'…' decodes hex and unicode escapes") {
        expectEqual(try ShellTokenizer.tokenize(#"$'\x41é\U0001F600'"#), ["Aé😀"])
    },
    Test("$'…' keeps unknown escapes") {
        expectEqual(try ShellTokenizer.tokenize(#"$'\q'"#), [#"\q"#])
    },
    Test("adjacent quoted parts join into one token") {
        expectEqual(try ShellTokenizer.tokenize(#"'a'"b"c$'d'"#), ["abcd"])
    },
    Test("empty quotes make an empty token") {
        expectEqual(try ShellTokenizer.tokenize("curl ''"), ["curl", ""])
    },
    Test("backslash escapes the next character outside quotes") {
        expectEqual(try ShellTokenizer.tokenize(#"a\ b \'c"#), ["a b", "'c"])
    },
    Test("backslash-newline continues the line") {
        expectEqual(try ShellTokenizer.tokenize("curl \\\n  -v"), ["curl", "-v"])
        expectEqual(try ShellTokenizer.tokenize("ab\\\ncd"), ["abcd"])
    },
    Test("CRLF line continuations work") {
        expectEqual(try ShellTokenizer.tokenize("curl \\\r\n  -v"), ["curl", "-v"])
    },
    Test("backslash-newline inside double quotes is removed") {
        expectEqual(try ShellTokenizer.tokenize("\"a\\\nb\""), ["ab"])
    },
    Test("trailing lone backslash is ignored") {
        expectEqual(try ShellTokenizer.tokenize("a \\"), ["a"])
    },
    Test("# starts a comment only at the start of a word") {
        expectEqual(try ShellTokenizer.tokenize("#!/bin/sh\ncurl a#b '#c' # note"), ["curl", "a#b", "#c"])
    },
    Test("unterminated quotes throw") {
        expectThrows(try ShellTokenizer.tokenize("'abc"))
        expectThrows(try ShellTokenizer.tokenize("\"abc"))
        expectThrows(try ShellTokenizer.tokenize("$'abc"))
    },
    Test("unterminated quote error explains which quote") {
        let error = expectThrows(try ShellTokenizer.tokenize("\"abc"))
        expectEqual(error?.localizedDescription, "Unterminated \" quote in command.")
    },
])
