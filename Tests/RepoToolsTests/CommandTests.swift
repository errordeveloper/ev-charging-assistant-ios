import Foundation
import Testing
@testable import RepoToolsSupport

@Test func missingCommandIsRecordedWithNullExecutable() throws {
    let runner = CommandRunner(root: FileManager.default.temporaryDirectory, environment: ["PATH": "/missing-tools"])
    let result = runner.run(["missing-repo-tool"])
    #expect(result.exitCode == 127)
    #expect(result.executable == nil)
    #expect(result.stderr.contains("Command not found"))
    let json = try #require(JSONSerialization.jsonObject(with: jsonData(result)) as? [String: Any])
    #expect(json["executable"] is NSNull)
}

@Test func timedOutCommandIsRecordedAsFailure() {
    let runner = CommandRunner(root: FileManager.default.temporaryDirectory)
    let result = runner.run(["/bin/sleep", "10"], timeout: 0.05)
    #expect(result.exitCode == 124)
    #expect(result.stderr.contains("timed out"))
}

@Test func commandPreservesLargeInputWithoutShellExpansion() throws {
    let fixture = try TemporaryDirectory(prefix: "command-fixture")
    defer { fixture.remove() }
    let input = String(repeating: "$(touch should-not-exist) `exit 1` $HOME\n", count: 5000)
    let runner = CommandRunner(root: fixture.url)
    let result = runner.run(["/bin/cat"], input: input)
    #expect(result.exitCode == 0)
    #expect(result.stdout == input)
    #expect(!FileManager.default.fileExists(atPath: fixture.url.appendingPathComponent("should-not-exist").path))
}

@Test func nonzeroExitAndDiagnosticsArePreserved() {
    let result = CommandRunner(root: FileManager.default.temporaryDirectory).run(["/bin/ls", "/missing-repo-tools-fixture"])
    #expect(result.exitCode != 0)
    #expect(result.stderr.contains("missing-repo-tools-fixture"))
    #expect(throws: ToolError.self) { try result.checked() }
}

@Test func executableLookupResolvesRelativeAndEmptyPathEntriesAgainstWorkingDirectory() throws {
    let fixture = try TemporaryDirectory(prefix: "path-fixture")
    defer { fixture.remove() }
    let bin = fixture.url.appendingPathComponent("bin")
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    let executable = bin.appendingPathComponent("fixture-tool")
    try Data("fixture".utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    #expect(CommandRunner(root: fixture.url, environment: ["PATH": "bin"]).executable("fixture-tool") == executable.path)
    #expect(CommandRunner(root: bin, environment: ["PATH": ""]).executable("fixture-tool") == executable.path)
}
