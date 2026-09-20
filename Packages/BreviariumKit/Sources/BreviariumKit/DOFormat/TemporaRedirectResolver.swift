/// Parses Divinum Officium's `Tabulae/Tempora/Generale.txt` — a version-gated redirect
/// table that substitutes an entirely different temporal office file for specific weeks,
/// completely separate from `TransferResolver`'s date-keyed annual transfers. Real
/// example: `Tempora/Quad6-6=Tempora/Quad6-6r;;1960 Newcal` — under the 1960 rubrics,
/// Holy Saturday's own winning office is `Tempora/Quad6-6r` (a thin override file that
/// chain-extends `Tempora/Quad6-6` via its own leading `@Tempora/Quad6-6` line for
/// everything it doesn't itself define — Matins stays the same; Vespers' own antiphons
/// and collect are the "r" file's own restored-Holy-Week content).
///
/// Ported by `Directorium.pm`'s own `load_tempora()`: `$tempTransfer =
/// get_from_directorium('transfer', ...) || get_from_directorium('tempora', ...)`, called
/// from `horascommon.pl`'s own `$tday` computation — **every hour of the day**, not just
/// Vespers, so this redirect is applied once, at the point the day's own winning temporal
/// path is first computed (`Occurrence.temporalPath`), before any hour-specific logic
/// runs. Confirmed real for 19 April 2025 (Holy Saturday): the real fixture's own Vespers
/// (`Oratio {ex Proprio de Tempore}`, "Concéde, quǽsumus, omnípotens Deus...") comes from
/// `Quad6-6r`'s own `[Oratio Matutinum]` (cross-referenced by its own `[Oratio 3]`), text
/// this project's engine could never reach while still resolving `Tempora/Quad6-6`
/// directly — that file has no Vespers content of its own at all (`[Oratio Matutinum]`
/// there is genuinely a *different*, Matins-only prayer), so every Vespers section for
/// this day was either missing entirely or silently falling back to the wrong content.
///
/// Every real `1960`/`Newcal`-tagged entry in the file is a `Tempora/`-to-`Tempora/`
/// redirect (the one exception, `C05-18=Votive/Coronatio`, is a Sanctoral votive-office
/// entry this project's Vespers-only Tempora path resolution has no use for and is
/// filtered out by the `Tempora/`-prefix requirement on both sides).
public enum TemporaRedirectResolver {
    /// Parses `OriginalPath=RedirectPath;;versions` lines, filtered to lines that
    /// explicitly list `"1960"` among their space-separated version tags (every real line
    /// in the file carries a tag list — there's no untagged, unconditionally-applied
    /// line) and whose original and redirect paths are both genuine `Tempora/` references.
    public static func parseEntries(_ text: String) -> [String: String] {
        var entries: [String: String] = [:]
        for line in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n") {
            guard !line.hasPrefix("#"), line.contains("="), let versionRange = line.range(of: ";;") else { continue }

            let withoutVersion = line[line.startIndex..<versionRange.lowerBound]
            let versionList = line[versionRange.upperBound...]
            guard appliesTo1960(versionList) else { continue }

            let fields = withoutVersion.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, fields[0].hasPrefix("Tempora/"), fields[1].hasPrefix("Tempora/") else { continue }
            entries[String(fields[0])] = String(fields[1])
        }
        return entries
    }

    /// Same word-boundary match as `TransferResolver.appliesTo1960` (`Directorium.pm`'s
    /// own `$ver =~ $_data{$version}{lc('transfer')}`, which for `"Rubrics 1960 - 1960"`
    /// is the literal word `"1960"`).
    private static func appliesTo1960(_ versionList: Substring) -> Bool {
        (try? nineteenSixtyWordRegex.firstMatch(in: String(versionList))) != nil
    }

    private nonisolated(unsafe) static let nineteenSixtyWordRegex = try! Regex(#"\b1960\b"#)
}
