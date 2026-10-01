import Foundation
import Testing
@testable import BreviariumKit

/// B5-M4: the Dominican office (`Ordo Praedicatorum - 1962`) against DO's own Dominican
/// renders (`op/hours/<Hour>/<year>.tar.gz`, `docs/rubrics-op1962.md`), every hour, the
/// same checks as `dayHoursFullRangeAudit`. `BREVIARIUM_AUDIT_YEAR(S)` and
/// `BREVIARIUM_AUDIT_HOURS` narrow a run.
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
            // Known DO divergence: DO's own Prime on 7 October shows "Sancti/9-12:Evangelium
            // is missing!" (a typo in its Rosary Mass); the app reads the Gospel the
            // reference means (`docs/rubrics-op1962.md` §8).
            if let text = archive["\(year)/\(date)_priestN_bilingual.tsv"], !text.contains("Sancti/9-12:Evangelium is missing!") {
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
