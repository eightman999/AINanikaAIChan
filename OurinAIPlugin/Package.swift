// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OurinAIPlugin",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "AINanikaCore", targets: ["AINanikaCore"]),
        .library(name: "AINanikaShioriModule", type: .dynamic, targets: ["AINanikaShioriModule"]),
        .executable(name: "ainanika-cli", targets: ["AINanikaCLI"])
    ],
    targets: [
        .target(
            name: "AINanikaCore"
        ),
        .target(
            name: "AINanikaShioriModule",
            dependencies: ["AINanikaCore"]
        ),
        .executableTarget(
            name: "AINanikaCLI",
            dependencies: ["AINanikaShioriModule"]
        ),
        .testTarget(
            name: "AINanikaCoreTests",
            dependencies: ["AINanikaCore"]
        )
    ]
)
