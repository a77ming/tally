// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Tally",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tally",
            path: "Sources/Tally"
        )
    ]
)
