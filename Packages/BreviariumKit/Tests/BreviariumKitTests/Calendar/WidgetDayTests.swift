import Foundation
import Testing
@testable import BreviariumKit

// 1.5, the widgets (`docs/1.5_plan.md`): the time-of-day schedule, the widget's data
// pack, and which antiphon a widget shows. The same against the real bundle and Divinum
// Officium's pages is in `OracleTests/WidgetOracleTests.swift`.

@Test func timeOfDayFollowsTheAppsSchedule() {
    // CLAUDE.md: Matins until 05:00, then Lauds, Terce, Sext, None, Vespers and Compline.
    let expected: [(Int, CanonicalHour)] = [
        (0, .matutinum), (4, .matutinum), (5, .laudes), (8, .laudes), (9, .tertia), (11, .tertia), (12, .sexta), (14, .sexta),
        (15, .nona), (16, .nona), (17, .vesperae), (19, .vesperae), (20, .completorium), (23, .completorium),
    ]
    for (clockHour, hour) in expected {
        #expect(CanonicalHour.forTimeOfDay(clockHour: clockHour) == hour, "\(clockHour):00")
    }
}

@Test func timeOfDayBoundariesAreWhereTheHourChanges() {
    let changes = (0 ..< 24).filter { $0 == 0 || CanonicalHour.forTimeOfDay(clockHour: $0) != CanonicalHour.forTimeOfDay(clockHour: $0 - 1) }
    #expect(changes == CanonicalHour.timeOfDayBoundaries)
}

private let sampleFiles = [
    RawOfficeFile(path: "Sancti/09-16.txt", sections: [
        RawSection(name: "Officium", condition: "", body: ["Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum"]),
        RawSection(name: "Oratio", condition: "", body: ["first"]),
        RawSection(name: "Oratio", condition: "rubrica 1960", body: ["second"]),
    ]),
    RawOfficeFile(path: "Commune/C7a.txt", sections: [RawSection(name: "Ant 1", condition: "", body: ["x"])], baseFile: BaseFileReference(file: "Commune/C7")),
]

private func samplePack() throws -> PackedBundle {
    let bundle = DataBundle(
        latin: sampleFiles, latinBea: [RawOfficeFile(path: "Psalmi/Psalm1.txt", sections: [RawSection(name: "Psalm", condition: "", body: ["Bea"])])],
        english: [RawOfficeFile(path: "Sancti/09-16.txt", sections: [])], calendar: ["09-16": "09-16"], temporaRedirect: ["Tempora/A": "Tempora/B"]
    )
    return try PackedBundle(data: PackedBundle.pack(bundle))
}

@Test func packAnswersAsTheInMemoryCorpus() throws {
    let packed = try samplePack().makeLatinCorpus(psalter: .vulgate)
    let inMemory = InMemoryOfficeCorpus(files: sampleFiles)
    for path in ["Sancti/09-16", "Sancti/09-16.txt", "Commune/C7a", "Commune/missing"] {
        for name in ["Officium", "Oratio", "Ant 1", "Nothing"] {
            #expect(packed.rawSections(path: path, name: name) == inMemory.rawSections(path: path, name: name), "\(path) [\(name)]")
        }
        #expect(packed.baseFile(path: path) == inMemory.baseFile(path: path), "\(path)")
        #expect(packed.fileExists(path: path) == inMemory.fileExists(path: path), "\(path)")
    }
    // Both variants of a section, in file order.
    #expect(packed.rawSections(path: "Sancti/09-16", name: "Oratio").map(\.body) == [["first"], ["second"]])
}

@Test func packKeepsTheTablesAndThePiusXIIPsalterButNotTheEnglish() throws {
    let pack = try samplePack()
    #expect(pack.tables.calendar == ["09-16": "09-16"])
    #expect(pack.tables.temporaRedirect == ["Tempora/A": "Tempora/B"])
    #expect(pack.tables.english.isEmpty && pack.tables.latin.isEmpty)
    #expect(pack.makeLatinCorpus(psalter: .pius12).rawSections(path: "Psalmi/Psalm1", name: "Psalm").map(\.body) == [["Bea"]])
    #expect(pack.makeLatinCorpus(psalter: .vulgate).rawSections(path: "Psalmi/Psalm1", name: "Psalm").isEmpty)
    #expect(pack.latinPaths == ["Commune/C7a", "Sancti/09-16"])
}

@Test func aFileThatIsNotAPackIsRefused() {
    #expect(throws: PackedBundle.ReadError.notAPack) { try PackedBundle(data: Data("{\"latin\": []}".utf8)) }
    var truncated = Data("BRVPACK1".utf8)
    truncated.append(contentsOf: [0xFF, 0xFF, 0, 0, 0, 0, 0, 0])
    #expect(throws: PackedBundle.ReadError.truncated) { try PackedBundle(data: truncated) }
}

private let sampleHour = Hour(sections: [
    Section(kind: .invitatorium, units: [.antiphon("Invitatory")]),
    Section(kind: .nocturnusI, units: [.antiphon("Nocturn one"), .verse(reference: "", firstHalf: "a*", secondHalf: "b"), .antiphon("Nocturn two")]),
    Section(kind: .psalmodia, units: [.antiphon("First psalm"), .antiphon("Second psalm")]),
    Section(kind: .canticum, units: [.antiphon("Salva nos."), .verse(reference: "", firstHalf: "Nunc dimittis*", secondHalf: "in pace"), .antiphon("Salva nos, Domine, vigilantes")]),
])

@Test func theCanticleHoursShowTheCanticlesAntiphonAsSaidAfterIt() {
    // The whole antiphon after the canticle, where the one before may be an intonation.
    for hour in [CanonicalHour.laudes, .vesperae, .completorium] {
        #expect(WidgetDay.antiphon(of: sampleHour, hour: hour) == "Salva nos, Domine, vigilantes", "\(hour)")
    }
}

@Test func matinsShowsTheFirstNocturnsFirstAntiphonNotTheInvitatory() {
    #expect(WidgetDay.antiphon(of: sampleHour, hour: .matutinum) == "Nocturn one")
    let singleNocturn = Hour(sections: [Section(kind: .invitatorium, units: [.antiphon("Inv")]), Section(kind: .adNocturnum, units: [.antiphon("Ad nocturnum")])])
    #expect(WidgetDay.antiphon(of: singleNocturn, hour: .matutinum) == "Ad nocturnum")
}

@Test func theOtherHoursShowThePsalmodysFirstAntiphon() {
    for hour in [CanonicalHour.prima, .tertia, .sexta, .nona] {
        #expect(WidgetDay.antiphon(of: sampleHour, hour: hour) == "First psalm", "\(hour)")
    }
}

@Test func anHourWithoutAnAntiphonShowsNone() {
    // The Triduum's little hours: nothing stands in for the antiphon.
    let triduum = Hour(sections: [Section(kind: .psalmodia, units: [.verse(reference: "", firstHalf: "a*", secondHalf: "b")])])
    #expect(WidgetDay.antiphon(of: triduum, hour: .tertia) == nil)
    #expect(WidgetDay.antiphon(of: Hour(sections: []), hour: .vesperae) == nil)
}

@Test func withoutAnAntiphonTheWidgetShowsTheDaysTitle() {
    let title = TitleBlock(classisLine: "I. classis", nameLine: "Feria Sexta in Passione et Morte Domini", commemorationLine: nil)
    let none = WidgetDay(day: 3, month: 4, year: 2026, hour: .tertia, dateLine: "Dies 3 aprilis 2026", titleBlock: title, color: .black, antiphon: nil)
    #expect(none.hourText == "Feria Sexta in Passione et Morte Domini")
    #expect(!none.hourTextIsAntiphon)
    let some = WidgetDay(day: 3, month: 4, year: 2026, hour: .vesperae, dateLine: "Dies 3 aprilis 2026", titleBlock: title, color: .black, antiphon: "Cum accepísset")
    #expect(some.hourText == "Cum accepísset")
    #expect(some.hourTextIsAntiphon)
}
