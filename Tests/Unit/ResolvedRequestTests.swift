import Foundation

/// Parses and resolves a curl command.
func resolve(_ curl: String) throws -> ResolvedRequest {
    ResolvedRequest.resolve(try CurlParser.parse(curl))
}

private func bodyKind(_ r: ResolvedRequest) -> String {
    switch r.body {
    case .none: return "none"
    case .json: return "json"
    case .form: return "form"
    case .raw: return "raw"
    case .file: return "file"
    }
}

let resolvedRequestTests = TestSuite("ResolvedRequest", [
    Test("adds http:// when the scheme is missing and drops the fragment") {
        let r = try resolve("curl e.com/a?b=1#top")
        expectEqual(r.originalURL, "http://e.com/a?b=1")
        expectEqual(r.url, "http://e.com/a?b=1")
    },
    Test("splits a decodable query string") {
        let r = try resolve("curl 'https://e.com/s?q=a+b&x=%26'")
        expectEqual(r.baseURL, "https://e.com/s")
        expectPairs(try unwrap(r.queryPairs), [("q", "a b"), ("x", "&")])
    },
    Test("leaves an undecodable query string alone") {
        let r = try resolve("curl 'https://e.com/s?q=%zz'")
        expectNil(r.queryPairs)
        expectEqual(r.baseURL, "https://e.com/s?q=%zz")
    },
    Test("urlAndParams respects the split option") {
        let r = try resolve("curl 'https://e.com/s?q=1'")
        let (splitURL, splitParams) = r.urlAndParams(split: true)
        expectEqual(splitURL, "https://e.com/s")
        expectPairs(splitParams, [("q", "1")])
        let (fullURL, noParams) = r.urlAndParams(split: false)
        expectEqual(fullURL, "https://e.com/s?q=1")
        expectTrue(noParams.isEmpty)
    },
    Test("-G moves data into the query string") {
        let r = try resolve("curl -G 'https://e.com/s?a=1' -d 'b=x y' -d flag")
        expectPairs(r.getPairs, [("b", "x y"), ("flag", "")])
        expectEqual(r.url, "https://e.com/s?a=1&b=x%20y&flag=")
        expectEqual(r.method, "GET")
        expectEqual(bodyKind(r), "none")
    },
    Test("cookies come from the Cookie header and -b") {
        let r = try resolve("curl https://e.com -H 'Cookie: a=1; b=2' -b 'c=3'")
        expectPairs(r.cookies, [("a", "1"), ("b", "2"), ("c", "3")])
        expectTrue(r.headers.isEmpty)
        expectEqual(r.cookieHeader, "a=1; b=2; c=3")
    },
    Test("a -b cookie file is noted, not sent") {
        let r = try resolve("curl https://e.com -b jar.txt")
        expectTrue(r.cookies.isEmpty)
        expectContains(r.notes.joined(), "jar.txt")
    },
    Test("drops headers the HTTP libraries set themselves") {
        let r = try resolve("curl https://e.com -H 'Accept-Encoding: gzip' -H 'Content-Length: 3' -H 'X-Keep: 1'")
        expectPairs(r.headers, [("X-Keep", "1")])
        expectEqual(r.notes.count, 2)
    },
    Test("drops a multipart Content-Type only when there are form fields") {
        let form = try resolve("curl https://e.com -H 'Content-Type: multipart/form-data; boundary=x' -F a=1")
        expectNil(form.header("content-type"))
        let noForm = try resolve("curl https://e.com -H 'Content-Type: multipart/form-data; boundary=x'")
        expectEqual(noForm.header("Content-Type"), "multipart/form-data; boundary=x")
    },
    Test("--json adds JSON headers unless already given") {
        let r = try resolve("curl https://e.com --json '{\"a\":1}' -H 'Accept: text/plain'")
        expectEqual(r.header("content-type"), "application/json")
        expectEqual(r.header("accept"), "text/plain")
        expectEqual(bodyKind(r), "json")
    },
    Test("chooses the body kind from content type and shape") {
        expectEqual(bodyKind(try resolve("curl e.com -H 'Content-Type: application/json' -d '{\"a\":1}'")), "json")
        expectEqual(bodyKind(try resolve("curl e.com -H 'Content-Type: application/json' -d '{bad'")), "raw")
        expectEqual(bodyKind(try resolve("curl e.com -d 'a=1&b=2'")), "form")
        expectEqual(bodyKind(try resolve("curl e.com -d 'hello'")), "raw")
        expectEqual(bodyKind(try resolve("curl e.com -H 'Content-Type: text/plain' -d 'a=1'")), "raw")
        expectEqual(bodyKind(try resolve("curl e.com -d @body.bin")), "file")
        expectEqual(bodyKind(try resolve("curl e.com --data-raw @literal")), "raw", "--data-raw never reads files")
    },
    Test("joins multiple data parts with &") {
        guard case .form(let pairs, let encoded) = try resolve("curl e.com -d a=1 -d b=2").body else {
            return fail("expected a form body")
        }
        expectPairs(pairs, [("a", "1"), ("b", "2")])
        expectEqual(encoded, "a=1&b=2")
    },
    Test("--data-urlencode percent-encodes the value") {
        guard case .form(_, let encoded) = try resolve("curl e.com --data-urlencode 'msg=a b&c/é'").body else {
            return fail("expected a form body")
        }
        expectEqual(encoded, "msg=a%20b%26c%2F%C3%A9")
    },
    Test("an @file mixed with other data is noted and skipped") {
        let r = try resolve("curl e.com -d @a.txt -d b=1")
        expectContains(r.notes.joined(), "@a.txt")
        expectEqual(bodyKind(r), "form")
    },
    Test("resolves multipart fields") {
        let r = try resolve("curl e.com -F 'f=@pic.jpg;type=image/jpeg' -F 'g=<notes.txt' -F 'h=text' --form-string 'i=@x'")
        let described = r.formFields.map { field -> String in
            switch field {
            case .file(let name, let path): return "file \(name) \(path)"
            case .fileContents(let name, let path): return "contents \(name) \(path)"
            case .text(let name, let value): return "text \(name) \(value)"
            }
        }
        expectEqual(described, ["file f pic.jpg", "contents g notes.txt", "text h text", "text i @x"])
        expectEqual(r.method, "POST")
    },
    Test("infers the method") {
        expectEqual(try resolve("curl e.com").method, "GET")
        expectEqual(try resolve("curl e.com -d x").method, "POST")
        expectEqual(try resolve("curl e.com -d x -X PUT").method, "PUT")
        expectEqual(try resolve("curl -I e.com").method, "HEAD")
    },
    Test("splits user and password") {
        let r = try resolve("curl e.com -u 'me:pa:ss'")
        expectEqual(r.auth?.user, "me")
        expectEqual(r.auth?.password, "pa:ss")
        expectEqual(r.basicAuthToken, Data("me:pa:ss".utf8).base64EncodedString())
    },
    Test("-u without a password is noted") {
        let r = try resolve("curl e.com -u me")
        expectEqual(r.auth?.password, "")
        expectContains(r.notes.joined(), "No password")
    },
    Test("normalizes proxy and timeout") {
        let r = try resolve("curl e.com -x host:8080 -m 1.5")
        expectEqual(r.proxy, "http://host:8080")
        expectEqual(r.timeout, 1.5)
        let bad = try resolve("curl e.com -m soon")
        expectNil(bad.timeout)
        expectContains(bad.notes.joined(), "soon")
    },
    Test("explicitHeaders adds cookies and curl's implicit form Content-Type") {
        let form = try resolve("curl e.com -d a=1 -b 'c=2'")
        expectPairs(form.explicitHeaders, [("Cookie", "c=2"), ("Content-Type", "application/x-www-form-urlencoded")])
        expectPairs(try resolve("curl e.com -d hello").explicitHeaders, [("Content-Type", "application/x-www-form-urlencoded")])
        expectTrue(try resolve("curl e.com -F a=1").explicitHeaders.isEmpty, "multipart sets its own type")
        expectTrue(try resolve("curl e.com").explicitHeaders.isEmpty)
    },
    Test("hasBody covers data and form fields") {
        expectFalse(try resolve("curl e.com").hasBody)
        expectTrue(try resolve("curl e.com -d a").hasBody)
        expectTrue(try resolve("curl e.com -F a=1").hasBody)
    },
    Test("static helpers") {
        expectEqual(ResolvedRequest.percentEncode("a b~-._/"), "a%20b~-._%2F")
        expectEqual(ResolvedRequest.encodeForm([("a b", "c&d")]), "a%20b=c%26d")
        expectNil(ResolvedRequest.parseForm("novalue"))
        expectNil(ResolvedRequest.parseForm("=1"))
        expectNil(ResolvedRequest.parseForm("a=1\nb=2"))
        expectPairs(try unwrap(ResolvedRequest.parseForm("a=&b=%41")), [("a", ""), ("b", "A")])
        expectEqual(ResolvedRequest.fileName("/tmp/dir/photo.jpg"), "photo.jpg")
    },
])
