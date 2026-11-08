// swift-tools-version: 5.9
import PackageDescription

// RunCore is the platform-agnostic half of the capture spine: the Run object,
// the speed/distance cleaning pipeline, and GPX import/export. It has no
// UIKit/SwiftUI/CoreLocation dependency so it can be unit-tested on macOS
// with `swift test` and ported to another platform later (brief §2).
let package = Package(
    name: "RunCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RunCore", targets: ["RunCore"]),
    ],
    targets: [
        .target(name: "RunCore"),
        .testTarget(name: "RunCoreTests", dependencies: ["RunCore"]),
    ]
)
