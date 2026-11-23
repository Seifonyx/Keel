// swift-tools-version:5.9
// KEEL: unit tests for Keel's auto-update rules. `Sources/KeelCore` is a symlink to
// SideStore/Keel/Core, so the tests build exactly the file the app ships.
// Run with: cd Keel/Tests && swift test
import PackageDescription

let package = Package(
    name: "KeelCoreTests",
    platforms: [.macOS(.v13), .iOS(.v15)],
    targets: [
        .target(name: "KeelCore", path: "Sources/KeelCore"),
        .testTarget(name: "KeelCoreTests", dependencies: ["KeelCore"], path: "Tests/KeelCoreTests"),
    ]
)
