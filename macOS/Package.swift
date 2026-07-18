// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PolarCoachMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PolarCoachMac", targets: ["PolarCoachMac"])
    ],
    targets: [
        .executableTarget(
            name: "PolarCoachMac",
            path: "Sources/PolarCoachSimple"
        )
    ]
)
