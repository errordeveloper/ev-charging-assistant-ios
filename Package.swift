// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EVChargingAssistant",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "EVCore", targets: ["EVCore"]),
        .executable(name: "repo-tools", targets: ["RepoTools"])
    ],
    dependencies: [
        // 4.3.1 is the latest Swift Crypto release supporting Swift 6.0.
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "4.3.1")
    ],
    targets: [
        .target(name: "EVCore"),
        .testTarget(name: "EVCoreTests", dependencies: ["EVCore"]),
        .target(name: "RepoToolsSupport", dependencies: [
            .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
        ], path: "Tools/RepoToolsSupport"),
        .executableTarget(name: "RepoTools", dependencies: ["RepoToolsSupport"], path: "Tools/RepoTools"),
        .testTarget(name: "RepoToolsTests", dependencies: ["RepoToolsSupport"])
    ]
)
