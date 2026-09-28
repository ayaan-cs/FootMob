// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FootMobKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FootMobKit", targets: ["FootMobKit"])
    ],
    targets: [
        .target(
            name: "FootMobKit",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "FootMobKitTests",
            dependencies: ["FootMobKit"],
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v5]
)
