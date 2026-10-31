// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Tether", platforms: [.macOS(.v14)],
    products: [.library(name: "TetherCore", targets: ["TetherCore"]), .executable(name: "Tether", targets: ["TetherApp"])],
    targets: [
        .target(name: "TetherCore"),
        .executableTarget(name: "TetherApp", dependencies: ["TetherCore"]),
        .testTarget(name: "TetherCoreTests", dependencies: ["TetherCore"]),
        .testTarget(name: "TetherAppTests", dependencies: ["TetherApp", "TetherCore"])
    ], swiftLanguageModes: [.v6]
)
