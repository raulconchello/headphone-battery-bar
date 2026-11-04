// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "HeadphoneBatteryBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HeadphoneBatteryBar", targets: ["HeadphoneBatteryBar"])],
    targets: [
        .target(name: "BatteryCore"),
        .executableTarget(name: "HeadphoneBatteryBar", dependencies: ["BatteryCore"]),
        .testTarget(name: "BatteryCoreTests", dependencies: ["BatteryCore"]),
    ]
)
