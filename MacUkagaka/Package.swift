// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MacUkagaka",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "MacUkagaka", targets: ["MacUkagaka"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacUkagaka",
            dependencies: [],
            path: "MacUkagaka",
            resources: [
                .copy("Resources/AINanikaAIChan")
            ]
        )
    ]
)