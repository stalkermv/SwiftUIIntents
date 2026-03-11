// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUIIntents",
    platforms: [.iOS(.v17), .macOS(.v15), .tvOS(.v17), .watchOS(.v11)],
    products: [
        .library(name: "SwiftUIIntents", targets: ["SwiftUIIntents"])
    ],
    dependencies: [
        .package(url: "https://github.com/stalkermv/CustomComponents.git", from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.3"),
    ],
    targets: [
        .target(
            name: "SwiftUIIntents",
            dependencies: [
                .product(name: "CustomComponents", package: "CustomComponents"),
                .product(name: "ServiceContextModule", package: "swift-service-context")
            ],
        ),
        .testTarget(
            name: "SwiftUIIntentsTests",
            dependencies: [
                "SwiftUIIntents",
                .product(name: "CustomComponents", package: "CustomComponents"),
                .product(name: "ViewInspector", package: "ViewInspector"),
            ]
        ),
    ]
)
