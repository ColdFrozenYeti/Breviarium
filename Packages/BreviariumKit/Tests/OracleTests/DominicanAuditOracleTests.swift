import Foundation
import Testing
@testable import BreviariumKit

/// B5-M4: the Dominican office (`Ordo Praedicatorum - 1962`) against DO's own Dominican
/// renders (`op/hours/<Hour>/<year>.tar.gz`, `docs/rubrics-op1962.md`), every hour, the
/// same checks as `dayHoursFullRangeAudit`. `BREVIARIUM_AUDIT_YEAR(S)` and
/// `BREVIARIUM_AUDIT_HOURS` narrow a run.
/// DO's own error texts on pages the app corrects (decided 1 October 2026).
private let knownDivergences = [
    "Sancti/9-12:Evangelium is missing!",    // 7 October, Prime: the Rosary Mass's Gospel reference
    "Commune/C1:Ant Vespera",                  // the Apostles' second Vespers antiphon (St Matthias)
    "Responsory Vespera 1 is missing!",        // Ascension, first Vespers: a reference with no section
    "Oratio missing", "Ant missing", "Ant 2 missing", "Ant 3 missing",    // 24 April: the Crown of Thorns office is incomplete
    " is missing!",                            // any other DO error text: a reference to a section that doesn't exist
]

/// DO errors on one hour's pages, recognised by all of their texts (`docs/rubrics-op1962.md` §8).
private let hourDivergences: [(hour: CanonicalHour, all: [String])] = [
    // Two Saturdays (14 February, 10 October 2026): Prime's chapter at first Vespers of Sunday.
    (.vesperae, ["Dóminus dírigat corda et córpora"]),
    // First Vespers of Passion Sunday: the Holy Cross's *In hac triúmphi glória*.
    (.vesperae, ["Dominica de Passione", "In hac triúmphi glória"]),
    // 2 January: the Roman Christmas hymn, through `Tempora/Nat02`'s `vide Sancti/01-01`;
    // every other Dominican Vespers of Christmastide says *Veni, redémptor géntium*.
    (.vesperae, ["Die Secunda Januarii", "Christe Redémptor ómnium"]),
    // 12 November (All Saints of the Order, `ex Sancti/11-01`): one antiphon from the
    // Common of Martyrs' Lauds over the Martyrs' Vespers psalms, not All Saints' office.
    (.vesperae, ["Festivitas Omnium Sanctorum OP", "Justórum autem ánimæ"]),
]

@Test(arguments: [CanonicalHour.vesperae, .completorium, .tertia, .sexta, .nona, .prima, .laudes, .matutinum])
func dominicanFullRangeAudit(hour: CanonicalHour) async throws {
    if let only = ProcessInfo.processInfo.environment["BREVIARIUM_AUDIT_HOURS"], !only.isEmpty, !only.split(separator: ",").contains(Substring(hour.rawValue)) {
        return
    }
    guard let bundle = RealCorpus.bundle, try await OracleFixture.shared.hourYear(set: "op/hours", hour: hour, year: 2040) != nil else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let english = bundle.makeEnglishCorpus()
    let calendar = bundle.makeSanctoralCalendar(rite: .dominicanus)

    var report = DayHourAuditReport()
    var corrected: [String] = []
    for year in auditYears {
        guard let archive = try await OracleFixture.shared.hourYear(set: "op/hours", hour: hour, year: year) else { continue }
        var (day, month, y) = (1, 1, year)
        while y == year {
            let date = String(format: "%04d-%02d-%02d", y, month, day)
            // Known DO divergences, where DO prints an error and the app the corrected text
            // (`docs/rubrics-op1962.md` §8).
            let page = archive["\(year)/\(date)_priestN_bilingual.tsv"]
            let hourDivergence = page.map { text in
                hourDivergences.contains { $0.hour == hour && $0.all.allSatisfy(text.contains) }
            } ?? false
            if let text = page, !knownDivergences.contains(where: text.contains), !hourDivergence {
                let (assembled, title) = assembleDayHour(
                    hour, day: day, month: month, year: y, priest: false, bundle: bundle, corpus: corpus, english: english,
                    calendar: calendar, rite: .dominicanus
                )
                if let assembled {
                    let rows = withoutMartyrology(OracleFixture.rows(text))
                    var single = DayHourAuditReport()
                    single.add(hour: assembled, rows: rows, title: title, date: date)
                    // A page that differs only by a correction of DO's data (`SectionResolver.
                    // correctsDOErrors`) must match DO exactly with the corrections off.
                    if !single.text.isEmpty {
                        let (uncorrected, uncorrectedTitle) = SectionResolver.$correctsDOErrors.withValue(false) {
                            assembleDayHour(
                                hour, day: day, month: month, year: y, priest: false, bundle: bundle, corpus: corpus, english: english,
                                calendar: calendar, rite: .dominicanus
                            )
                        }
                        if let uncorrected {
                            var check = DayHourAuditReport()
                            check.add(hour: uncorrected, rows: rows, title: uncorrectedTitle, date: date)
                            if check.text.isEmpty { corrected.append(date) }
                        }
                    }
                    if corrected.last == date {
                        report.daysChecked += 1
                    } else {
                        report.add(hour: assembled, rows: rows, title: title, date: date)
                    }
                } else {
                    report.failedToAssemble.append(date)
                }
            }
            (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
        }
    }
    if !corrected.isEmpty { print("Dominican \(hour): \(corrected.count) page(s) differ from DO only by a corrected DO error: \(corrected.prefix(20).joined(separator: ", "))") }
    #expect(report.daysChecked > auditYears.count * 362, "\(hour): checked \(report.daysChecked)")
    #expect(report.text.isEmpty, "\nDominican \(hour):\n\(report.text)")
}
