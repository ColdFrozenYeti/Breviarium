/// Parses Divinum Officium's `Tabulae/Transfer/*.txt` annual-transfer tables — a
/// separate mechanism from `KalendariaResolver`'s flat calendar: each file covers dates
/// near one specific Easter (the 35 files named by Easter's own month+day, `"322"`
/// through `"425"`) or one "dominical letter" bucket used for dates further from Easter
/// (`"a"` through `"g"`, `Directorium.pm`'s own `load_transfers`) — both keyed the same
/// way once loaded, and `SanctoralCalendar` merges them per `Directorium.pm`'s own
/// letter-then-numeric-file push order (a numeric-file entry overrides a letter-file one
/// for the same target date, since Perl's hash-overwrite keeps whichever was pushed
/// last).
///
/// Ported for the two confirmed, `CLAUDE.md`-named 1960 cases (the Annunciation and
/// St Joseph, when Holy Week/the Easter Octave or a Lenten Sunday impedes them) plus
/// every other genuinely 1960-tagged entry the real files carry (Christ the King's
/// October redirect, the Corpus Christi/Sacred Heart octave collisions, etc.) — the
/// mechanism itself doesn't know or care *why* a date is listed, so implementing it
/// generally (rather than hand-coding just the two named dates) is what "any date must
/// work" (`CLAUDE.md`) actually requires here.
///
/// **Deliberately not covered by this pass** (flagged, not silently dropped):
/// - The base-version inheritance fallback (`Reduced - 1955`'s own `"DA"`-tagged
///   transfer entries, consulted by `get_from_directorium` only when 1960's own table is
///   silent for a date) — every date this project's named edge cases and a full audit
///   of the 1960-tagged lines actually need already carries an explicit `"1960"` tag or
///   no version restriction at all, so this fallback chain was never exercised; adding
///   it without a concrete case to verify against would be guessing.
/// - The leap-year dominical-letter shift for January/23 February
///   (`Directorium.pm`'s `$isleap` filter split) — the one 1960-tagged entry in that
///   window (`"01-02"`, a Christmas-season Tempora redirect, not a Vespers-relevant
///   Sancti collision) isn't exercised by this project's alpha scope either.
/// - Transfer entries whose source is a `Tempora/` reference or the `"X-X"` placeholder
///   — `SanctoralCalendar.candidates(...)`'s own contract is Sancti-side candidates
///   only; a Tempora-side transfer would need `Occurrence`-level changes this pass
///   doesn't attempt (confirmed, by a full audit of every 1960-tagged line in the real
///   files, that no Vespers-relevant date actually needs one), and `"X-X"` ("no office")
///   already falls through to an equally-empty ordinary Kalendaria lookup.
public enum TransferResolver {
    /// Parses one Transfer-table file's `MM-DD=source[~source2];;versions` lines,
    /// filtered to lines that apply universally (no `;;` version list at all) or
    /// explicitly list `"1960"` among their space-separated version tags.
    /// `dirge*`/`Hy*`/`C*`-keyed lines are Matins-initial-letter/hymn-shift/coronation
    /// markers this project doesn't use — requiring the key to match `MM-DD` exactly
    /// (mirroring `KalendariaResolver.isDateKey`) skips them the same way
    /// `Directorium.pm`'s `transfered()` does (`next if $key =~ /(dirge|Hy)/i`), plus the
    /// `C##-##` Coronatio-only lines it doesn't separately guard against but this project
    /// has no use for either.
    public static func parseEntries(_ text: String) -> [String: String] {
        var entries: [String: String] = [:]
        for line in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n") {
            guard !line.hasPrefix("#"), line.contains("=") else { continue }

            let withoutVersion: Substring
            let versionList: Substring?
            if let range = line.range(of: ";;") {
                withoutVersion = line[line.startIndex..<range.lowerBound]
                versionList = line[range.upperBound...]
            } else {
                withoutVersion = line[...]
                versionList = nil
            }
            if let versionList, !appliesTo1960(versionList) { continue }

            let fields = withoutVersion.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, isDateKey(fields[0]) else { continue }
            entries[String(fields[0])] = String(fields[1])
        }
        return entries
    }

    /// `Directorium.pm:172`: `$ver =~ /\b$_data{$version}{lc($type)}\b/` — for
    /// `"Rubrics 1960 - 1960"` (`Tabulae/data.txt`) that's the literal word `"1960"`,
    /// matched with a word boundary so it doesn't accidentally match inside `"M1963"`.
    private static func appliesTo1960(_ versionList: Substring) -> Bool {
        (try? nineteenSixtyWordRegex.firstMatch(in: String(versionList))) != nil
    }

    private nonisolated(unsafe) static let nineteenSixtyWordRegex = try! Regex(#"\b1960\b"#)

    private static func isDateKey(_ field: Substring) -> Bool {
        (try? dateKeyRegex.wholeMatch(in: field)) != nil
    }

    private nonisolated(unsafe) static let dateKeyRegex = /\d{2}-\d{2}/
}
