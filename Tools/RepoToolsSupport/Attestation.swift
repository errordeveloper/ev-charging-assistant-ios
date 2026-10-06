#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

public struct ToolchainStatement: Codable, Equatable {
    public struct Subject: Codable, Equatable {
        public var name: String
        public var digest: [String: String]
    }
    public struct Predicate: Codable, Equatable {
        public var recordedAt: String
        public var host: [String: String]
        public var environment: [String: String]
        public var observations: [String: Observation]
        public var collectionSucceeded: Bool
    }
    public var _type = "https://in-toto.io/Statement/v1"
    public var subject: [Subject]
    public var predicateType = "https://github.com/errordeveloper/ev-charging-assistant-ios/attestations/toolchain/v1"
    public var predicate: Predicate

    public func write(to output: URL) throws -> Int32 {
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try jsonData(self).write(to: output, options: .atomic)
        return predicate.collectionSucceeded ? 0 : 1
    }
}

public enum Attestation {
    public static let subjectFiles = [
        "flake.nix", "flake.lock", "nix/xcodegen.nix", "config/toolchain.json", ".github/workflows/ci.yml",
        "Package.swift", "Tools/RepoTools/main.swift", "Tools/RepoToolsSupport/Attestation.swift",
        "Tools/RepoToolsSupport/Command.swift"
    ]
    public static let commands = [
        "nix": ["nix", "--version"], "xcode": ["xcodebuild", "-version"], "swift": ["swift", "--version"],
        "git": ["git", "--version"], "xcodegen": ["xcodegen", "--version"],
        "selectedSwift": ["xcrun", "--find", "swift"],
        "simulatorSDK": ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
        "simulatorRuntimes": ["xcrun", "simctl", "list", "runtimes", "--json"],
        "gitRevision": ["git", "rev-parse", "HEAD"], "gitStatus": ["git", "status", "--porcelain"]
    ]
    private static let environmentKeys: Set<String> = [
        "DEVELOPER_DIR", "SDKROOT", "TOOLCHAINS", "GITHUB_REPOSITORY", "GITHUB_SHA", "GITHUB_RUN_ID",
        "GITHUB_RUN_ATTEMPT", "RUNNER_OS", "RUNNER_ARCH"
    ]

    public static func collect(
        root: URL, run: ([String]) -> Observation,
        recordedAt: Date = Date(), environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> ToolchainStatement {
        let subjects = try subjectFiles.map { name in
            ToolchainStatement.Subject(name: name, digest: ["sha256": try sha256(root.appendingPathComponent(name))])
        }
        var observations: [String: Observation] = [:]
        for name in commands.keys.sorted() { observations[name] = run(commands[name]!) }
        var system = utsname()
        uname(&system)
        func string<T>(_ field: T) -> String {
            withUnsafeBytes(of: field) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        }
        return ToolchainStatement(subject: subjects, predicate: .init(
            recordedAt: ISO8601DateFormatter().string(from: recordedAt),
            host: ["os": string(system.sysname), "architecture": string(system.machine), "kernelRelease": string(system.release)],
            environment: environment.filter { environmentKeys.contains($0.key) },
            observations: observations, collectionSucceeded: observations.values.allSatisfy { $0.exitCode == 0 }
        ))
    }
}

func sha256(_ file: URL) throws -> String {
    #if canImport(CryptoKit)
    return SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
    #else
    // GNU coreutils is supplied by the Linux development shell. Pass bytes on
    // stdin so filenames cannot affect sha256sum's output or option parsing.
    let input = try FileHandle(forReadingFrom: file)
    defer { try? input.close() }
    let process = Process()
    let output = Pipe()
    let runner = CommandRunner(root: file.deletingLastPathComponent())
    guard let executable = runner.executable("sha256sum") else {
        throw ToolError("Missing sha256sum; enter the Linux Nix development shell")
    }
    process.executableURL = URL(fileURLWithPath: executable)
    process.standardInput = input
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let digest = String(decoding: data, as: UTF8.self).components(separatedBy: " ")[0]
    try require(process.terminationStatus == 0 && matches(digest, "^[0-9a-f]{64}$"), "sha256sum failed")
    return digest
    #endif
}
