import Foundation
import BreviariumKit

/// Walks one language folder of the pinned Divinum Officium checkout
/// (`web/www/horas/<Language>`), parsing every `.txt` file under a fixed set of
/// top-level subfolders into `RawSection`s (`RawSectionParser`), applying
/// `LatinOrthography` where the language calls for it.
public enum OfficeCorpusWalker {

    public enum WalkError: Error, CustomStringConvertible {
        case rootNotFound(String)
        case fileReadFailed(String, underlying: Error)

        public var description: String {
            switch self {
            case .rootNotFound(let path): return "Directory not found: \(path)"
            case .fileReadFailed(let path, let error): return "Failed to read \(path): \(error)"
            }
        }
    }

    /// Walks `languageRoot` (e.g. `.../web/www/horas/Latin`), parsing every `.txt` file
    /// whose path (relative to `languageRoot`) starts with one of `topLevelFolders`
    /// (e.g. `["Tempora", "Sancti", "Commune", "Psalterium"]` — this project's Roman
    /// secular subset, excluding the Monastic/Cistercian/Dominican `*M`/`*Cist`/`*OP`
    /// sibling folders and non-office content like `Martyrologium`/`Regula`).
    ///
    /// Each `RawOfficeFile.path` is the file's path relative to `languageRoot`, without
    /// its `.txt` extension, e.g. `"Sancti/01-18r"`, `"Psalterium/Common/Prayers"`.
    public static func walk(languageRoot: URL, topLevelFolders: Set<String>, applyLatinOrthography: Bool) throws -> [RawOfficeFile] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: languageRoot.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw WalkError.rootNotFound(languageRoot.path)
        }

        guard let enumerator = fileManager.enumerator(at: languageRoot, includingPropertiesForKeys: [.isRegularFileKey])
        else {
            return []
        }

        let rootPath = languageRoot.standardizedFileURL.path
        var results: [RawOfficeFile] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "txt" else { continue }

            let fullPath = fileURL.standardizedFileURL.path
            guard fullPath.hasPrefix(rootPath) else { continue }
            var relative = String(fullPath.dropFirst(rootPath.count))
            if relative.hasPrefix("/") { relative.removeFirst() }

            guard let topFolder = relative.split(separator: "/").first, topLevelFolders.contains(String(topFolder))
            else { continue }

            let text: String
            do {
                text = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                throw WalkError.fileReadFailed(fullPath, underlying: error)
            }

            let normalized = applyLatinOrthography ? LatinOrthography.normalize(text) : text
            let pathWithoutExtension = relative.hasSuffix(".txt") ? String(relative.dropLast(4)) : relative
            results.append(RawSectionParser.parse(fileText: normalized, path: pathWithoutExtension))
        }

        return results.sorted { $0.path < $1.path }    // Deterministic bundle output.
    }
}
