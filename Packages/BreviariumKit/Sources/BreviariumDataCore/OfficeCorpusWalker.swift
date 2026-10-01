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

    /// The files of the other rites' folders (`SanctiM/`, `CommuneOP/`, …) that the walked
    /// files reference, and those they reference in turn: a few Roman offices borrow from
    /// them (the Baptism of the Lord's Matins antiphons, `@SanctiM/01-06:AntMatutinumM:2`).
    public static func referencedSiblings(
        languageRoot: URL, of files: [RawOfficeFile], applyLatinOrthography: Bool
    ) throws -> [RawOfficeFile] {
        let sibling = /@((?:Sancti|Tempora|Commune)(?:M|OP|Cist)\/[^:\n]+?)(?=:|\n|$)/
        var have = Set(files.map(\.path))
        var pending = files
        var added: [RawOfficeFile] = []
        while let file = pending.popLast() {
            var texts = file.sections.flatMap(\.body)
            if let base = file.baseFile { texts.append("@" + base.file) }
            for text in texts {
                for match in text.matches(of: sibling) {
                    let path = String(match.1).trimmingCharacters(in: .whitespaces)
                    guard !have.contains(path) else { continue }
                    have.insert(path)
                    let url = languageRoot.appendingPathComponent(path + ".txt")
                    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
                    let normalized = applyLatinOrthography ? LatinOrthography.normalize(raw) : raw
                    let parsed = RawSectionParser.parse(fileText: normalized, path: path)
                    added.append(parsed)
                    pending.append(parsed)
                }
            }
        }
        return added.sorted { $0.path < $1.path }
    }

    /// Beta 5: the Mass Gospels the Dominican Prime reads on feasts (`monastic.pl:534-590`,
    /// `lectioE`), from DO's `missa/<Language>/{Tempora,Sancti,Commune}` (its `Commune` has
    /// only `Coronatio` and `Propaganda`; the numbered Commons are read from the office's
    /// tree). Only the `[Evangelium…]` sections are kept, under a `missa/` path prefix
    /// (`missa/Sancti/02-06`). A reference inside them points into the Mass's tree when
    /// that file exists there; `SectionResolver.missaLocation` decides the rest when the
    /// Gospel is read.
    public static func walkMissaGospels(languageRoot: URL, applyLatinOrthography: Bool) throws -> [RawOfficeFile] {
        let walked = try walk(languageRoot: languageRoot, topLevelFolders: ["Tempora", "Sancti", "Commune"], applyLatinOrthography: applyLatinOrthography)
        let missaPaths = Set(walked.map(\.path))
        func retarget(_ path: String) -> String {
            missaPaths.contains(path) && !path.hasPrefix("Commune") ? "missa/" + path : path
        }
        let reference = /^@([^:\n]+)/
        return walked.map { file in
            let sections = file.sections.filter { $0.name.hasPrefix("Evangelium") }.map { section in
                var section = section
                section.body = section.body.map { line in
                    guard let match = line.firstMatch(of: reference) else { return line }
                    return "@" + retarget(String(match.1)) + line[match.range.upperBound...]
                }
                return section
            }
            // Every file is kept, with no sections if it has no Gospel: whether it exists
            // decides which tree DO reads (`SectionResolver.missaContext`).
            let base = file.baseFile.map { BaseFileReference(file: retarget($0.file), condition: $0.condition) }
            return RawOfficeFile(path: "missa/" + file.path, sections: sections, baseFile: base)
        }
    }
}
