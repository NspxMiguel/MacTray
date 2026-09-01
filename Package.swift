// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacTray",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacTray", targets: ["MacTray"]),
        .library(name: "MacTrayCore", targets: ["MacTrayCore"]),
    ],
    targets: [
        .target(name: "MacTrayCore", path: "Sources/MacTrayCore"),
        .executableTarget(
            name: "MacTray",
            dependencies: ["MacTrayCore"],
            path: "Sources/MacTray"
        ),
        .testTarget(
            name: "MacTrayTests",
            dependencies: ["MacTrayCore"],
            path: "Tests/MacTrayTests"
        ),
    ]
)
