// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "CodableKeychain",
    platforms: [
        .ios(.v13.0),
    ],
    products: [
        .library(name: "CodableKeychain", targets: ["CodableKeychain"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "CodableKeychain", dependencies: ["Utility"]),
        .testTarget(name: "CodableKeychainTests", dependencies: ["CodableKeychain"]),
    ]
)
