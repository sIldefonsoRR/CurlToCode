import Foundation

/// Python using the `requests` library.
enum PythonGenerator {
    private static let simpleMethods: Set<String> = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

    private static let style = Literals.Style(
        string: Literals.python, key: Literals.python,
        trueLiteral: "True", falseLiteral: "False", nullLiteral: "None", indentUnit: "    ")

    static func generate(_ r: ResolvedRequest, options: GeneratorOptions) -> String {
        let str = Literals.python
        var blocks: [String] = []
        var args: [String] = []

        let (url, params) = r.urlAndParams(split: options.splitQueryParams)
        if !simpleMethods.contains(r.method) { args.append(str(r.method)) }
        args.append(str(url))

        if !params.isEmpty {
            blocks.append("params = " + pairs(params))
            args.append("params=params")
        }
        if !r.cookies.isEmpty {
            blocks.append("cookies = " + pairs(r.cookies, forceDict: true))
            args.append("cookies=cookies")
        }
        if !r.headers.isEmpty {
            blocks.append("headers = " + pairs(r.headers, forceDict: true))
            args.append("headers=headers")
        }

        switch r.body {
        case .none:
            break
        case .json(let value):
            blocks.append("json_data = " + Literals.render(value, style: style))
            args.append("json=json_data")
        case .form(let form, _):
            blocks.append("data = " + pairs(form))
            args.append("data=data")
        case .raw(let text):
            let needsEncode = text.unicodeScalars.contains { $0.value > 0x7F }
            blocks.append("data = " + str(text) + (needsEncode ? ".encode()" : ""))
            args.append("data=data")
        case .file(let path):
            blocks.append("with open(\(str(path)), 'rb') as f:\n    data = f.read()")
            args.append("data=data")
        }

        if !r.formFields.isEmpty {
            let lines = r.formFields.map { field -> String in
                switch field {
                case .text(let name, let value): return "    \(str(name)): (None, \(str(value))),"
                case .file(let name, let path): return "    \(str(name)): open(\(str(path)), 'rb'),"
                case .fileContents(let name, let path): return "    \(str(name)): (None, open(\(str(path))).read()),"
                }
            }
            blocks.append("files = {\n" + lines.joined(separator: "\n") + "\n}")
            args.append("files=files")
        }

        if let auth = r.auth { args.append("auth=(\(str(auth.user)), \(str(auth.password)))") }
        if let proxy = r.proxy {
            blocks.append("proxies = " + pairs([("http", proxy), ("https", proxy)], forceDict: true))
            args.append("proxies=proxies")
        }
        if let timeout = r.timeout { args.append("timeout=\(Literals.number(timeout))") }
        if r.insecure { args.append("verify=False") }

        let function = simpleMethods.contains(r.method) ? r.method.lowercased() : "request"
        blocks.append(call("response = requests.\(function)(", args))

        if options.includePrint {
            blocks.append("print(response.status_code)\nprint(response.text)")
        }

        return CodeGenerator.noteComments(r.notes, prefix: "#")
            + "import requests\n\n" + blocks.joined(separator: "\n\n") + "\n"
    }

    private static func call(_ prefix: String, _ args: [String]) -> String {
        let oneLine = prefix + args.joined(separator: ", ") + ")"
        if oneLine.count <= 88 { return oneLine }
        return prefix + "\n" + args.map { "    \($0)," }.joined(separator: "\n") + "\n)"
    }

    /// Dict literal, or a list of tuples when keys repeat (so none are lost).
    private static func pairs(_ pairs: [(String, String)], forceDict: Bool = false) -> String {
        let str = Literals.python
        let keys = pairs.map { $0.0 }
        if !forceDict && Set(keys).count != keys.count {
            return "[\n" + pairs.map { "    (\(str($0.0)), \(str($0.1)))," }.joined(separator: "\n") + "\n]"
        }
        return "{\n" + pairs.map { "    \(str($0.0)): \(str($0.1))," }.joined(separator: "\n") + "\n}"
    }
}
