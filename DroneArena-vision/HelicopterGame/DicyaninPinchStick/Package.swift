// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DicyaninPinchStick",
    platforms: [.visionOS(.v2), .macOS(.v15)],
    products: [
        .library(name: "DicyaninPinchStick", targets: ["PinchStick", "PinchStickCore"]),
    ],
    targets: [
        .target(name: "PinchStickCore"),
        .target(name: "PinchStick", dependencies: ["PinchStickCore"],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "PinchStickCoreTests", dependencies: ["PinchStickCore"]),
    ]
)
