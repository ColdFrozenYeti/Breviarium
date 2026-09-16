/// Wraps the flattened 1960 sanctoral calendar table (`DataBundle.calendar`,
/// `KalendariaResolver`) with date-based lookup.
public struct SanctoralCalendar: Sendable {
    public var entries: [String: String]

    public init(entries: [String: String]) {
        self.entries = entries
    }

    /// Candidate `Sancti` file references for a date, in priority order (a Kalendaria
    /// entry can list several `~`-separated candidates — `do-format.md`). The `"XXXXX"`
    /// removal sentinel and any empty entries are filtered out; the result is empty when
    /// there's no sanctoral office at all on this date.
    public func candidates(day: Int, month: Int, year: Int) -> [String] {
        let key = Computus.sanctoralKey(day: day, month: month, year: year)
        guard let raw = entries[key] else { return [] }
        return raw.split(separator: "~")
            .map(String.init)
            .filter { !$0.isEmpty && !KalendariaResolver.isRemovalSentinel($0) }
    }
}
