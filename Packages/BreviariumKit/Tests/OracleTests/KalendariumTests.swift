import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// 1.4: the *Kalendarium* (`docs/1.4_plan.md`, M2). It adds no calendar logic, so each row
// must be exactly what the engine gives Lauds for that day; these tests check that, and
// the named days `CLAUDE.md` lists.

private func month(_ year: Int, _ month: Int, rite: Rite = .romanus) -> [KalendariumEntry] {
    guard let bundle = RealCorpus.bundle else { return [] }
    return Kalendarium.month(
        year: year, month: month, rite: rite, corpus: bundle.makeLatinCorpus(psalter: .vulgate),
        sanctoralCalendar: bundle.makeSanctoralCalendar(rite: rite)
    )
}

private func entry(_ day: Int, _ m: Int, _ year: Int, rite: Rite = .romanus) -> KalendariumEntry? {
    month(year, m, rite: rite).first { $0.day == day }
}

/// The day's own office, straight from the engine (as the calendar's colour dots have it).
private func engineDay(_ day: Int, _ m: Int, _ year: Int, rite: Rite = .romanus) -> LiturgicalDay? {
    guard let bundle = RealCorpus.bundle else { return nil }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar(rite: rite)
    let context = ConditionalContextBuilder.build(
        day: day, month: m, year: year, ad: "Laudes", rubrica: rite.doVersion, corpus: corpus, sanctoralCalendar: calendar
    )
    return LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: calendar).day(day: day, month: m, year: year)
}

@Test func kalendariumHasEveryDayOfTheMonth() {
    guard RealCorpus.bundle != nil else { return }
    #expect(month(2026, 9).map(\.day) == Array(1...30))
    #expect(month(2028, 2).count == 29)   // leap-year February
    #expect(month(2027, 2).count == 28)
    // 16 September 2026 is a Wednesday.
    #expect(entry(16, 9, 2026)?.weekday == 3)
}

/// `CLAUDE.md`'s example day, whose title block the visual spec gives.
@Test func kalendariumSixteenthSeptember2026() {
    guard RealCorpus.bundle != nil, let row = entry(16, 9, 2026) else { return }
    #expect(row.classis == "III")
    #expect(row.titleBlock.classisLine == "III. classis")
    #expect(row.titleBlock.nameLine == "Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum")
    #expect(row.color == .red)
}

/// Every row of a few months is the engine's own title and colour for the day, and the
/// name Lauds shows starts with it (Lauds adds the monthday suffix, *I. Novembris*).
@Test(arguments: [(2026, 12, Rite.romanus), (2027, 4, .romanus), (2038, 4, .romanus), (2026, 11, .romanus), (2026, 8, .dominicanus)])
func kalendariumMatchesTheEngine(_ year: Int, _ m: Int, _ rite: Rite) {
    guard RealCorpus.bundle != nil else { return }
    for row in month(year, m, rite: rite) {
        let office = engineDay(row.day, m, year, rite: rite)
        #expect(row.titleBlock == office?.titleBlock, "\(rite) \(year)-\(m)-\(row.day)")
        #expect(row.color == office.map { CalendarColor(color: $0.color, officePath: $0.occurrence.winningPath) })
    }
}

@Test func kalendariumNamedDays() {
    guard RealCorpus.bundle != nil else { return }
    // 8 December on an Advent Sunday (2030): the Immaculate Conception, I class, white.
    let conception = entry(8, 12, 2030)
    #expect(conception?.titleBlock.nameLine.contains("Conceptione") == true, "\(String(describing: conception))")
    #expect(conception?.classis == "I")
    #expect(conception?.color == .white)
    // The Annunciation transferred in 2027 to the Monday after Low Sunday, 5 April.
    #expect(entry(25, 3, 2027)?.titleBlock.nameLine.contains("Annuntiatione") == false)
    #expect(entry(5, 4, 2027)?.titleBlock.nameLine.contains("Annuntiatione") == true)
    // The latest Easter, 25 April 2038.
    #expect(entry(25, 4, 2038)?.classis == "I")
    #expect(entry(25, 4, 2038)?.color == .white)
    // Gaudete Sunday is rose, as in the calendar dots.
    #expect(entry(13, 12, 2026)?.color == .rose)
}

/// Names in the abbreviations of an Ordo.
@Test func kalendariumShortNames() {
    #expect(Kalendarium.shortName("Feria Quinta infra Hebdomadam XXIII post Octavam Pentecostes")
        == "Feria V hebd. XXIII post Oct. Pent.")
    #expect(Kalendarium.shortName("S. Alfonsi Mariæ de Ligorio Episcopi Confessoris et Ecclesiæ Doctoris")
        == "S. Alfonsi Mariæ de Ligorio Ep. Conf. et Eccl. Doct.")
    #expect(Kalendarium.shortName("Ss. Septem Fratrum Martyrum, ac Rufinæ et Secundæ Virginum et Martyrum")
        == "Ss. Septem Fratrum Mm., ac Rufinæ et Secundæ Virg. et Mm.")
    #expect(Kalendarium.shortName("In Commemoratione Omnium Fidelium Defunctorum")
        == "In Comm. Omnium Fidelium Defunctorum")
    #expect(Kalendarium.shortName("S. Martini Papæ et Martyris") == "S. Martini Papæ et Mart.")
    #expect(Kalendarium.shortName("Feria II infra Hebdomadam I Adventus") == "Feria II hebd. I Adventus")
    #expect(Kalendarium.shortName("Dominica III Post Pentecosten infra Octavam SSmi Cordis D.N.I.C")
        == "Dominica III post Pent. infra Oct. SSmi Cordis D.N.I.C")
}

@Test func kalendariumAmbrosian() throws {
    let root = OracleFixture.repoRoot.appendingPathComponent("data/ambrosian")
    let data = try AmbrosianSource.data(
        compline: String(contentsOf: root.appendingPathComponent("completorium-1957.txt"), encoding: .utf8),
        corrections: String(contentsOf: root.appendingPathComponent("corrections.txt"), encoding: .utf8),
        calendar: String(contentsOf: root.appendingPathComponent("kalendarium.txt"), encoding: .utf8)
    )
    let calendar = AmbrosianCalendar(entries: data.calendar)
    let december = Kalendarium.month(year: 2026, month: 12, ambrosian: calendar)
    #expect(december.count == 31)
    let ambrose = december.first { $0.day == 7 }
    #expect(ambrose?.titleBlock == calendar.titleBlock(day: 7, month: 12, year: 2026))
    #expect(ambrose?.classis == "Sol. I cl.")
    #expect(ambrose?.color == calendar.color(day: 7, month: 12, year: 2026))
}
