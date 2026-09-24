import Foundation
import BreviariumKit

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
    private var vulgateYearCache: [Int: [String: String]] = [:]
    private var holdoutYearCache: [Int: [String: String]] = [:]
    private var bilingualHoldoutYearCache: [Int: [String: String]] = [:]
    private var bilingualYearCache: [Int: [String: String]] = [:]
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

    /// The 2025-2040 Latin fixture for one date in either psalter (priest off): `main/`
    /// for the Pius XII psalter, `vulgate/` for the Vulgate (`data/SOURCE.md`).
    func range(psalter: Psalter, year: Int, date: String) throws -> String? {
        switch psalter {
        case .pius12:
            return try main(year: year, date: date)
        case .vulgate:
            if vulgateYearCache[year] == nil {
                vulgateYearCache[year] = try Self.extractAndRead(
                    archive: Self.repoRoot.appendingPathComponent("data/oracle-fixtures/vulgate/\(year).tar.gz")
                )
            }
            return vulgateYearCache[year]?["\(year)/\(date)_priestN_latin.txt"]
        }
    }

    /// A hold-out year's Latin fixture in either psalter. The Vulgate hold-out is stored
    /// bilingual (`holdout/<year>-bilingual.tar.gz`, one table row per line, cells split
    /// by a tab); its Latin column, joined, equals the Latin-only page on every date
    /// checked (`data/SOURCE.md`), so that is what this returns.
    func holdout(psalter: Psalter, year: Int, date: String, priest: Bool) throws -> String? {
        switch psalter {
        case .pius12:
            return try holdout(year: year, date: date, priest: priest)
        case .vulgate:
            if bilingualHoldoutYearCache[year] == nil {
                let archive = Self.repoRoot.appendingPathComponent("data/oracle-fixtures/holdout/\(year)-bilingual.tar.gz")
                guard FileManager.default.fileExists(atPath: archive.path) else { return nil }
                bilingualHoldoutYearCache[year] = try Self.extractAndRead(archive: archive)
            }
            guard let rows = bilingualHoldoutYearCache[year]?["\(year)/\(date)_priest\(priest ? "Y" : "N")_bilingual.tsv"] else {
                return nil
            }
            return Self.latinColumn(ofRows: rows)
        }
    }

    /// The 2025-2040 bilingual fixture for one date (Vulgate Latin + English, priest off):
    /// DO's table rows, each a Latin cell and an English cell (`data/SOURCE.md`, "rows"
    /// format). The first row is the text above DO's table (the day title), Latin only.
    func bilingual(year: Int, date: String) throws -> [BilingualRow]? {
        if bilingualYearCache[year] == nil {
            bilingualYearCache[year] = try Self.extractAndRead(
                archive: Self.repoRoot.appendingPathComponent("data/oracle-fixtures/bilingual/\(year).tar.gz")
            )
        }
        return bilingualYearCache[year]?["\(year)/\(date)_priestN_bilingual.tsv"].map(Self.rows)
    }

    /// The Vulgate hold-out's bilingual rows for one date, priest off or on.
    func bilingualHoldout(year: Int, date: String, priest: Bool) throws -> [BilingualRow]? {
        _ = try holdout(psalter: .vulgate, year: year, date: date, priest: priest)
        return bilingualHoldoutYearCache[year]?["\(year)/\(date)_priest\(priest ? "Y" : "N")_bilingual.tsv"].map(Self.rows)
    }

    static func rows(_ text: String) -> [BilingualRow] {
        text.split(separator: "\n").map { row in
            let cells = row.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            return BilingualRow(latin: String(cells.first ?? ""), english: cells.count > 1 ? String(cells[1]) : "")
        }
    }

    /// The Latin (first) cell of every row of a "rows"-format fixture, joined with single
    /// spaces: the same text a Latin-only "flat" render of that page gives.
    static func latinColumn(ofRows rows: String) -> String {
        rows.split(separator: "\n").compactMap { row -> Substring? in
            let latin = row.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
            return latin.isEmpty ? nil : latin
        }.joined(separator: " ")
    }

    /// A hold-out year's fixture text for one date (`scripts/generate-holdout-fixtures.sh`,
    /// `data/oracle-fixtures/holdout/<year>.tar.gz`): Latin/Bea, with priest off and on
    /// both rendered. `nil` if that year hasn't been generated.
    func holdout(year: Int, date: String, priest: Bool) throws -> String? {
        if holdoutYearCache[year] == nil {
            let archive = Self.repoRoot.appendingPathComponent("data/oracle-fixtures/holdout/\(year).tar.gz")
            guard FileManager.default.fileExists(atPath: archive.path) else { return nil }
            holdoutYearCache[year] = try Self.extractAndRead(archive: archive)
        }
        return holdoutYearCache[year]?["\(year)/\(date)_priest\(priest ? "Y" : "N")_latin.txt"]
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
            guard fileURL.pathExtension == "txt" || fileURL.pathExtension == "tsv" else { continue }
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

/// One row of Divinum Officium's two-column table: what it prints side by side.
struct BilingualRow: Equatable, Sendable {
    var latin: String
    var english: String
}
