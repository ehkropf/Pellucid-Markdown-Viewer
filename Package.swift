// swift-tools-version: 6.0
//
// md_viewr — Native macOS markdown viewer
// Copyright (C) 2026 Everett Kropf
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
            path: "md_viewr",
            swiftSettings: [
                .enableExperimentalFeature("IsolatedDeinit"),
            ]
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
