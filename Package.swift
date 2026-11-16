// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hush",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Hush", targets: ["Hush"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "Hush",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift")
            ],
            path: "Sources/Hush",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
