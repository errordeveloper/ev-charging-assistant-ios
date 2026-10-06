import Foundation
import Testing
@testable import RepoToolsSupport

private func fixture() throws -> TemporaryDirectory {
    let directory = try TemporaryDirectory(prefix: "attestation-fixture")
    for name in Attestation.subjectFiles {
        let path = directory.url.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("abc".utf8).write(to: path)
    }
    return directory
}

private func collect(_ root: URL, failed: Bool = false) throws -> ToolchainStatement {
    try Attestation.collect(root: root, run: { command in
        let failure = failed && command.first == "xcrun"
        return Observation(command: command, executable: "/fixture/bin/\(command[0])", exitCode: failure ? 1 : 0,
                           stdout: "", stderr: failure ? "SDK unavailable" : "")
    }, recordedAt: Date(timeIntervalSince1970: 0),
       environment: ["GITHUB_RUN_ID": "123", "GITHUB_TOKEN": "must-not-leak", "DEVELOPER_DIR": "/fixture/Xcode.app"])
}

@Test func statementBindsInputBytesAndRoundTripsWithoutSignatures() throws {
    let fixture = try fixture()
    defer { fixture.remove() }
    let statement = try collect(fixture.url)
    #expect(statement._type == "https://in-toto.io/Statement/v1")
    #expect(statement.predicateType == "https://github.com/errordeveloper/ev-charging-assistant-ios/attestations/toolchain/v1")
    #expect(statement.predicate.collectionSucceeded)
    #expect(statement.predicate.recordedAt == "1970-01-01T00:00:00Z")
    #expect(Set(statement.subject.map(\.name)) == Set(Attestation.subjectFiles))
    for subject in statement.subject {
        // Known SHA-256 of abc, independent of the collector's hashing implementation.
        #expect(subject.digest == ["sha256": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"])
    }
    let output = fixture.url.appendingPathComponent("artifacts/toolchain.intoto.json")
    #expect(try statement.write(to: output) == 0)
    let data = try Data(contentsOf: output)
    #expect(try JSONDecoder().decode(ToolchainStatement.self, from: data) == statement)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["signatures"] == nil)
    try Data("changed inputs".utf8).write(to: fixture.url.appendingPathComponent("flake.lock"))
    #expect(try collect(fixture.url).subject != statement.subject)
}

@Test func onlyAllowlistedEnvironmentIsRecorded() throws {
    let fixture = try fixture()
    defer { fixture.remove() }
    let statement = try collect(fixture.url)
    #expect(statement.predicate.environment == ["GITHUB_RUN_ID": "123", "DEVELOPER_DIR": "/fixture/Xcode.app"])
    let json = String(decoding: try jsonData(statement), as: UTF8.self)
    #expect(!json.contains("GITHUB_TOKEN"))
    #expect(!json.contains("must-not-leak"))
}

@Test func failedProbePersistsIncompleteStatement() throws {
    let fixture = try fixture()
    defer { fixture.remove() }
    let statement = try collect(fixture.url, failed: true)
    #expect(!statement.predicate.collectionSucceeded)
    #expect(statement.predicate.observations["simulatorSDK"]?.exitCode == 1)
    #expect(statement.predicate.observations["simulatorSDK"]?.stderr == "SDK unavailable")
    let output = fixture.url.appendingPathComponent("artifacts/toolchain.intoto.json")
    #expect(try statement.write(to: output) == 1)
    #expect(try JSONDecoder().decode(ToolchainStatement.self, from: Data(contentsOf: output)) == statement)
}

@Test func missingSubjectFailsInsteadOfInventingDigest() throws {
    let fixture = try fixture()
    defer { fixture.remove() }
    try FileManager.default.removeItem(at: fixture.url.appendingPathComponent("flake.lock"))
    #expect(throws: (any Error).self) { try collect(fixture.url) }
}

@Test func failedProbeDiagnosticsIdentifyCommandsAndKeepFailureDetails() throws {
    let fixture = try fixture()
    defer { fixture.remove() }
    var statement = try collect(fixture.url)
    #expect(statement.failureDiagnostics.isEmpty)
    statement.predicate.observations["simulatorSDK"] = Observation(
        command: ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
        executable: "/usr/bin/xcrun", exitCode: 1, stdout: "", stderr: "SDK unavailable\n")
    statement.predicate.observations["nix"] = Observation(
        command: ["nix", "--version"], executable: nil, exitCode: 127, stdout: "", stderr: "Command not found: nix")
    #expect(statement.failureDiagnostics == """
    nix: nix --version exited 127
    Command not found: nix
    simulatorSDK: xcrun --sdk iphonesimulator --show-sdk-version exited 1
    SDK unavailable
    """)
    statement.predicate.observations["nix"]?.stderr = ""
    statement.predicate.observations["nix"]?.stdout = "stdout diagnostic\n"
    #expect(statement.failureDiagnostics.contains("nix: nix --version exited 127\nstdout diagnostic"))
}

@Test func hashingHandlesEmptyAndBinaryFilesWithUnusualNames() throws {
    let fixture = try TemporaryDirectory(prefix: "hash-fixture")
    defer { fixture.remove() }
    let file = fixture.url.appendingPathComponent("- bytes\nwith spaces")
    try Data().write(to: file)
    #expect(try sha256(file) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    try Data([0, 255, 10, 128]).write(to: file)
    #expect(try sha256(file) == "2d75f84de96be6dba9b1e48d2994df26ede680ad1f7cfb0263d1252f08655694")
    try FileManager.default.removeItem(at: file)
    #expect(throws: (any Error).self) { try sha256(file) }
}
