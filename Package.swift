// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickSnap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "QuickSnap", targets: ["QuickSnap"])
    ],
    targets: [
        .executableTarget(
            name: "QuickSnap",
            path: "Sources/QuickSnap"
        )
    ]
)
