// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwitchIMCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwitchIMCore", targets: ["SwitchIMCore"]),
    ],
    targets: [
        .target(name: "SwitchIMCore"),
        .testTarget(name: "SwitchIMCoreTests", dependencies: ["SwitchIMCore"]),
    ]
)