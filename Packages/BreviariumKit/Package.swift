// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BreviariumKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "BreviariumKit", targets: ["BreviariumKit"]),
        .executable(name: "BreviariumData", targets: ["BreviariumData"]),
    ],
    targets: [
        // The engine: calendar, rubrics, office assembly, text model.
        // Foundation only — must build and test on Linux and Windows.
        .target(
            name: "BreviariumKit"
        ),
        .testTarget(
            name: "BreviariumKitTests",
            dependencies: ["BreviariumKit"]
        ),

        // The build-time data pipeline logic, kept as a library so it's unit-testable.
        .target(
            name: "BreviariumDataCore",
            dependencies: ["BreviariumKit"]
        ),
        .testTarget(
            name: "BreviariumDataTests",
            dependencies: ["BreviariumDataCore"]
        ),

        // Thin CLI entry point over BreviariumDataCore.
        .executableTarget(
            name: "BreviariumData",
            dependencies: ["BreviariumDataCore"]
        ),

        // Diffs engine output against the committed Divinum Officium oracle fixtures
        // (data/oracle-fixtures, generated in M4). Fixture loading is added once that
        // data exists — SPM resources must live inside the target's own directory, so
        // the loader will read from the repo-relative path via FileManager rather than
        // as a declared SPM resource.
        .testTarget(
            name: "OracleTests",
            dependencies: ["BreviariumKit"]
        ),
    ]
)
