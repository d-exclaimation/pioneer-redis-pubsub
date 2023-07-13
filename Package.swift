// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PioneerRedisPubSub",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PioneerRedisPubSub",
            targets: ["PioneerRedisPubSub"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/d-exclaimation/pioneer", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/RediStack.git", from: "2.0.0-gamma.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "PioneerRedisPubSub",
            dependencies: [
                .product(name: "Pioneer", package: "pioneer"),
                .product(name: "RediStack", package: "RediStack")
            ]),
        .testTarget(
            name: "PioneerRedisPubSubTests",
            dependencies: ["PioneerRedisPubSub"]),
    ]
)
