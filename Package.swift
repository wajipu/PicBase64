// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "PicBase64",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PicBase64", targets: ["PicBase64App"]),
        .executable(name: "picbase64-mcp", targets: ["PicBase64MCP"]),
        .library(name: "PicBase64Core", targets: ["PicBase64Core"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", exact: "0.12.1")
    ],
    targets: [
        .target(
            name: "PicBase64Core",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .executableTarget(
            name: "PicBase64App",
            dependencies: ["PicBase64Core"],
            path: "Sources/PicBase64App",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .executableTarget(
            name: "PicBase64MCP",
            dependencies: [
                "PicBase64Core",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/PicBase64MCP",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        ),
        .testTarget(
            name: "PicBase64CoreTests",
            dependencies: ["PicBase64Core"]
        )
    ]
)
