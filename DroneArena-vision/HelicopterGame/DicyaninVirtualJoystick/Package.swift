// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DicyaninVirtualJoystick",
    platforms: [
        .visionOS(.v2),
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "DicyaninVirtualJoystick",
            targets: ["DicyaninVirtualJoystick"]),
    ],
    targets: [
        .target(
            name: "DicyaninVirtualJoystick")
    ]
)
