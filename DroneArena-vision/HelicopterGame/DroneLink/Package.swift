// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DroneLink",
    platforms: [.visionOS(.v2), .iOS(.v18), .macOS(.v15)],
    products: [.library(name: "DroneLink", targets: ["DroneLink"])],
    targets: [
        .target(name: "DroneLink"),
        .testTarget(name: "DroneLinkTests", dependencies: ["DroneLink"], resources: [.copy("Fixtures")]),
    ]
)
