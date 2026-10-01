import Testing
@testable import BreviariumKit

/// B5-M3: the rite plug-in, on the real corpus (`docs/rubrics-op1962.md` §1-2).
@Suite struct RiteTests {
    @Test func versionsAndFolders() {
        #expect(Rite.romanus.doVersion == "Rubrics 1960 - 1960")
        #expect(Rite.dominicanus.doVersion == "Ordo Praedicatorum - 1962")
        #expect(Rite.romanus.folderSuffix.isEmpty)
        #expect(Rite.dominicanus.folderSuffix == "OP")
    }

    /// DO's `checklatinfile`: the rite's own file when it exists, else the Roman one.
    @Test func dominicanPathsFallBackToRoman() throws {
        let bundle = try #require(RealCorpus.bundle)
        let latin = bundle.makeLatinCorpus(psalter: .vulgate)
        #expect(Rite.dominicanus.path("Sancti", "01-15OP", latin: latin) == "SanctiOP/01-15OP")
        #expect(Rite.dominicanus.path("Sancti", "01-15", latin: latin) == "Sancti/01-15")
        #expect(Rite.romanus.path("Sancti", "01-15OP", latin: latin) == "Sancti/01-15OP")
        #expect(latin.fileExists(path: "Regula/OrdoPraedicatorum"))
        #expect(!latin.fileExists(path: "Regula/01-01"))
    }

    /// The Dominican calendar is the 1960 one with `OP1962.txt` on top; the Roman one
    /// is untouched by it.
    @Test func dominicanCalendarOverlay() throws {
        let bundle = try #require(RealCorpus.bundle)
        let op = try #require(bundle.calendarOP)
        #expect(op["01-15"]?.hasPrefix("01-15OP") == true)       // Bl. Francis de Capillas
        #expect(op["02-13"]?.hasPrefix("02-13OP") == true)       // St Catherine de' Ricci
        #expect(bundle.calendar["01-15"]?.contains("OP") != true)
        #expect(op.count >= bundle.calendar.count - 50)
    }
}
