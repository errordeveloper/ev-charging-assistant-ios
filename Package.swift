// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EVChargingAssistant",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "EVCore", targets: ["EVCore"])],
    targets: [
        .target(name: "EVCore"),
        .testTarget(name: "EVCoreTests", dependencies: ["EVCore"])
    ]
)
