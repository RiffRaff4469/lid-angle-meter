// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "LidAngleMeter",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "LidAngleMeter", targets: ["LidAngleMeter"])
    ],
    targets: [
        .executableTarget(
            name: "LidAngleMeter",
            path: "Sources/LidAngleMeter"
        )
    ]
)
