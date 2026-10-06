import Foundation

public func checkToolchain(root: URL, runner: CommandRunner) throws {
    for name in ["git", "xcodegen"] {
        guard let executable = runner.executable(name) else { throw ToolError("Missing \(name)") }
        let resolved = URL(fileURLWithPath: executable).resolvingSymlinksInPath().path
        try require(resolved.hasPrefix("/nix/store/"), "\(name) must come from Nix: \(resolved)")
    }
    for name in ["swift", "swiftc", "xcrun", "xcodebuild"] {
        try require(runner.executable(name) == "/usr/bin/\(name)", "\(name) must use the host's /usr/bin tool")
    }
    for name in ["DEVELOPER_DIR", "SDKROOT", "TOOLCHAINS"] {
        try require(!(runner.environment[name] ?? "").contains("/nix/store/"), "\(name) must use the host's Apple toolchain")
    }
    let config = try readJSON(ToolchainConfig.self, root: root, path: "config/toolchain.json")
    let generator = try runner.run(["xcodegen", "--version"]).checked().trimmingCharacters(in: .whitespacesAndNewlines)
    try require(generator == "Version: \(config.xcodegen.version)", "Unexpected XcodeGen version: \(generator)")
    let swift = try runner.run(["swift", "--version"]).checked()
    guard let version = captures(swift, #"Apple Swift version (\d+\.\d+)"#).first?.first else {
        throw ToolError("Expected Apple Swift: \(swift)")
    }
    try require(version.compare(config.swiftLanguageVersion, options: .numeric) != .orderedAscending,
                "Swift \(config.swiftLanguageVersion)+ is required")
    let sdk = try runner.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).checked()
        .trimmingCharacters(in: .whitespacesAndNewlines)
    try require(matches(sdk, #"^\d+(\.\d+)*$"#) && sdk.compare(config.minimumIOS, options: .numeric) != .orderedAscending,
                "iOS Simulator SDK \(config.minimumIOS)+ is required; found \(sdk)")
    print("Toolchain checks passed: Nix Git/XcodeGen, host Apple tools, minimum Swift and simulator SDK versions.")
}

public func checkXcodeGen(runner: CommandRunner) throws {
    let temporary = try TemporaryDirectory(prefix: "xcodegen-presets")
    defer { temporary.remove() }
    // Generate outside the repository and release archive so loose presets cannot hide an incomplete installation.
    let spec = #"""
    {"name":"PresetCheck","targets":{
      "App":{"type":"application","platform":"iOS"},
      "AppUITests":{"type":"bundle.ui-testing","platform":"iOS","dependencies":[{"target":"App"}]}
    }}
    """#
    try Data(spec.utf8).write(to: temporary.url.appendingPathComponent("project.yml"))
    let isolated = CommandRunner(root: temporary.url, environment: runner.environment)
    print(try isolated.run(["xcodegen", "generate"]).checked(), terminator: "")
    let data = try Data(contentsOf: temporary.url.appendingPathComponent("PresetCheck.xcodeproj/project.pbxproj"))
    guard let project = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let objects = project["objects"] as? [String: [String: Any]], let rootID = project["rootObject"] as? String,
          let root = objects[rootID] else { throw ToolError("Invalid generated project") }
    func configurations(_ owner: [String: Any]) throws -> [String: [String: Any]] {
        guard let id = owner["buildConfigurationList"] as? String,
              let references = objects[id]?["buildConfigurations"] as? [String] else {
            throw ToolError("Missing build configurations")
        }
        var result: [String: [String: Any]] = [:]
        for ref in references {
            guard let configuration = objects[ref], let name = configuration["name"] as? String,
                  let settings = configuration["buildSettings"] as? [String: Any] else {
                throw ToolError("Invalid build configuration")
            }
            result[name] = settings
        }
        try require(Set(result.keys) == ["Debug", "Release"], "Missing Debug/Release configurations")
        return result
    }
    let settings = try configurations(root)
    for name in ["Debug", "Release"] {
        try require(settings[name]?["PRODUCT_NAME"] as? String == "$(TARGET_NAME)", "Missing \(name) PRODUCT_NAME preset")
    }
    try require(settings["Debug"]?["SWIFT_OPTIMIZATION_LEVEL"] as? String == "-Onone", "Missing Debug optimization preset")
    try require(settings["Debug"]?["ONLY_ACTIVE_ARCH"] as? String == "YES", "Missing Debug architecture preset")
    try require(settings["Release"]?["SWIFT_COMPILATION_MODE"] as? String == "wholemodule", "Missing Release preset")
    let targets = objects.values.filter { $0["isa"] as? String == "PBXNativeTarget" }
    try require(Set(targets.compactMap { $0["name"] as? String }) == ["App", "AppUITests"], "Missing generated targets")
    for target in targets {
        for (_, config) in try configurations(target) {
            try require(config["SDKROOT"] as? String == "iphoneos", "Missing iOS platform presets")
            if target["name"] as? String == "AppUITests" {
                try require((config["LD_RUNPATH_SEARCH_PATHS"] as? [String])?.contains("@loader_path/Frameworks") == true,
                            "Missing UI test bundle presets")
            } else {
                try require(config["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String == "AppIcon", "Missing app presets")
            }
        }
    }
    print("XcodeGen regression check passed: product names, Debug/Release, iOS and target presets.")
}
