// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EVChargingAssistant",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "EVCore", targets: ["EVCore"]),
        .executable(name: "repo-tools", targets: ["RepoTools"])
    ],
    targets: [
        .target(name: "EVCore"),
        .testTarget(name: "EVCoreTests", dependencies: ["EVCore"]),
        .target(name: "RepoToolsSupport", path: "Tools/RepoToolsSupport"),
        .executableTarget(name: "RepoTools", dependencies: ["RepoToolsSupport"], path: "Tools/RepoTools"),
        .testTarget(name: "RepoToolsTests", dependencies: ["RepoToolsSupport"])
    ]
)
