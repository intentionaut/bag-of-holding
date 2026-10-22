// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "BagOfHolding",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BagCore"),
        .executableTarget(name: "BagOfHolding", dependencies: ["BagCore"]),
        .testTarget(name: "BagCoreTests", dependencies: ["BagCore"]),
    ]
)
