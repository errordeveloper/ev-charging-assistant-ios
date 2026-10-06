import Darwin
import Foundation

public struct ToolError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw ToolError(message) }
}

public struct Observation: Codable, Equatable, Sendable {
    public var command: [String]
    public var executable: String?
    public var exitCode: Int
    public var stdout: String
    public var stderr: String

    // Keep the explicit null executable field when a command cannot be found.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(command, forKey: .command)
        try container.encode(executable, forKey: .executable)
        try container.encode(exitCode, forKey: .exitCode)
        try container.encode(stdout, forKey: .stdout)
        try container.encode(stderr, forKey: .stderr)
    }

    public func checked() throws -> String {
        try require(exitCode == 0, "\(command.joined(separator: " ")) exited \(exitCode): \(stderr)")
        return stdout
    }
}

public struct CommandRunner {
    public let root: URL
    public let environment: [String: String]

    public init(root: URL, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.root = URL(fileURLWithPath: root.path, isDirectory: true)
        self.environment = environment
    }

    public func executable(_ name: String) -> String? {
        let candidates = name.contains("/") ? [name] :
            (environment["PATH"] ?? "/usr/bin:/bin").components(separatedBy: ":").map {
                $0.isEmpty ? name : "\($0)/\(name)"
            }
        return candidates.map { URL(fileURLWithPath: $0, relativeTo: root).standardizedFileURL.path }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func run(_ command: [String], input: String? = nil, timeout: TimeInterval = 60) -> Observation {
        var result = Observation(command: command, executable: command.first.flatMap(executable),
                                 exitCode: 127, stdout: "", stderr: "")
        guard let path = result.executable else {
            result.stderr = "Command not found: \(command.first ?? "<empty command>")"
            return result
        }
        do {
            let temporary = try TemporaryDirectory(prefix: "repo-tools-command")
            defer { temporary.remove() }
            // Files avoid pipe-buffer deadlocks when a tool emits a large diagnostic.
            let out = temporary.url.appendingPathComponent("stdout")
            let err = temporary.url.appendingPathComponent("stderr")
            try Data().write(to: out)
            try Data().write(to: err)
            let stdout = try FileHandle(forWritingTo: out)
            let stderr = try FileHandle(forWritingTo: err)
            defer { try? stdout.close(); try? stderr.close() }
            var stdin = FileHandle.nullDevice
            if let input {
                let file = temporary.url.appendingPathComponent("stdin")
                try Data(input.utf8).write(to: file)
                stdin = try FileHandle(forReadingFrom: file)
            }
            defer { if input != nil { try? stdin.close() } }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = Array(command.dropFirst())
            process.currentDirectoryURL = root
            process.environment = environment
            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr
            let finished = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in finished.signal() }
            try process.run()
            if finished.wait(timeout: .now() + timeout) == .timedOut {
                process.terminate()
                if finished.wait(timeout: .now() + 1) == .timedOut {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    process.waitUntilExit()
                }
                result.exitCode = 124
            } else {
                result.exitCode = Int(process.terminationStatus)
            }
            result.stdout = String(decoding: try Data(contentsOf: out), as: UTF8.self)
            result.stderr = String(decoding: try Data(contentsOf: err), as: UTF8.self)
            if result.exitCode == 124 { result.stderr += "\nCommand timed out after \(timeout) seconds." }
        } catch {
            result.exitCode = 127
            result.stderr = String(describing: error)
        }
        return result
    }
}

struct TemporaryDirectory {
    let url: URL
    init(prefix: String) throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func remove() { try? FileManager.default.removeItem(at: url) }
}

func readJSON<T: Decodable>(_ type: T.Type, root: URL, path: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent(path)))
}

func jsonData<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(0x0A)
    return data
}

func matches(_ value: String, _ pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
}

func captures(_ value: String, _ pattern: String) -> [[String]] {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    return expression.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { match in
        (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: value).map { String(value[$0]) } }
    }
}
