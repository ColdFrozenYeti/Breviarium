import SwiftUI

@main
struct BreviariumApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(dateSource: Self.launchDateSource)
        }
    }

    /// Normally "now" -- overridable via the `BREVIARIUM_SNAPSHOT_DATE` environment
    /// variable (`yyyy-MM-dd`) so UI tests can capture deterministic snapshots for a
    /// specific named date (`CLAUDE.md`'s snapshot matrix) instead of whatever day it
    /// happens to be when CI runs. Parsed as plain integers, not through `Date`, so
    /// there's no timezone to get wrong.
    private static var launchDateSource: ContentView.DateSource {
        guard let dateString = ProcessInfo.processInfo.environment["BREVIARIUM_SNAPSHOT_DATE"] else { return .now }
        let parts = dateString.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .now }
        return .fixed(day: parts[2], month: parts[1], year: parts[0])
    }
}
