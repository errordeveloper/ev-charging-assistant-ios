import Foundation
import RepoToolsSupport

let usage = """
Usage: swift run repo-tools <command> [options]
  validate                         Check repository contracts and links
  check-toolchain                  Check Nix tools and the host Apple toolchain
  check-xcodegen                   Verify bundled generator presets
  record-toolchain [--output PATH] Write an unsigned in-toto toolchain statement
  select-simulator [--input PATH]  Print an available iPhone simulator UDID
  install-xcodegen                 Install the checksum-pinned standalone generator
  import-backlog [--repository OWNER/REPO] [--apply]
                                  Preview issues; --apply explicitly creates them
All commands accept --repo-root PATH. Defaults: artifacts/toolchain.intoto.json,
artifacts/simulators.json, and the repository containing the current directory.
"""

func main() throws -> Int32 {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let command = arguments.first, command != "--help", command != "-h" else {
        print(usage)
        return 0
    }
    let allowed: [String: Set<String>] = [
        "validate": [], "check-toolchain": [], "check-xcodegen": [], "install-xcodegen": [],
        "record-toolchain": ["--output"], "select-simulator": ["--input"],
        "import-backlog": ["--repository", "--apply"]
    ]
    guard let options = allowed[command] else { throw ToolError("Unknown command: \(command)\n\(usage)") }
    var values: [String: String] = [:]
    var apply = false
    var index = 1
    while index < arguments.count {
        let argument = arguments[index]
        guard options.contains(argument) || argument == "--repo-root" else { throw ToolError("Unknown option: \(argument)") }
        if argument == "--apply" { apply = true } else {
            index += 1
            guard index < arguments.count, !arguments[index].hasPrefix("--"), values[argument] == nil else {
                throw ToolError("Expected one value for \(argument)")
            }
            values[argument] = arguments[index]
        }
        index += 1
    }
    var root = URL(fileURLWithPath: values["--repo-root"] ?? FileManager.default.currentDirectoryPath).standardizedFileURL
    if values["--repo-root"] == nil {
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("config/toolchain.json").path) {
            guard root.path != "/" else { throw ToolError("Repository not found; pass --repo-root PATH") }
            root.deleteLastPathComponent()
        }
    }
    let runner = CommandRunner(root: root)
    switch command {
    case "validate": try validateRepository(root: root)
    case "check-toolchain": try checkToolchain(root: root, runner: runner)
    case "check-xcodegen": try checkXcodeGen(runner: runner)
    case "record-toolchain":
        let output = URL(fileURLWithPath: values["--output"] ?? "artifacts/toolchain.intoto.json", relativeTo: root)
        let statement = try Attestation.collect(root: root, run: { runner.run($0) })
        let status = try statement.write(to: output)
        print("Wrote unsigned toolchain statement to \(output.path)")
        if status != 0 { print("Toolchain collection was incomplete; inspect the recorded command errors.") }
        return status
    case "select-simulator":
        let input = URL(fileURLWithPath: values["--input"] ?? "artifacts/simulators.json", relativeTo: root)
        print(try SimulatorSelector.select(from: Data(contentsOf: input)))
    case "install-xcodegen": try installXcodeGen(root: root, runner: runner)
    case "import-backlog": try importBacklog(root: root, repository: values["--repository"], apply: apply, runner: runner)
    default: break
    }
    return 0
}

do { exit(try main()) } catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
