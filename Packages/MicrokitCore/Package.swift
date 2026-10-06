// swift-tools-version: 6.0
import PackageDescription

// Pure Swift: the VIA wire protocol, keycode tables, keyboard definitions, macros and backups.
// No IOKit and no AppKit here, so everything is testable with `swift test` against a fake transport.
let package = Package(
    name: "MicrokitCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MicrokitCore", targets: ["MicrokitCore"]),
    ],
    targets: [
        .target(name: "MicrokitCore"),
        .testTarget(
            name: "MicrokitCoreTests",
            dependencies: ["MicrokitCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
