import BreviariumKit
import SwiftUI

@main
struct BreviariumApp: App {
    var body: some Scene {
        WindowGroup {
            // `BREVIARIUM_SNAPSHOT_SECTION` (a section's raw name, e.g. `hymnus`) opens the
            // office at that section, as the table of contents would, so UI tests can
            // capture a specific section's page deterministically.
            ContentView(
                dateSource: Self.launchDateSource,
                initialSection: ProcessInfo.processInfo.environment["BREVIARIUM_SNAPSHOT_SECTION"],
                // `BREVIARIUM_SNAPSHOT_HOUR` (DO's name, e.g. `Vespera`, `Laudes`, or
                // `martyrologium`) pins the hour, which otherwise follows the time of day.
                initialHour: ProcessInfo.processInfo.environment["BREVIARIUM_SNAPSHOT_HOUR"].flatMap { name in
                    name == "martyrologium" ? .martyrologium : CanonicalHour(rawValue: name).map(OfficeHour.hour)
                }
            )
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
