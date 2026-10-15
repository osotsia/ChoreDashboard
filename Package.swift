// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChoreDashboard",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ChoreDashboard",
            path: "Sources"
        ),
        .testTarget(
            name: "ChoreDashboardTests",
            dependencies: ["ChoreDashboard"],
            path: "Tests/ChoreDashboardTests"
        )
    ]
)