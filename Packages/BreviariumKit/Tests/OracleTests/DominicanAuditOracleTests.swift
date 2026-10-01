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
    for year in auditYears {
        guard let archive = try await OracleFixture.shared.hourYear(set: "op/hours", hour: hour, year: year) else { continue }
        var (day, month, y) = (1, 1, year)
        while y == year {
            let date = String(format: "%04d-%02d-%02d", y, month, day)
            // Known DO divergences, where DO prints an error and the app the corrected text
            // (`docs/rubrics-op1962.md` §8).
            if let text = archive["\(year)/\(date)_priestN_bilingual.tsv"], !knownDivergences.contains(where: text.contains) {
                let (assembled, title) = assembleDayHour(
                    hour, day: day, month: month, year: y, priest: false, bundle: bundle, corpus: corpus, english: english,
                    calendar: calendar, rite: .dominicanus
                )
                if let assembled {
                    report.add(hour: assembled, rows: withoutMartyrology(OracleFixture.rows(text)), title: title, date: date)
                } else {
                    report.failedToAssemble.append(date)
                }
            }
            (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
        }
    }
    #expect(report.daysChecked > auditYears.count * 362, "\(hour): checked \(report.daysChecked)")
    #expect(report.text.isEmpty, "\nDominican \(hour):\n\(report.text)")
}
