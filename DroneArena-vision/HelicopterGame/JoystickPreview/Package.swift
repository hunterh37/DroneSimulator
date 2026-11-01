// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JoystickPreview",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../DicyaninVirtualJoystick")
    ],
    targets: [
        .executableTarget(
            name: "JoystickPreview",
            dependencies: ["DicyaninVirtualJoystick"])
    ]
)
