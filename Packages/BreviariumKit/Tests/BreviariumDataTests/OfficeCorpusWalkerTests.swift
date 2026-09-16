import Foundation
import Testing
@testable import BreviariumDataCore

private func makeTempCorpus(_ files: [String: String]) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for (relativePath, content) in files {
        let fileURL = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    return root
}

@Test func walksOnlyAllowedTopLevelFolders() throws {
    let root = try makeTempCorpus([
        "Sancti/01-18r.txt": "[Officium]\nJesum.",
        "Tempora/Adv1-0.txt": "[Officium]\nAdventus.",
        "SanctiM/01-18.txt": "[Officium]\nMonastic, should be excluded.",
        "Martyrologium/01-18.txt": "[Officium]\nExcluded.",
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let files = try OfficeCorpusWalker.walk(
        languageRoot: root,
        topLevelFolders: ["Sancti", "Tempora"],
        applyLatinOrthography: false
    )

    let paths = Set(files.map(\.path))
    #expect(paths == ["Sancti/01-18r", "Tempora/Adv1-0"])
}

@Test func appliesLatinOrthographyWhenRequested() throws {
    let root = try makeTempCorpus(["Sancti/01-18r.txt": "[Officium]\nJesum ejus."])
    defer { try? FileManager.default.removeItem(at: root) }

    let files = try OfficeCorpusWalker.walk(languageRoot: root, topLevelFolders: ["Sancti"], applyLatinOrthography: true)
    #expect(files.first?.sections.first?.body.first == "Iesum eius.")
}

@Test func skipsOrthographyWhenNotRequested() throws {
    let root = try makeTempCorpus(["Sancti/01-18r.txt": "[Officium]\nJesum ejus."])
    defer { try? FileManager.default.removeItem(at: root) }

    let files = try OfficeCorpusWalker.walk(languageRoot: root, topLevelFolders: ["Sancti"], applyLatinOrthography: false)
    #expect(files.first?.sections.first?.body.first == "Jesum ejus.")
}

@Test func handlesNestedSubdirectories() throws {
    let root = try makeTempCorpus(["Psalterium/Common/Prayers.txt": "[Per Dominum]\nr. Per Dominum."])
    defer { try? FileManager.default.removeItem(at: root) }

    let files = try OfficeCorpusWalker.walk(languageRoot: root, topLevelFolders: ["Psalterium"], applyLatinOrthography: false)
    #expect(files.first?.path == "Psalterium/Common/Prayers")
}

@Test func throwsForMissingRoot() {
    let missing = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString)")
    #expect(throws: OfficeCorpusWalker.WalkError.self) {
        try OfficeCorpusWalker.walk(languageRoot: missing, topLevelFolders: ["Sancti"], applyLatinOrthography: false)
    }
}
