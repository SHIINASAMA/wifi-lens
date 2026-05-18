// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TinyWiFiAnalyzer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TinyWiFiAnalyzer", targets: ["TinyWiFiAnalyzer"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "TinyWiFiAnalyzer",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "TinyWiFiAnalyzerTests",
            dependencies: ["TinyWiFiAnalyzer"]
        ),
    ]
)
