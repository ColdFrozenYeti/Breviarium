import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 4's named edge cases for the Little Office and the Office of the Dead
// (`docs/Beta_4_plan.md`, B4-M3). The audits check every date against DO; these say in
// words what the seasons and options change.

private func votive(
    _ hour: CanonicalHour, _ day: Int, _ month: Int, _ year: Int, _ officium: Officium, priest: Bool = false
) -> (hour: Hour?, title: String?) {
    guard let bundle = RealCorpus.bundle else { return (nil, nil) }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar()
    let (assembled, title) = assembleDayHour(
        hour, day: day, month: month, year: year, priest: priest, bundle: bundle, corpus: corpus, english: nil,
        calendar: calendar, officium: officium
    )
    return (assembled, title)
}

private func text(_ hour: Hour?, _ kind: Section.Kind? = nil) -> String {
    (hour?.sections ?? []).filter { kind == nil || $0.kind == kind }.flatMap(\.units).flatMap(oracleComparisonTexts).joined(separator: " ")
}

private func hasTeDeum(_ hour: Hour?) -> Bool { hour?.sections.contains { $0.kind == .teDeum } == true }

@Test func littleOfficeInAdvent() {
    guard RealCorpus.bundle != nil else { return }
    let matins = votive(.matutinum, 2, 12, 2026, .parvumBMV)
    #expect(matins.title?.contains("Adventus") == true)
    #expect(!hasTeDeum(matins.hour))
}

@Test func littleOfficeAtChristmas() {
    guard RealCorpus.bundle != nil else { return }
    let matins = votive(.matutinum, 27, 12, 2026, .parvumBMV)
    #expect(matins.title?.contains("Nativitatis") == true)
    #expect(hasTeDeum(matins.hour))
    // Christmas Eve: the Christmas form from Vespers on.
    #expect(votive(.laudes, 24, 12, 2026, .parvumBMV).title?.contains("Adventus") == true)
    #expect(votive(.vesperae, 24, 12, 2026, .parvumBMV).title?.contains("Nativitatis") == true)
}

@Test func littleOfficeAfterThePurification() {
    guard RealCorpus.bundle != nil else { return }
    // 2038: Septuagesima is 21 February, so 3 February has the ordinary form.
    let matins = votive(.matutinum, 3, 2, 2038, .parvumBMV)
    #expect(matins.title == "Officium parvum Beatæ Mariæ Virginis")
    #expect(hasTeDeum(matins.hour))
}

@Test func littleOfficeInLent() {
    guard RealCorpus.bundle != nil else { return }
    let matins = votive(.matutinum, 10, 3, 2027, .parvumBMV)
    #expect(matins.title?.contains("Septuagesimae") == true)
    #expect(!hasTeDeum(matins.hour))
    // On Our Lady's own feasts the Te Deum stays (DO: "no Te Deum" becomes "Feria Te
    // Deum" when the day's Commune is C11): the Purification after Septuagesima, 2026.
    #expect(hasTeDeum(votive(.matutinum, 2, 2, 2026, .parvumBMV).hour))
    // The Annunciation has its own form (2026; in 2027 it falls on Maundy Thursday and
    // is transferred).
    #expect(votive(.laudes, 25, 3, 2026, .parvumBMV).title?.contains("Annuntiationis") == true)
}

@Test func littleOfficeAtEaster() {
    guard RealCorpus.bundle != nil else { return }
    let lauds = votive(.laudes, 12, 4, 2026, .parvumBMV)
    #expect(lauds.title == "Officium parvum Beatæ Mariæ Virginis")
    // The Incipit keeps the season's Alleluia.
    #expect(text(lauds.hour, .introductio).contains("Allelúia"))
}

@Test func officeOfTheDeadWithThePriestOnAndOff() {
    guard RealCorpus.bundle != nil else { return }
    let withPriest = text(votive(.laudes, 16, 9, 2026, .defunctorum, priest: true).hour, .oratio)
    let without = text(votive(.laudes, 16, 9, 2026, .defunctorum, priest: false).hour, .oratio)
    #expect(withPriest.contains("Dóminus vobíscum"))
    #expect(!without.contains("Dóminus vobíscum"))
    #expect(without.contains("Dómine, exáudi oratiónem meam"))
}

@Test func officeOfTheDeadOnAllSouls() {
    guard RealCorpus.bundle != nil else { return }
    // As DO renders it: the Office of the Dead chosen as the office reads its own
    // lessons (Job 10 in the first nocturn), the day's office All Souls' own (Job 14).
    let votiveMatins = text(votive(.matutinum, 2, 11, 2026, .defunctorum).hour)
    let dayMatins = text(votive(.matutinum, 2, 11, 2026, .diei).hour)
    #expect(votiveMatins.contains("Tædet ánimam meam vitæ meæ"))
    #expect(!dayMatins.contains("Tædet ánimam meam vitæ meæ"))
    #expect(dayMatins.contains("Homo natus de mulíere"))
}

@Test func officeOfTheDeadHasThreeHours() {
    #expect(Officium.defunctorum.hours == [.matutinum, .laudes, .vesperae])
    #expect(Officium.defunctorum.availableHour(for: .tertia) == .laudes)
    #expect(Officium.defunctorum.availableHour(for: .completorium) == .vesperae)
    #expect(Officium.parvumBMV.availableHour(for: .completorium) == .completorium)
    guard RealCorpus.bundle != nil else { return }
    #expect(votive(.tertia, 16, 9, 2026, .defunctorum).hour == nil)
}
