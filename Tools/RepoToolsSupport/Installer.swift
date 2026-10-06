import Foundation

func verifyArchive(_ archive: URL, expectedSHA256: String) throws {
    try require(matches(expectedSHA256, "^[0-9a-f]{64}$"), "Invalid XcodeGen SHA-256")
    let actual = try sha256(archive)
    try require(actual == expectedSHA256, "XcodeGen checksum mismatch; refusing to extract or execute download.")
}

func installPayload(from release: URL, to destination: URL) throws {
    let fm = FileManager.default
    let paths = ["bin/xcodegen", "share/xcodegen/SettingPresets", "LICENSE"]
    for path in paths {
        try require(fm.fileExists(atPath: release.appendingPathComponent(path).path), "Incomplete XcodeGen release: missing \(path)")
    }
    for path in paths {
        let target = destination.appendingPathComponent(path)
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        try fm.copyItem(at: release.appendingPathComponent(path), to: target)
    }
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.appendingPathComponent("bin/xcodegen").path)
}

public func installXcodeGen(root: URL, runner: CommandRunner) throws {
    let config = try readJSON(ToolchainConfig.self, root: root, path: "config/toolchain.json").xcodegen
    let temporary = try TemporaryDirectory(prefix: "xcodegen-install")
    defer { temporary.remove() }
    let archive = temporary.url.appendingPathComponent("xcodegen.zip")
    _ = try runner.run(["/usr/bin/curl", "--fail", "--location", "--retry", "3", "--output", archive.path,
                        config.url], timeout: 300).checked()
    try verifyArchive(archive, expectedSHA256: config.sha256)
    print("Verified XcodeGen archive SHA-256.")
    let unpacked = temporary.url.appendingPathComponent("unpacked")
    _ = try runner.run(["/usr/bin/unzip", "-q", archive.path, "-d", unpacked.path]).checked()
    let destination = root.appendingPathComponent(".tools/xcodegen")
    try installPayload(from: unpacked.appendingPathComponent("xcodegen"), to: destination)
    print(try runner.run([destination.appendingPathComponent("bin/xcodegen").path, "--version"]).checked(), terminator: "")
}
