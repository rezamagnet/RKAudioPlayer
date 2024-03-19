// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SereneAudioPlayer",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "SereneAudioPlayer",
            targets: ["SereneAudioPlayer"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/exyte/ActivityIndicatorView.git", from: "0.0.1"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "SereneAudioPlayer",
            dependencies: [
                "ActivityIndicatorView",
                "Kingfisher"
        ],
            resources: [.process("Assets")]
        ),
        .testTarget(
            name: "SereneAudioPlayerTests",
            dependencies: ["SereneAudioPlayer"]),
    ]
)
