// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sidl",
    platforms: [.macOS(.v13)],
    targets: [
        // C shim that loads the private MultitouchSupport framework at runtime.
        .target(name: "CMultitouch"),
        .executableTarget(name: "Sidl", dependencies: ["CMultitouch"]),
        .testTarget(name: "SidlTests", dependencies: ["Sidl"]),
    ]
)
