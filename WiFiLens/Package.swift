// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WiFiLens",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "WiFiLens", targets: ["WiFiLens"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "WiFiLens",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WiFiLensTests",
            dependencies: ["WiFiLens"]
        ),
    ]
)
