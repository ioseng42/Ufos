// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Ufos",
    platforms: [
        .macOS(.v10_12), .iOS(.v10), .tvOS(.v12), .watchOS(.v5)
    ],
    products: [
        .library(name: "Ufos", targets: ["Ufos"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "Ufos", dependencies: []),
        .testTarget(name: "UfosTests", dependencies: ["Ufos"]),
    ],
    swiftLanguageVersions: [.v5]
)
