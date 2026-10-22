// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "BagOfHolding",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BagOfHolding", targets: ["BagOfHolding"]),
        .executable(name: "bag", targets: ["BagCLI"]),
    ],
    targets: [
        .target(name: "BagCore"),
        .executableTarget(name: "BagOfHolding", dependencies: ["BagCore"]),
        .executableTarget(name: "BagCLI", dependencies: ["BagCore"]),
        .testTarget(name: "BagCoreTests", dependencies: ["BagCore"]),
    ]
)
