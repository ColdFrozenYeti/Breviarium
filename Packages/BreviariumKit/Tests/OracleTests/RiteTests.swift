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

    /// End to end: with the Dominican version, 13 February 2026 is St Catherine de'
    /// Ricci from `SanctiOP`, as DO's own fixture titles it; the Roman office that day
    /// is untouched.
    @Test func dominicanDayComesFromSanctiOP() async throws {
        let bundle = try #require(RealCorpus.bundle)
        let latin = bundle.makeLatinCorpus(psalter: .vulgate)
        for (rite, expectOP) in [(Rite.dominicanus, true), (Rite.romanus, false)] {
            let calendar = bundle.makeSanctoralCalendar(rite: rite)
            let context = ConditionalContextBuilder.build(
                day: 13, month: 2, year: 2026, ad: "laudes", rubrica: rite.doVersion, corpus: latin, sanctoralCalendar: calendar
            )
            let result = try #require(Occurrence(corpus: latin, context: context, calendar: calendar).resolve(day: 13, month: 2, year: 2026))
            #expect(result.winningPath.hasPrefix("SanctiOP/") == expectOP, "\(rite): \(result.winningPath)")
            if expectOP { #expect(result.winningRank.title.contains("Ricci")) }
        }
    }

    /// The Dominican Little Office has no Lenten form (`horascommon.pl:1783`).
    @Test func dominicanLittleOfficeHasNoLentenForm() throws {
        let bundle = try #require(RealCorpus.bundle)
        let latin = bundle.makeLatinCorpus(psalter: .vulgate)
        let lent = { (rite: Rite) in
            Officium.parvumBMV.votivePath(
                hour: .laudes, day: 4, month: 3, year: 2026, weekName: "Quad2", dayWinnerPath: "Tempora/Quad2-3",
                rite: rite, latin: latin
            )
        }
        #expect(lent(.romanus) == "Commune/C12Q")
        #expect(lent(.dominicanus) == "CommuneOP/C12")
    }
}
