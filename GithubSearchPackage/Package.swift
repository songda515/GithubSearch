// swift-tools-version: 6.0
// The Package.swift is the single source of truth for app modules.
// Add new feature/client modules here as targets — no .xcodeproj surgery required.
import PackageDescription

let package = Package(
    name: "GithubSearchPackage",
    // Minimum iOS 17.0: lets us use Apple's native Observation framework
    // (@ObservableState) instead of TCA's Perception backport.
    // macOS is declared only so `swift test` can run reducer tests on the host
    // (fast loop, no simulator). The app target itself ships iOS-only.
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "SearchFeature", targets: ["SearchFeature"]),
    ],
    dependencies: [
        // TCA pinned to an exact stable version for reproducible builds.
        // ComposableArchitecture re-exports `Dependencies`, so @Dependency /
        // DependencyKey / liveValue / testValue / previewValue are available
        // without adding swift-dependencies separately.
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.25.5"
        ),
    ],
    targets: [
        // App composition root. Hosts feature modules via Scope.
        .target(
            name: "AppFeature",
            dependencies: [
                "SearchFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: ["AppFeature"]
        ),
        // Search screen (Task 4: shell — title, search bar, empty content area).
        .target(
            name: "SearchFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "SearchFeatureTests",
            dependencies: ["SearchFeature"]
        ),
    ],
    // Swift 6 language mode for full data-race safety (strict concurrency).
    swiftLanguageModes: [.v6]
)
