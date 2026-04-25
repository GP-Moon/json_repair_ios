// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "json-repair-ios",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "JSONRepairIOS",
            targets: ["JSONRepairIOS"]
        ),
    ],
    targets: [
        .target(
            name: "JSONRepairIOS"
        ),
        .testTarget(
            name: "JSONRepairIOSTests",
            dependencies: ["JSONRepairIOS"]
        ),
    ]
)
