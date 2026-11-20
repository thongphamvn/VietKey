// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VietKey",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "VietKey", targets: ["VietKey"])],
    targets: [
        .target(name: "VietEngine"),
        .executableTarget(
            name: "VietKey",
            dependencies: ["VietEngine"],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("InputMethodKit")]
        ),
        // Chạy test: swift run VietTests  (không dùng XCTest/Swift Testing vì Command Line Tools thiếu)
        .executableTarget(name: "VietTests", dependencies: ["VietEngine"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
