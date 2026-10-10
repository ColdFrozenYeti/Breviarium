import Foundation
import Testing
@testable import BreviariumKit

// 1.2-M3: the galleries' fixed preview (`docs/1.2_plan.md` §4), read from the real
// Divinum Officium files at the pinned commit.

private func realFile(_ path: String) throws -> RawOfficeFile {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("data/divinum-officium/web/www/horas/Latin")
    let text = try String(contentsOf: root.appendingPathComponent(path + ".txt"), encoding: .utf8)
    return RawSectionParser.parse(fileText: text, path: path)
}

@Test func gallerySampleIsEasterSundaysMagnificatAntiphonAndTheFirstTwoVerses() throws {
    let corpus = InMemoryOfficeCorpus(files: [
        try realFile(GallerySample.antiphonPath), try realFile(GallerySample.canticlePath),
    ])
    let units = GallerySample.units(corpus: corpus)
    #expect(units.count == 3)
    #expect(units.first == .antiphon("Et respiciéntes * vidérunt revolútum lápidem: erat quippe magnus valde, allelúja."))
    guard units.count == 3, case .verse(_, let first, let second, _, _) = units[1], case .verse(_, let next, _, _, _) = units[2] else {
        Issue.record("expected two verses, got \(units)")
        return
    }
    #expect(first == "Magníficat +*")
    #expect(second == "ánima mea Dóminum.")
    #expect(next.hasPrefix("Et exsultávit spíritus meus:"))
}

@Test func gallerySampleLeavesOutWhatTheDataLacks() {
    let canticle = RawOfficeFile(path: GallerySample.canticlePath, sections: [
        RawSection(name: RawSectionParser.wholeFileSectionName, condition: "", body: ["1:46 Magníficat + * ánima mea Dóminum."]),
    ])
    let units = GallerySample.units(corpus: InMemoryOfficeCorpus(files: [canticle]))
    #expect(units.count == 1)
    #expect(GallerySample.units(corpus: InMemoryOfficeCorpus(files: [])).isEmpty)
}
