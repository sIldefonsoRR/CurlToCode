import Foundation

private func ruby(_ r: ResolvedRequest, _ options: GeneratorOptions = .init()) -> String {
    RubyGenerator.generate(r, options: options)
}

let rubyGeneratorTests = TestSuite("RubyGenerator", [
    Test("simple GET") {
        expectEqual(ruby(makeRequest(), printOff), """
        require 'net/http'

        uri = URI('https://api.example.com/items')
        req = Net::HTTP::Get.new(uri)

        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = uri.scheme == 'https'
        res = http.request(req)

        """)
    },
    Test("prints code and body") {
        expectContains(ruby(makeRequest()), "puts res.code\nputs res.body")
    },
    Test("non-standard methods use HTTPGenericRequest") {
        expectContains(ruby(makeRequest("PURGE")), "Net::HTTPGenericRequest.new('PURGE', true, true, uri)")
    },
    Test("headers, cookies and basic auth") {
        let code = ruby(makeRequest { $0.headers = [("Accept", "*/*")]; $0.cookies = [("s", "1")]; $0.auth = ("u", "p") })
        expectContains(code, "req['Accept'] = '*/*'")
        expectContains(code, "req['Cookie'] = 's=1'")
        expectContains(code, "req.basic_auth('u', 'p')")
    },
    Test("JSON bodies become a hash with to_json") {
        let code = ruby(makeRequest("POST") { $0.body = .json(sampleJSON()) })
        expectContains(code, "require 'json'")
        expectContains(code, "req.body = {\n  'name' => 'x',\n  'ok' => true,\n  'none' => nil,\n}.to_json")
    },
    Test("form bodies use URI.encode_www_form") {
        expectContains(ruby(makeRequest("POST") { $0.body = .form([("a", "1")], encoded: "a=1") }),
                       "req.body = URI.encode_www_form(\n  'a' => '1',\n)")
        expectContains(ruby(makeRequest("POST") { $0.body = .form([("k", "1"), ("k", "2")], encoded: "") }),
                       "URI.encode_www_form([\n  ['k', '1'],\n  ['k', '2'],\n])")
    },
    Test("file bodies and multipart") {
        expectContains(ruby(makeRequest("POST") { $0.body = .file("b.bin") }), "req.body = File.binread('b.bin')")
        let code = ruby(makeRequest("POST") { $0.formFields = [.file(name: "f", path: "p.jpg"), .fileContents(name: "g", path: "n.txt")] })
        expectContains(code, "req.set_form([\n  ['f', File.open('p.jpg')],\n  ['g', File.read('n.txt')],\n], 'multipart/form-data')")
    },
    Test("insecure, proxy and timeouts configure the connection") {
        let code = ruby(makeRequest { $0.insecure = true; $0.proxy = "http://px:1"; $0.timeout = 30 })
        expectContains(code, "require 'openssl'")
        expectContains(code, "http.verify_mode = OpenSSL::SSL::VERIFY_NONE")
        expectContains(code, "proxy = URI('http://px:1')")
        expectContains(code, "Net::HTTP.new(uri.hostname, uri.port, proxy.hostname, proxy.port, proxy.user, proxy.password)")
        expectContains(code, "http.open_timeout = 30\nhttp.read_timeout = 30")
    },
])
