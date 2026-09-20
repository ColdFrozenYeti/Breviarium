import Foundation
import BreviariumKit

/// Reads the real `Tabulae/Tempora/Generale.txt` file from a pinned DO checkout and
/// parses it with `TemporaRedirectResolver`.
public enum TemporaRedirectReader {
    /// `tempoRoot` is `.../web/www/Tabulae/Tempora`.
    public static func read(temporaRoot: URL) throws -> [String: String] {
        let fileURL = temporaRoot.appendingPathComponent("Generale.txt")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return TemporaRedirectResolver.parseEntries(text)
    }
}
