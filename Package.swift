// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MarkIt",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MarkItCore",
            path: "Sources/MarkItCore"
        ),
        .executableTarget(
            name: "MarkIt",
            dependencies: ["MarkItCore"],
            path: "Sources/MarkIt"
        ),
        .testTarget(
            name: "MarkItCoreTests",
            dependencies: ["MarkItCore"],
            path: "Tests/MarkItCoreTests"
        )
    ]
)
