import Foundation

// A tiny XCTest-style test kit. XCTest and Swift Testing only ship with full Xcode,
// not the Command Line Tools this project builds with, so the unit tests use this
// instead. Suites are plain values listed in Tests/Unit/main.swift.
//
//     let exampleTests = TestSuite("Example", [
//         Test("adds numbers") {
//             expectEqual(1 + 1, 2)
//         },
//     ])

struct Test {
    let name: String
    let body: () throws -> Void

    init(_ name: String, _ body: @escaping () throws -> Void) {
        self.name = name
        self.body = body
    }
}

struct TestSuite {
    let name: String
    let tests: [Test]

    init(_ name: String, _ tests: [Test]) {
        self.name = name
        self.tests = tests
    }
}

/// Thrown by `unwrap` to stop a test early; the failure itself is already recorded.
struct TestStopped: Error {}

private struct Failure {
    let message: String
    let file: StaticString
    let line: UInt
}

private var currentFailures: [Failure] = []

func fail(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    currentFailures.append(Failure(message: message, file: file, line: line))
}

private func label(_ message: String) -> String {
    message.isEmpty ? "" : " — \(message)"
}

/// Evaluates a possibly-throwing expression, recording a failure if it throws.
private func evaluate<T>(_ expression: () throws -> T, file: StaticString, line: UInt) -> T? {
    do {
        return try expression()
    } catch {
        fail("threw \(error)", file: file, line: line)
        return nil
    }
}

// MARK: - Assertions

func expectEqual<T: Equatable>(
    _ actual: @autoclosure () throws -> T,
    _ expected: @autoclosure () throws -> T,
    _ message: String = "",
    file: StaticString = #filePath, line: UInt = #line
) {
    guard let a = evaluate(actual, file: file, line: line),
          let e = evaluate(expected, file: file, line: line) else { return }
    if a != e {
        fail("expected \(String(reflecting: e)), got \(String(reflecting: a))\(label(message))", file: file, line: line)
    }
}

func expectTrue(_ value: @autoclosure () throws -> Bool, _ message: String = "",
                file: StaticString = #filePath, line: UInt = #line) {
    if evaluate(value, file: file, line: line) == false {
        fail("expected true\(label(message))", file: file, line: line)
    }
}

func expectFalse(_ value: @autoclosure () throws -> Bool, _ message: String = "",
                 file: StaticString = #filePath, line: UInt = #line) {
    if evaluate(value, file: file, line: line) == true {
        fail("expected false\(label(message))", file: file, line: line)
    }
}

func expectNil<T>(_ value: @autoclosure () throws -> T?, _ message: String = "",
                  file: StaticString = #filePath, line: UInt = #line) {
    if let v = evaluate(value, file: file, line: line), let unwrapped = v {
        fail("expected nil, got \(String(reflecting: unwrapped))\(label(message))", file: file, line: line)
    }
}

/// Returns the unwrapped value, or records a failure and stops the test.
func unwrap<T>(_ value: @autoclosure () throws -> T?, _ message: String = "",
               file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let v = evaluate(value, file: file, line: line) else { throw TestStopped() }
    guard let unwrapped = v else {
        fail("unexpected nil\(label(message))", file: file, line: line)
        throw TestStopped()
    }
    return unwrapped
}

func expectContains(_ text: @autoclosure () throws -> String, _ needle: String, _ message: String = "",
                    file: StaticString = #filePath, line: UInt = #line) {
    guard let t = evaluate(text, file: file, line: line) else { return }
    if !t.contains(needle) {
        fail("expected to contain \(needle.debugDescription)\(label(message))\n      in: \(t.debugDescription)", file: file, line: line)
    }
}

func expectNotContains(_ text: @autoclosure () throws -> String, _ needle: String, _ message: String = "",
                       file: StaticString = #filePath, line: UInt = #line) {
    guard let t = evaluate(text, file: file, line: line) else { return }
    if t.contains(needle) {
        fail("expected not to contain \(needle.debugDescription)\(label(message))\n      in: \(t.debugDescription)", file: file, line: line)
    }
}

/// Records a failure unless the expression throws; returns the error for further checks.
@discardableResult
func expectThrows<T>(_ expression: @autoclosure () throws -> T, _ message: String = "",
                     file: StaticString = #filePath, line: UInt = #line) -> Error? {
    do {
        let value = try expression()
        fail("expected an error, got \(String(reflecting: value))\(label(message))", file: file, line: line)
        return nil
    } catch {
        return error
    }
}

/// Compares ordered key/value pairs (tuples aren't Equatable).
func expectPairs(_ actual: @autoclosure () throws -> [(String, String)], _ expected: [(String, String)],
                 _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    guard let a = evaluate(actual, file: file, line: line) else { return }
    expectEqual(a.map { "\($0.0)=\($0.1)" }, expected.map { "\($0.0)=\($0.1)" }, message, file: file, line: line)
}

// MARK: - Runner

enum TestRunner {
    /// Runs every suite (or only those whose name contains `filter`) and returns the exit code.
    static func run(_ suites: [TestSuite], filter: String?) -> Int32 {
        let selected = suites.filter { filter == nil || $0.name.localizedCaseInsensitiveContains(filter!) }
        let start = Date()
        var passed = 0
        var failed: [String] = []

        for suite in selected {
            print("\n\(suite.name)")
            for test in suite.tests {
                currentFailures = []
                do {
                    try test.body()
                } catch is TestStopped {
                    // already recorded
                } catch {
                    fail("threw \(error)", file: #filePath, line: #line)
                }
                if currentFailures.isEmpty {
                    passed += 1
                    print("  ✓ \(test.name)")
                } else {
                    failed.append("\(suite.name) › \(test.name)")
                    print("  ✗ \(test.name)")
                    for f in currentFailures {
                        let file = ("\(f.file)" as NSString).lastPathComponent
                        print("      \(file):\(f.line): \(f.message)")
                    }
                }
            }
        }

        let seconds = String(format: "%.2f", Date().timeIntervalSince(start))
        print("\n\(passed + failed.count) tests in \(selected.count) suites, \(failed.count) failed (\(seconds)s)")
        if !failed.isEmpty {
            print("Failed:")
            failed.forEach { print("  ✗ \($0)") }
        }
        if selected.isEmpty { print("No suite matches \"\(filter ?? "")\".") }
        return failed.isEmpty && !selected.isEmpty ? 0 : 1
    }
}
