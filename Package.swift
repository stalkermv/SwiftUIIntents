// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIIntents",
    platforms: [.iOS(.v17), .macOS(.v15), .tvOS(.v17), .watchOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "SwiftUIIntents", type: .dynamic, targets: ["SwiftUIIntents"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftUIIntents",
            dependencies: [
                .target(name: "AsyncButton"),
                .product(name: "ServiceContextModule", package: "swift-service-context")
            ],
        ),
        .target(name: "AsyncButton"),
        .testTarget(
            name: "SwiftUIIntentsTests",
            dependencies: ["SwiftUIIntents"]
        ),
    ]
)
