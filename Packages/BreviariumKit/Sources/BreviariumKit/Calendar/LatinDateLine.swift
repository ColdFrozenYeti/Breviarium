/// Formats the date line `CLAUDE.md`'s visual spec describes (§ "Date line"):
/// `"Dies <day> <month genitive> <year>"`, e.g. `"Dies 16 septembris 2026"`.
public enum LatinDateLine {
    private static let monthsGenitive = [
        "ianuarii", "februarii", "martii", "aprilis", "maii", "iunii",
        "iulii", "augusti", "septembris", "octobris", "novembris", "decembris",
    ]

    /// `month` is 1-12 -- an out-of-range value is a caller bug (every call site in this
    /// project derives `month` from `Computus`/`Calendar`, which never produce one),
    /// so this traps via the array index rather than silently falling back.
    public static func format(day: Int, month: Int, year: Int) -> String {
        "Dies \(day) \(monthsGenitive[month - 1]) \(year)"
    }
}
