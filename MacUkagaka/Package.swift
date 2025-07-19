// swift-tools-version:5.7
//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  Swift package manifest for building MacUkagaka.
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