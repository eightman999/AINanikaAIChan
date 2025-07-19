// swift-tools-version:5.7
//  © eightman 2005-2025
//  Furin-lab All Rights Reserved.
//  MacUkagakaをビルドするためのSwiftパッケージマニフェスト。
import PackageDescription

/// Swift Packageの定義。
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