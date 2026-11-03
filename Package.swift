// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Touchyy",
    platforms: [.macOS(.v13)],
    targets: [
        // C shim that loads the private MultitouchSupport framework at runtime.
        .target(name: "CMultitouch"),
        .executableTarget(name: "Touchyy", dependencies: ["CMultitouch"]),
        .testTarget(name: "TouchyyTests", dependencies: ["Touchyy"]),
    ]
)
