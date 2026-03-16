// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "md_viewr",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.1"),
        .package(url: "https://github.com/mgriebling/SwiftMath.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "md_viewr",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "SwiftMath", package: "SwiftMath"),
            ],
            path: "md_viewr"
        ),
        .testTarget(
            name: "md_viewrTests",
            dependencies: [
                "md_viewr",
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "md_viewrTests"
        ),
    ]
)
