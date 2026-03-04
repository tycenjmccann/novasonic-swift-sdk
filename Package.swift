// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NovaSonic",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(name: "NovaSonicCore", targets: ["NovaSonicCore"]),
        .library(name: "NovaSonicUI", targets: ["NovaSonicUI"])
    ],
    dependencies: [
        // AWS SDK for Swift - compatible with applications using version 1.2.59 and above
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", exact: "1.2.59")
    ],
    targets: [
        .target(
            name: "NovaSonicCore",
            dependencies: [
                // Import only specific AWS services (no umbrella imports)
                .product(name: "AWSBedrockRuntime", package: "aws-sdk-swift"),
                .product(name: "AWSSDKIdentity", package: "aws-sdk-swift"),
                .product(name: "AWSBedrockAgentRuntime", package: "aws-sdk-swift"),
                .product(name: "AWSDynamoDB", package: "aws-sdk-swift")
            ],
            path: "Sources/NovaSonicCore",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("IOS_AUDIO", .when(platforms: [.iOS, .tvOS, .watchOS]))
            ]
        ),
        .target(
            name: "NovaSonicUI",
            dependencies: ["NovaSonicCore"],
            path: "Sources/NovaSonicUI"
        )
    ]
)
