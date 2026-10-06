import Foundation

struct ToolchainConfig: Decodable {
    struct XcodeGen: Decodable { var version: String; var url: String; var sha256: String }
    var nixVersion: String
    var swiftLanguageVersion: String
    var minimumIOS: String
    var xcodegen: XcodeGen
    var actions: [String: String]
}

public func validateRepository(root: URL) throws {
    let required = [
        "Package.swift", "project.yml", "README.md", "AGENTS.md", "docs/DEVELOPMENT_PLAN.md",
        "docs/ARCHITECTURE.md", "docs/BLUETOOTH.md", "docs/TEST_STRATEGY.md", "docs/SECURITY_AND_PRIVACY.md",
        "docs/BACKLOG.md", "docs/BOOTSTRAP_VALIDATION.md", ".github/workflows/ci.yml",
        "Apps/EVChargingAssistant/EVChargingAssistantApp.swift", "Apps/EVChargingAssistant/BluetoothScanner.swift",
        "UITests/DashboardUITests.swift", "config/compatibility.json", "flake.nix", "flake.lock", "nix/xcodegen.nix",
        "Tools/RepoTools/main.swift", "Tools/RepoToolsSupport/Attestation.swift",
        "Tools/RepoToolsSupport/Toolchain.swift", "Tests/RepoToolsTests/AttestationTests.swift"
    ]
    let fm = FileManager.default
    func file(_ name: String) -> URL { root.appendingPathComponent(name) }
    func contents(_ name: String) throws -> String { try String(contentsOf: file(name), encoding: .utf8) }
    for name in required {
        try require(fm.fileExists(atPath: file(name).path), "Missing \(name)")
    }
    for script in try fm.contentsOfDirectory(at: file("scripts"), includingPropertiesForKeys: [.isRegularFileKey]) {
        if try script.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            try require(matches(script.lastPathComponent, #"^[a-z0-9]+(?:-[a-z0-9]+)*\.(sh|swift)$"#),
                        "Script filenames must use kebab-case and Bash or Swift: \(script.lastPathComponent)")
        }
    }
    let excluded: Set<String> = [".git", ".build", ".swiftpm", ".tools", "artifacts", "local-evidence", "DerivedData"]
    guard let files = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else {
        throw ToolError("Cannot enumerate repository")
    }
    for case let path as URL in files {
        if excluded.contains(path.lastPathComponent) { files.skipDescendants(); continue }
        guard path.pathExtension == "md" else { continue }
        for capture in captures(try String(contentsOf: path, encoding: .utf8), #"(?<!!)\[[^\]]+\]\(([^)]+)\)"#) {
            let target = capture[0]
            if target.contains("://") || target.hasPrefix("#") || target.hasPrefix("mailto:") { continue }
            let relative = target.components(separatedBy: "#")[0]
            let resolved = path.deletingLastPathComponent().appendingPathComponent(relative).standardizedFileURL
            try require(fm.fileExists(atPath: resolved.path), "Broken link in \(path.path): \(target)")
        }
    }
    // Commands remain arbitrary JSON definitions; validation checks only the enablement boundary.
    let compatibility = try JSONSerialization.jsonObject(with: Data(contentsOf: file("config/compatibility.json")))
    guard let compatibility = compatibility as? [String: Any], compatibility["schemaVersion"] as? Int == 1,
          let profiles = compatibility["profiles"] as? [[String: Any]] else {
        throw ToolError("Invalid compatibility schema")
    }
    for profile in profiles {
        guard let status = profile["status"] as? String,
              ["unverified", "verified", "unsupported"].contains(status),
              let commands = profile["readCommands"] as? [Any] else { throw ToolError("Invalid compatibility profile") }
        if status == "verified" {
            guard let report = profile["evidenceReport"] as? String, !report.isEmpty,
                  fm.fileExists(atPath: file(report).path) else { throw ToolError("Verified profile needs a report") }
            try require(!commands.isEmpty, "Verified profile needs reviewed request definitions")
        } else { try require(commands.isEmpty, "Unverified profile cannot enable commands") }
    }
    let project = try contents("project.yml")
    try require(project.contains("NSBluetoothAlwaysUsageDescription:"), "Missing Bluetooth usage description")
    try require(!project.contains("UIBackgroundModes:"), "Background support is not implemented yet")
    let scanner = try contents("Apps/EVChargingAssistant/BluetoothScanner.swift")
    try require(!scanner.contains("writeValue(") && !scanner.contains(".connect("), "Scanner must remain discovery-only")
    let workflow = try contents(".github/workflows/ci.yml")
    let toolchain = try readJSON(ToolchainConfig.self, root: root, path: "config/toolchain.json")
    for action in ["checkout", "uploadArtifact", "installNix"] {
        guard let sha = toolchain.actions[action], matches(sha, "^[0-9a-f]{40}$"), workflow.contains(sha) else {
            throw ToolError("Missing or mismatched action pin: \(action)")
        }
    }
    try require(workflow.contains("nix-\(toolchain.nixVersion)/install"), "Nix installer version mismatch")
    try require(project.contains(toolchain.xcodegen.version), "XcodeGen project version mismatch")
    try require(matches(toolchain.xcodegen.sha256, "^[0-9a-f]{64}$"), "Invalid XcodeGen SHA-256")
    try require(!workflow.contains("pull_request_target") && workflow.contains("contents: read"), "Unsafe workflow permissions")
    for capture in captures(workflow, #"uses:\s+([^\s#]+)"#) {
        try require(matches(capture[0], "^[^@]+@[0-9a-f]{40}$"), "Unpinned action: \(capture[0])")
    }
    struct Lock: Decodable {
        struct Node: Decodable {
            struct Pin: Decodable { var rev: String; var narHash: String }
            var locked: Pin?
        }
        var nodes: [String: Node]
    }
    let lock = try readJSON(Lock.self, root: root, path: "flake.lock")
    guard let pin = lock.nodes["nixpkgs"]?.locked else { throw ToolError("Missing Nixpkgs lock") }
    try require(matches(pin.rev, "^[0-9a-f]{40}$") && pin.narHash.hasPrefix("sha256-"), "Nixpkgs must be commit-pinned and content-hashed")
    let issues = try readJSON([BacklogIssue].self, root: root, path: ".github/backlog.json")
    try Backlog.validate(issues)
    print("Structural checks passed: \(required.count) required files, Markdown links, \(profiles.count) compatibility candidates, \(issues.count) acyclic backlog items, SHA-pinned Actions and foreground-only scanner policy.")
    print("Swift compilation, behavioral tests, UI tests and hardware tests are separate checks.")
}
