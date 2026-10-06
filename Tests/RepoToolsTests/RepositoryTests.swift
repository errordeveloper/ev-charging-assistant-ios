import Foundation
import Testing
@testable import RepoToolsSupport

private func issue(_ id: String, dependsOn: [String] = []) -> BacklogIssue {
    BacklogIssue(id: id, title: "Title \(id)", body: "Body\nwith literal `code` and $HOME",
                 dependsOn: dependsOn, acceptanceCriteria: ["Preserve newlines", "No shell expansion"])
}

@Test func backlogRejectsDuplicateUnknownAndCyclicDependencies() throws {
    try Backlog.validate([issue("A"), issue("B", dependsOn: ["A"])])
    #expect(throws: ToolError.self) { try Backlog.validate([issue("A"), issue("A")]) }
    #expect(throws: ToolError.self) { try Backlog.validate([issue("A", dependsOn: ["missing"])]) }
    #expect(throws: ToolError.self) { try Backlog.validate([issue("A", dependsOn: ["A"])]) }
    #expect(throws: ToolError.self) {
        try Backlog.validate([issue("A", dependsOn: ["B"]), issue("B", dependsOn: ["A"])])
    }
}

@Test func githubIssueBodyPreservesMarkdown() {
    #expect(issue("A", dependsOn: ["B"]).githubBody == """
    Body
    with literal `code` and $HOME

    Dependencies: B

    Acceptance criteria:

    - [ ] Preserve newlines
    - [ ] No shell expansion

    Follow AGENTS.md and attach exact software/hardware evidence. See docs/DEVELOPMENT_PLAN.md.
    """)
}

@Test func archiveChecksumMismatchIsRejected() throws {
    let fixture = try TemporaryDirectory(prefix: "archive-fixture")
    defer { fixture.remove() }
    let archive = fixture.url.appendingPathComponent("archive.zip")
    try Data("abc".utf8).write(to: archive)
    try verifyArchive(archive, expectedSHA256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    #expect(throws: ToolError.self) { try verifyArchive(archive, expectedSHA256: String(repeating: "0", count: 64)) }
}

@Test func installerKeepsPresetsAndRejectsIncompleteRelease() throws {
    let fixture = try TemporaryDirectory(prefix: "installer-fixture")
    defer { fixture.remove() }
    let release = fixture.url.appendingPathComponent("release")
    let destination = fixture.url.appendingPathComponent("installed")
    for name in ["bin/xcodegen", "share/xcodegen/SettingPresets/base.yml", "LICENSE"] {
        let path = release.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("fixture \(name)".utf8).write(to: path)
    }
    try installPayload(from: release, to: destination)
    #expect(FileManager.default.isExecutableFile(atPath: destination.appendingPathComponent("bin/xcodegen").path))
    let installedPresets = destination.appendingPathComponent("share/xcodegen/SettingPresets/base.yml")
    #expect(try String(contentsOf: installedPresets, encoding: .utf8) == "fixture share/xcodegen/SettingPresets/base.yml")
    try FileManager.default.removeItem(at: release.appendingPathComponent("share/xcodegen/SettingPresets"))
    #expect(throws: ToolError.self) { try installPayload(from: release, to: destination) }
    #expect(FileManager.default.fileExists(atPath: installedPresets.path))
}
