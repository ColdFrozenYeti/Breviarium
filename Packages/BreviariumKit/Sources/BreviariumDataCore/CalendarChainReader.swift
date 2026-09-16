import Foundation
import BreviariumKit

/// Reads the real `Kalendaria/*.txt` files from a pinned DO checkout and flattens them
/// via `KalendariaResolver`.
public enum CalendarChainReader {

    /// The `Rubrics 1960 - 1960` version's `Kalendaria` inheritance chain, from the
    /// ultimate base to the most specific version — `web/www/Tabulae/data.txt`'s `base`
    /// column, walked by hand once here rather than re-parsed at build time, since this
    /// project only ever targets the one rubrics version (`do-format.md`).
    public static let chainOldestFirst = ["1570", "1888", "1906", "1939", "1954", "1955", "1960"]

    /// `tabulaeRoot` is `.../web/www/Tabulae`.
    public static func flattenedCalendar(tabulaeRoot: URL) throws -> [String: String] {
        let texts = try chainOldestFirst.map { version -> String in
            let fileURL = tabulaeRoot.appendingPathComponent("Kalendaria/\(version).txt")
            return try String(contentsOf: fileURL, encoding: .utf8)
        }
        return KalendariaResolver.flatten(textsOldestFirst: texts)
    }
}
