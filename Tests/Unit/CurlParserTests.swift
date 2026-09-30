import Foundation

private func parse(_ curl: String) throws -> CurlRequest {
    try CurlParser.parse(curl)
}

let curlParserTests = TestSuite("CurlParser", [
    Test("reads the URL") {
        expectEqual(try parse("curl https://e.com/a").url, "https://e.com/a")
    },
    Test("accepts curl.exe, a path to curl and a $ prompt") {
        expectEqual(try parse("curl.exe https://e.com").url, "https://e.com")
        expectEqual(try parse("/usr/bin/curl https://e.com").url, "https://e.com")
        expectEqual(try parse("  $ curl https://e.com\n").url, "https://e.com")
    },
    Test("-X sets an upper-cased method") {
        expectEqual(try parse("curl -X patch https://e.com").method, "PATCH")
        expectEqual(try parse("curl --request=DELETE https://e.com").method, "DELETE")
    },
    Test("-H splits name and value and trims them") {
        let r = try parse("curl https://e.com -H '  X-A :  b c ' -H 'X-B:'")
        expectPairs(r.headers, [("X-A", "b c"), ("X-B", "")])
    },
    Test("-H 'Name;' sends an empty header") {
        expectPairs(try parse("curl https://e.com -H 'X-Empty;'").headers, [("X-Empty", "")])
    },
    Test("-H without a colon is ignored with a warning") {
        let r = try parse("curl https://e.com -H 'nonsense'")
        expectTrue(r.headers.isEmpty)
        expectContains(r.warnings.joined(), "no ':'")
    },
    Test("-A, -e and --oauth2-bearer become headers") {
        let r = try parse("curl https://e.com -A agent/1 -e https://ref --oauth2-bearer tok")
        expectPairs(r.headers, [("User-Agent", "agent/1"), ("Referer", "https://ref"), ("Authorization", "Bearer tok")])
    },
    Test("data options keep their kind") {
        let r = try parse("curl https://e.com -d a --data-raw b --data-binary c --data-urlencode d --data-ascii e")
        expectEqual(r.dataParts.map(\.value), ["a", "b", "c", "d", "e"])
        expectTrue(r.dataParts[0].kind == .normal)
        expectTrue(r.dataParts[1].kind == .raw)
        expectTrue(r.dataParts[2].kind == .binary)
        expectTrue(r.dataParts[3].kind == .urlencode)
        expectTrue(r.dataParts[4].kind == .normal)
    },
    Test("--json marks the request as JSON") {
        let r = try parse("curl https://e.com --json '{}'")
        expectTrue(r.isJSON)
        expectTrue(r.dataParts.first?.kind == .raw)
        expectTrue(try parse("curl https://e.com --json @body.json").dataParts.first?.kind == .binary)
    },
    Test("combined short flags are expanded") {
        let r = try parse("curl -sSLkIG https://e.com")
        expectTrue(r.insecure)
        expectTrue(r.head)
        expectTrue(r.forceGet)
        expectTrue(r.warnings.isEmpty, "silent/show-error/location are ignored quietly")
    },
    Test("short options take attached values") {
        let r = try parse("curl -XPOST -H'A: b' -uuser:pw https://e.com")
        expectEqual(r.method, "POST")
        expectPairs(r.headers, [("A", "b")])
        expectEqual(r.user, "user:pw")
    },
    Test("-F and --form-string split at the first =") {
        let r = try parse("curl https://e.com -F 'f=@a=b.txt' --form-string 'g=@lit'")
        expectEqual(r.formParts.map(\.name), ["f", "g"])
        expectEqual(r.formParts.map(\.value), ["@a=b.txt", "@lit"])
        expectEqual(r.formParts.map(\.literal), [false, true])
    },
    Test("reads -u, -b, -x, -m") {
        let r = try parse("curl https://e.com -u a:b -b 'c=d' -x proxy:1 -m 7")
        expectEqual(r.user, "a:b")
        expectEqual(r.cookie, "c=d")
        expectEqual(r.proxy, "proxy:1")
        expectEqual(r.timeout, "7")
    },
    Test("--connect-timeout doesn't override --max-time") {
        expectEqual(try parse("curl https://e.com -m 5 --connect-timeout 2").timeout, "5")
        expectEqual(try parse("curl https://e.com --connect-timeout 2").timeout, "2")
    },
    Test("ignored options still consume their value") {
        let r = try parse("curl -o out.txt -w '%{http_code}' https://e.com")
        expectEqual(r.url, "https://e.com")
        expectTrue(r.warnings.isEmpty)
    },
    Test("--url and -- supply URLs") {
        expectEqual(try parse("curl --url https://e.com").url, "https://e.com")
        expectEqual(try parse("curl -- -weird-host").url, "-weird-host")
    },
    Test("extra URLs are ignored with a warning") {
        let r = try parse("curl https://a.com https://b.com")
        expectEqual(r.url, "https://a.com")
        expectContains(r.warnings.joined(), "https://b.com")
    },
    Test("unknown and unsupported options produce warnings") {
        expectContains(try parse("curl -Q https://e.com").warnings.joined(), "Unknown option -Q")
        expectContains(try parse("curl --tlsv1.3 https://e.com").warnings.joined(), "--tlsv1.3")
        expectTrue(try parse("curl --compressed --no-progress-meter https://e.com").warnings.isEmpty)
    },
    Test("errors: empty, not curl, missing value, no URL") {
        expectThrows(try parse(" \n "))
        let notCurl = expectThrows(try parse("wget https://e.com"))
        expectContains(notCurl?.localizedDescription ?? "", "wget")
        let missing = expectThrows(try parse("curl https://e.com -H"))
        expectContains(missing?.localizedDescription ?? "", "-H")
        expectThrows(try parse("curl -v"))
    },
])
