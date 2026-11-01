// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DicyaninThumbController",
    platforms: [
        .visionOS(.v1),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "DicyaninThumbController",
            targets: ["DicyaninThumbController"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hunterh37/DicyaninARKitSession.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "DicyaninThumbController",
            dependencies: [
                .product(name: "DicyaninARKitSession", package: "DicyaninARKitSession", condition: .when(platforms: [.visionOS]))
            ])
    ]
) 
