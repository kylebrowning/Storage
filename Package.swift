// swift-tools-version:5.1

import PackageDescription
let package = Package(
    name: "swift-storage",
    platforms: [
       .macOS(.v10_14),
       .iOS(.v12)
    ],
    products: [
        .library(name: "Storage", targets: ["Storage"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Storage", dependencies: []),
        .testTarget(name: "StorageTests", dependencies: [
            .target(name: "Storage")
        ])
    ]
)
