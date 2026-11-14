import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// 1.5, the widgets (`docs/1.5_plan.md`), against the real bundle: the pack reads exactly
// what the bundle holds; a widget's day agrees with the page the app shows for the same
// hour; its antiphon is on Divinum Officium's page for that hour; and CLAUDE.md's named
// cases. Every test skips when the Divinum Officium checkout isn't there.

/// The real bundle's pack, built once.
private enum RealPack {
    static let pack: PackedBundle? = RealCorpus.bundle.flatMap { try? PackedBundle(data: PackedBundle.pack($0)) }
    static let office: WidgetOffice? = pack.map(WidgetOffice.init(pack:))
}

/// The hour's title block and colour as the app's page has them: `OfficeDataStore.content(for:…)`
/// over the whole bundle decoded in memory.
private func pageDay(_ bundle: DataBundle, _ hour: CanonicalHour, _ d: Int, _ m: Int, _ y: Int, rite: Rite, officium: Officium) -> LiturgicalDay? {
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar(rite: rite)
    let shown = officium.availableHour(for: hour)
    let context = ConditionalContextBuilder.build(day: d, month: m, year: y, ad: shown.doName, rubrica: rite.doVersion, corpus: corpus, sanctoralCalendar: calendar)
    return LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: calendar).day(for: shown, day: d, month: m, year: y, officium: officium)
}

private func dateLabel(_ d: Int, _ m: Int, _ y: Int) -> String {
    String(format: "%04d-%02d-%02d", y, m, d)
}

@Test func widgetPackReadsEveryFileAsTheBundleHasIt() throws {
    guard let bundle = RealCorpus.bundle, let pack = RealPack.pack else { return }
    let packed = pack.makeLatinCorpus(psalter: .vulgate)
    #expect(pack.latinPaths.count == bundle.latin.count)
    for file in bundle.latin {
        let path = String(file.path.dropLast(file.path.hasSuffix(".txt") ? 4 : 0))
        #expect(packed.fileExists(path: path), "\(path)")
        #expect(packed.baseFile(path: path) == file.baseFile, "\(path)")
        for name in Set(file.sections.map(\.name)) {
            #expect(packed.rawSections(path: path, name: name) == file.sections.filter { $0.name == name }, "\(path) [\(name)]")
        }
    }
    // The Pius XII psalter, layered over the plain Latin as the app layers it.
    let bea = pack.makeLatinCorpus(psalter: .pius12)
    let beaInMemory = bundle.makeLatinCorpus(psalter: .pius12)
    for file in bundle.latinBea {
        let path = String(file.path.dropLast(file.path.hasSuffix(".txt") ? 4 : 0))
        for name in Set(file.sections.map(\.name)) {
            #expect(bea.rawSections(path: path, name: name) == beaInMemory.rawSections(path: path, name: name), "Bea \(path) [\(name)]")
        }
    }
    #expect(pack.tables.calendar == bundle.calendar)
    #expect(pack.tables.calendarOP == bundle.calendarOP)
    #expect(pack.tables.transferTable == bundle.transferTable)
    #expect(pack.tables.temporaRedirect == bundle.temporaRedirect)
    #expect(pack.tables.ambrosian == bundle.ambrosian)
}

/// Every seventh day of 2026 (52 days, every weekday and season), every hour, under
/// both rites read from Divinum Officium: the widget's title block and colour are the
/// page's. Under *Romanus* its antiphon is also on DO's page for that hour.
@Test func widgetDaysAgreeWithThePagesAndWithDivinumOfficium() async throws {
    guard let bundle = RealCorpus.bundle, let office = RealPack.office else { return }
    var (d, m, y) = (1, 1, 2026)
    var hoursFixtures: [CanonicalHour: [String: String]] = [:]
    var checkedAntiphons = 0
    while y == 2026 {
        for rite in [Rite.romanus, .dominicanus] {
            for hour in CanonicalHour.allCases {
                guard let widget = office.day(hour, day: d, month: m, year: y, rite: rite) else {
                    Issue.record("no widget day: \(rite) \(hour) \(dateLabel(d, m, y))")
                    continue
                }
                let page = try #require(pageDay(bundle, hour, d, m, y, rite: rite, officium: .diei))
                #expect(widget.titleBlock == page.titleBlock, "\(rite) \(hour) \(dateLabel(d, m, y))")
                #expect(widget.color == CalendarColor(color: page.color, officePath: page.occurrence.winningPath), "\(rite) \(hour) \(dateLabel(d, m, y))")
                #expect(widget.hour == hour)
                #expect(widget.dateLine == LatinDateLine.format(day: d, month: m, year: y))

                guard rite == .romanus, let antiphon = widget.antiphon else { continue }
                let fixture: String?
                if hour == .vesperae {
                    fixture = try await OracleFixture.shared.range(psalter: .vulgate, year: y, date: dateLabel(d, m, y))
                } else {
                    if hoursFixtures[hour] == nil { hoursFixtures[hour] = try await OracleFixture.shared.hourYear(hour: hour, year: y) ?? [:] }
                    fixture = hoursFixtures[hour]?["\(y)/\(dateLabel(d, m, y))_priestN_bilingual.tsv"].map(OracleFixture.latinColumn(ofRows:))
                }
                guard let fixture else { continue }
                checkedAntiphons += 1
                #expect(
                    collapsedWhitespace(LatinOrthography.normalize(fixture)).contains(collapsedWhitespace(antiphon)),
                    "\(hour) \(dateLabel(d, m, y)): \(antiphon)"
                )
            }
        }
        (d, m, y) = Computus.addDays(7, day: d, month: m, year: y)
    }
    // 52 days x 8 hours, less the hours without an antiphon: not skipped for want of fixtures.
    #expect(checkedAntiphons > 400, "only \(checkedAntiphons) antiphons checked against DO")
}

@Test func widgetSixteenthSeptember2026HasTheSpecsTitleBlock() throws {
    guard let office = RealPack.office else { return }
    let lauds = try #require(office.day(.laudes, day: 16, month: 9, year: 2026))
    #expect(lauds.titleBlock.classisLine == "III. classis")
    #expect(lauds.classis == "III")
    #expect(lauds.titleBlock.nameLine == "Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum")
    #expect(lauds.dateLine == "Dies 16 septembris 2026")
    #expect(lauds.color == .red)
}

@Test func widgetChristmasEveVespersAreFirstVespersOfChristmas() throws {
    guard let office = RealPack.office else { return }
    let vespers = try #require(office.day(.vesperae, day: 24, month: 12, year: 2026))
    #expect(vespers.titleBlock.nameLine.contains("Nativitate"), "\(vespers.titleBlock.nameLine)")
    #expect(vespers.color == .white)
    #expect(vespers.antiphon != nil)
}

@Test func widgetTriduumLittleHoursHaveNoAntiphon() throws {
    guard let office = RealPack.office else { return }
    for hour in [CanonicalHour.prima, .tertia, .sexta, .nona] {
        let day = try #require(office.day(hour, day: 3, month: 4, year: 2026))
        #expect(day.antiphon == nil, "Good Friday \(hour)")
        // The day's Latin title stands in (decided 2026-11-14).
        #expect(day.hourText == day.titleBlock.nameLine && !day.hourTextIsAntiphon, "Good Friday \(hour)")
        #expect(day.hourText == "Feria Sexta in Passione et Morte Domini", "\(day.hourText)")
    }
    #expect(try #require(office.day(.vesperae, day: 3, month: 4, year: 2026)).antiphon?.hasPrefix("Cum accepísset acétum") == true)
}

@Test func widgetTimelineHasAnEntryForEachHourOfTheDay() throws {
    guard let office = RealPack.office else { return }
    let day = office.timeline(day: 14, month: 11, year: 2026)
    #expect(day.map(\.clockHour) == CanonicalHour.timeOfDayBoundaries)
    #expect(day.map(\.entry.hour) == [.matutinum, .laudes, .tertia, .sexta, .nona, .vesperae, .completorium])

    // The Office of the Dead: Matins, then Lauds until Vespers (its Terce, Sext and None
    // open Lauds), then Vespers through Compline.
    let dead = office.timeline(day: 14, month: 11, year: 2026, officium: .defunctorum)
    #expect(dead.map(\.clockHour) == [0, 5, 17])
    #expect(dead.map(\.entry.hour) == [.matutinum, .laudes, .vesperae])
}

@Test func widgetAmbrosianComplineAllDayWithTheSourcesAntiphon() throws {
    guard let office = RealPack.office else { return }
    let day = office.timeline(day: 14, month: 11, year: 2026, rite: .ambrosianus)
    #expect(day.map(\.clockHour) == [0])
    let compline = try #require(day.first?.entry)
    #expect(compline.hour == .completorium)
    // The whole antiphon, as the source gives it after the *Nunc dimittis*, not the
    // intonation (*Salva nos.*) before it; Latin from the 1957 breviary, no Roman text.
    #expect(compline.antiphon?.hasPrefix("Salva nos, Domine, vigilantes") == true, "\(compline.antiphon ?? "nil")")
    #expect(compline.antiphon?.contains("Dómine") == false)
}

/// The widget's *Psalterium* option (decided 2026-11-14): with the Pius XII psalter,
/// every fortnight of 2026, every Roman hour's antiphon is on DO's Pius XII page.
@Test func widgetPiusXIIAntiphonsAreOnDivinumOfficiumsPiusXIIPages() async throws {
    guard let office = RealPack.office else { return }
    var (d, m, y) = (1, 1, 2026)
    var fixtures: [CanonicalHour: [String: String]] = [:]
    var checked = 0
    while y == 2026 {
        for hour in CanonicalHour.allCases {
            let widget = try #require(office.day(hour, day: d, month: m, year: y, psalter: .pius12), "\(hour) \(dateLabel(d, m, y))")
            guard let antiphon = widget.antiphon else { continue }
            let fixture: String?
            if hour == .vesperae {
                fixture = try await OracleFixture.shared.range(psalter: .pius12, year: y, date: dateLabel(d, m, y))
            } else {
                if fixtures[hour] == nil { fixtures[hour] = try await OracleFixture.shared.hourYear(set: "hours-bea", hour: hour, year: y) ?? [:] }
                fixture = fixtures[hour]?["\(y)/\(dateLabel(d, m, y))_priestN_latin.txt"]
            }
            guard let fixture else { continue }
            checked += 1
            #expect(
                collapsedWhitespace(LatinOrthography.normalize(fixture)).contains(collapsedWhitespace(antiphon)),
                "Pius XII \(hour) \(dateLabel(d, m, y)): \(antiphon)"
            )
        }
        (d, m, y) = Computus.addDays(14, day: d, month: m, year: y)
    }
    #expect(checked > 180, "only \(checked) antiphons checked against DO")
}
