import Foundation
import BreviariumKit

/// Reads the real `Tabulae/Transfer/*.txt` annual-transfer files from a pinned DO
/// checkout and parses each with `TransferResolver`.
public enum TransferTableReader {

    /// `transferRoot` is `.../web/www/Tabulae/Transfer`. Only its direct `.txt` children
    /// are read — the Calendarium Generale files this project targets — not the diocese
    /// subfolders alongside them (`Augustanae`, `Monacensis`, etc., each a
    /// `$dioecesis`-specific override tree `Directorium.pm` only consults when a
    /// diocese is selected, which this project's alpha never does).
    public static func readAll(transferRoot: URL) throws -> [String: [String: String]] {
        let fileManager = FileManager.default
        let entries = try fileManager.contentsOfDirectory(at: transferRoot, includingPropertiesForKeys: nil)

        var tables: [String: [String: String]] = [:]
        for fileURL in entries where fileURL.pathExtension.lowercased() == "txt" {
            let key = fileURL.deletingPathExtension().lastPathComponent
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            tables[key] = TransferResolver.parseEntries(text)
        }
        return tables
    }
}
