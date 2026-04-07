// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DoNotSleep",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "DoNotSleep",
            targets: ["DoNotSleep"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "DoNotSleep",
            resources: [
                .process("Resources"),
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
