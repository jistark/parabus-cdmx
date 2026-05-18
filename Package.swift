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
    dependencies: [],
    targets: [
        // Shared core: Models, Services, ViewModels, Theme, Core (DI/Protocols)
        .target(
            name: "ParabusCore",
            dependencies: [],
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
                // GTFS schedule data (stop_times.txt) removed in HIGH-16:
                // the worker's /static/schedule + /static/travel-time
                // endpoints replaced the bundled file. -56MB binary size.
                .copy("Sources/Resources/Fonts")
            ]
        ),
        .testTarget(
            name: "ParabusCoreTests",
            dependencies: ["ParabusCore"],
            path: "Tests"
        ),
    ]
)
