// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickSnap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "QuickSnapCore", targets: ["QuickSnapCore"]),
        .executable(name: "QuickSnap", targets: ["QuickSnap"])
    ],
    targets: [
        .target(
            name: "QuickSnapCore",
            path: "Sources/QuickSnapCore"
        ),
        .executableTarget(
            name: "QuickSnap",
            dependencies: ["QuickSnapCore"],
            path: "Sources/QuickSnap"
        )
    ]
)
