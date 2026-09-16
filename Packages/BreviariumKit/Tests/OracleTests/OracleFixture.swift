import Foundation

/// Loads the compressed fixtures `scripts/generate-oracle-fixtures.sh` produced
/// (`data/oracle-fixtures/`), extracting each `.tar.gz` once per test run and caching
/// its contents. Shells out to `tar` rather than a Swift compression library — this is
/// test-only infrastructure (never shipped in the app or the Kit), so it isn't
/// constrained by `CLAUDE.md`'s "no third-party dependencies in the app or engine"
/// rule, and both platforms this project targets locally (Linux CI, Windows 10+) ship a
/// `tar` capable of `-xzf` at a fixed, well-known path.
///
/// An `actor`, not an `enum` with `nonisolated(unsafe)` statics: Swift Testing runs
/// `@Test` functions in parallel by default, and multiple `OracleTests` cases call this
/// concurrently — an unsynchronised shared dictionary crashed the whole test binary
/// (SIGSEGV) the first time this ran on CI, a real data race, not a false alarm.
actor OracleFixture {
    static let shared = OracleFixture()

    static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private var mainYearCache: [Int: [String: String]] = [:]
    private var spotCheckCache: [String: String]?

    /// The main sweep's fixture text for one date (priest off, Latin/Bea only — the
    /// only combination that sweep covers), or `nil` if that date isn't in the sweep
    /// range (2025-2040).
    func main(year: Int, date: String) throws -> String? {
        if mainYearCache[year] == nil {
            mainYearCache[year] = try Self.extractAndRead(
                archive: Self.repoRoot.appendingPathComponent("data/oracle-fixtures/main/\(year).tar.gz")
            )
        }
        return mainYearCache[year]?["\(year)/\(date)_priestN_latin.txt"]
    }

    /// The spot-check fixture text for one filename (as `scripts/oracle-date-list.pl`
    /// names it, e.g. `"2026-04-05_priestY_latin_easter.txt"`).
    func spotCheck(filename: String) throws -> String? {
        if spotCheckCache == nil {
            spotCheckCache = try Self.extractAndRead(archive: Self.repoRoot.appendingPathComponent("data/oracle-fixtures/spot-check.tar.gz"))
        }
        return spotCheckCache?["spot-check/\(filename)"]
    }

    private static func extractAndRead(archive: URL) throws -> [String: String] {
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("breviarium-oracle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        let process = Process()
        #if os(Windows)
        process.executableURL = URL(fileURLWithPath: "C:\\Windows\\System32\\tar.exe")
        #else
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        #endif
        process.arguments = ["-xzf", archive.path, "-C", dest.path]
        try process.run()
        process.waitUntilExit()

        var result: [String: String] = [:]
        guard let enumerator = FileManager.default.enumerator(at: dest, includingPropertiesForKeys: nil) else { return result }
        let destPath = dest.standardizedFileURL.path
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "txt" else { continue }
            let fullPath = fileURL.standardizedFileURL.path
            guard fullPath.hasPrefix(destPath) else { continue }
            var relative = String(fullPath.dropFirst(destPath.count))
            if relative.hasPrefix("/") || relative.hasPrefix("\\") { relative.removeFirst() }
            relative = relative.replacingOccurrences(of: "\\", with: "/")
            result[relative] = try String(contentsOf: fileURL, encoding: .utf8)
        }
        return result
    }
}
