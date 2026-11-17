// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftLens",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "SwiftLens",
            path: "Sources/SwiftLens",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
