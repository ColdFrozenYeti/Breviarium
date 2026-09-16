/// Flattens Divinum Officium's cascading `Kalendaria/*.txt` calendar files
/// (`do-format.md`) into a single date -> file-reference table.
///
/// Each version's file only lists its *changes* from its `base` version
/// (`web/www/Tabulae/data.txt`'s `base` column) — `1960.txt` diffs against
/// `Reduced - 1955`, which diffs against `Divino Afflatu - 1954`, and so on back to
/// `1570.txt`, the actual full base calendar. `Directorium.pm`'s
/// `get_from_directorium('kalendar', ...)` walks this chain at read time, checking the
/// most specific version first and falling through to the base only when a date is
/// entirely absent from it (`do-format.md`'s Calendar data files section). This is the
/// same result, computed once at build time instead of on every lookup.
public enum KalendariaResolver {

    /// Parses one Kalendaria file's raw text into `MM-DD -> fileref` entries.
    /// Only lines containing `=` are data lines (`*Month*` headers, `#comment` lines,
    /// and blank lines are skipped) — mirrors `Directorium.pm:78-92`'s
    /// `grep(/=/, @lines)` filter. Only the first two `=`-separated fields matter
    /// (`Directorium.pm:80`: `my ($day, $file) = split(/=/)`); any further
    /// title/rank annotations some files carry aren't load-bearing there and aren't
    /// kept here either — see `do-format.md`.
    public static func parseEntries(_ text: String) -> [String: String] {
        var entries: [String: String] = [:]
        // CRLF-checked-out files (Windows) would otherwise collapse into a single
        // "line": Swift's Character (grapheme cluster) view treats "\r\n" as one
        // Character, so `split(separator: "\n")` never finds a boundary inside it —
        // this only ever surfaces locally on Windows, never on Linux CI.
        for line in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n") {
            guard line.contains("=") else { continue }
            let fields = line.split(separator: "=", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count >= 2, isDateKey(fields[0]) else { continue }
            entries[String(fields[0])] = String(fields[1])
        }
        return entries
    }

    /// Real Kalendaria files have at least one stray comment line that happens to
    /// contain `=` (`Kalendaria/1960.txt`: `#identical to 1955=`) and would otherwise
    /// get misread as a data line. Perl's `split` silently drops trailing empty fields,
    /// which happens to leave that particular line with only one field and so no `$file`
    /// value — a harmless accident of Perl's default `split` behaviour, not something
    /// meaningful to replicate. Requiring the key to actually look like `MM-DD` is a more
    /// direct fix for the same non-issue.
    private static func isDateKey(_ field: Substring) -> Bool {
        (try? dateKeyRegex.wholeMatch(in: field)) != nil
    }

    private nonisolated(unsafe) static let dateKeyRegex = /\d{2}-\d{2}/

    /// Flattens a chain of Kalendaria file texts into one merged table.
    ///
    /// `textsOldestFirst` must be ordered from the ultimate base (e.g. `1570.txt`) to
    /// the most specific version (e.g. `1960.txt`) — each subsequent file's entries
    /// overwrite the accumulated table for the same date, including with the `"XXXXX"`
    /// removal sentinel (a later version can explicitly remove a date its base assigned
    /// an office to, not just add new ones).
    public static func flatten(textsOldestFirst: [String]) -> [String: String] {
        var merged: [String: String] = [:]
        for text in textsOldestFirst {
            for (day, file) in parseEntries(text) {
                merged[day] = file
            }
        }
        return merged
    }

    /// `true` for the `"XXXXX"` sentinel meaning "no sanctoral office on this date in
    /// this version" (`do-format.md`) — DO itself doesn't special-case this string; it
    /// just happens to never match a real file on disk, so `checklatinfile` fails
    /// naturally. Provided here so callers don't have to know that indirection.
    public static func isRemovalSentinel(_ fileref: String) -> Bool {
        fileref == "XXXXX"
    }
}
