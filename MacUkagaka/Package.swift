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
        .library(name: "MacUkagaka", targets: ["MacUkagaka"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MacUkagaka",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras")
            ],
            path: "MacUkagaka",
            resources: [
                .copy("Resources/AINanikaAIChan")
            ]
        )
    ]
)