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
        .target(
            name: "AppFeature",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: ["AppFeature"]
        ),
    ],
    // Swift 6 language mode for full data-race safety (strict concurrency).
    swiftLanguageModes: [.v6]
)
