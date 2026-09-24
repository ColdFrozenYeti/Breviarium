import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Saturday Vespers with the ferial psalms divides Psalm 144 in the middle of verse 13:
// `Psalmi major.txt` [Day6 Vespera] lists `144(8-'13a')` and `144('13b'-21)`. DO filters
// the file's lines by that range while they still carry their sub-verse letter
// (`horasscripts.pl:598-614`) and drops the letter only for display (`:400-403`), so the
// fourth psalm ends with 144:13a ("Regnum tuum…") and the fifth starts with 144:13b
// ("Fidélis Dóminus…"). The range reaches `psalm()` as the arguments `8` and `'13a'`
// (`psalmi.pl:692-697`), so the title reads "Psalmus 144(8-13a)", without quotes
// (`horasscripts.pl:561-562`). Found in B1-M3: the engine had dropped both halves of
// 144:13 and quoted the title, and neither showed in the content audit.

private func saturdayPsalms(_ psalter: Psalter) throws -> [RenderedPsalm]? {
    guard let bundle = RealCorpus.bundle else { return nil }
    let corpus = bundle.makeLatinCorpus(psalter: psalter)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 17, month: 1, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let hour = try #require(HourAssembler(corpus: corpus, context: context, calendar: calendar).assembleVespers(day: 17, month: 1, year: 2026, priest: false))
    return renderedPsalms(hour)
}

@Test(arguments: Psalter.allCases)
func saturdayDividedPsalm144KeepsBothHalvesOfVerse13(psalter: Psalter) async throws {
    guard let engine = try saturdayPsalms(psalter) else { return }
    let fixtureText = try #require(try await OracleFixture.shared.range(psalter: psalter, year: 2026, date: "2026-01-17"))
    let fixture = fixturePsalms(fixtureText)

    #expect(engine[3].references.last == "144:13")
    #expect(engine[4].references.first == "144:13")
    #expect(engine.map(\.references) == fixture.map(\.references))
}

@Test(arguments: Psalter.allCases)
func dividedPsalmTitlesMatchDivinumOfficium(psalter: Psalter) async throws {
    guard let engine = try saturdayPsalms(psalter) else { return }
    let fixtureText = try #require(try await OracleFixture.shared.range(psalter: psalter, year: 2026, date: "2026-01-17"))

    #expect(engine[3].title == "Psalmus 144(8-13a) [4]")
    #expect(engine[4].title == "Psalmus 144(13b-21) [5]")
    // The Pius XII psalter's subtitle comes from the file's "(Magnitudo et bonitas Dei)"
    // line, kept for the part that starts at verse 1 and dropped for the later parts
    // (`horasscripts.pl:584`); the Vulgate files have no such line.
    #expect(engine[2].title == (psalter == .pius12 ? "Psalmus 144(1-7) — Magnitudo et bonitas Dei [3]" : "Psalmus 144(1-7) [3]"))
    #expect(engine.map(\.title) == fixturePsalms(fixtureText).map(\.title))
}
