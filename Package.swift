// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Parabus",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        // Core library shared between app, widget, and live activities
        .library(
            name: "ParabusCore",
            targets: ["ParabusCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        // Shared core: Models, Services, ViewModels, Theme, Core (DI/Protocols)
        .target(
            name: "ParabusCore",
            dependencies: ["SwiftSoup"],
            path: ".",
            exclude: [
                "Sources/App",
                "ParabusWidget",
                "Parabus.xcodeproj",
                ".build",
                "Tests",
                "Parabus.entitlements",
                "WIDGET_SETUP.md"
            ],
            sources: [
                "Sources/Core",
                "Sources/Models",
                "Sources/Services",
                "Sources/ViewModels",
                "Sources/Views",
                "Sources/Theme",
                "Shared"
            ],
            resources: [
                .copy("Sources/Resources/GTFS")
            ]
        ),
        .testTarget(
            name: "ParabusCoreTests",
            dependencies: ["ParabusCore"],
            path: "Tests"
        ),
    ]
)
