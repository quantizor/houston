// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HoustonKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Models", targets: ["Models"]),
        .library(name: "LaunchdService", targets: ["LaunchdService"]),
        .library(name: "PrivilegedHelper", targets: ["PrivilegedHelper"]),
        .library(name: "JobAnalyzer", targets: ["JobAnalyzer"]),
        .library(name: "LogViewer", targets: ["LogViewer"]),
        .library(name: "PlistEditor", targets: ["PlistEditor"]),
    ],
    targets: [
        // MARK: - Modules

        .target(
            name: "Models",
            dependencies: []
        ),
        .target(
            name: "LaunchdService",
            dependencies: ["Models", "PrivilegedHelper"]
        ),
        .target(
            name: "PrivilegedHelper",
            dependencies: ["Models"]
        ),
        .target(
            name: "JobAnalyzer",
            dependencies: ["Models", "LaunchdService"]
        ),
        .target(
            name: "LogViewer",
            dependencies: ["Models"]
        ),
        .target(
            name: "PlistEditor",
            dependencies: ["Models", "LaunchdService"]
        ),

        // MARK: - Tests

        .testTarget(
            name: "ModelsTests",
            dependencies: ["Models"]
        ),
        .testTarget(
            name: "LaunchdServiceTests",
            dependencies: ["LaunchdService"]
        ),
        .testTarget(
            name: "PrivilegedHelperTests",
            dependencies: ["PrivilegedHelper"]
        ),
        .testTarget(
            name: "JobAnalyzerTests",
            dependencies: ["JobAnalyzer"]
        ),
        .testTarget(
            name: "LogViewerTests",
            dependencies: ["LogViewer"]
        ),
        .testTarget(
            name: "PlistEditorTests",
            dependencies: ["PlistEditor"]
        ),
    ]
)
