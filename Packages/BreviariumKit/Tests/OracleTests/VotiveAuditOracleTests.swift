import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 4: the Little Office of Our Lady (DO's votive C12) and the Office of the Dead (C9)
// against DO's pages (`votives/<votive>/<Hour>/`, `votives-bea/…`, `holdout/2044-<votive>-<Hour>`),
// with the same checks as the day hours: content and coverage in Latin and English, the
// pairing, the title, and with the Pius XII psalter every psalm's title and verses.

struct VotiveHour: CustomStringConvertible, Sendable {
    var officium: Officium
    var hour: CanonicalHour
    var votive: String { officium == .parvumBMV ? "C12" : "C9" }
    var description: String { "\(votive) \(hour.doName)" }
}

let votiveHours: [VotiveHour] = Officium.parvumBMV.hours.map { VotiveHour(officium: .parvumBMV, hour: $0) }
    + Officium.defunctorum.hours.map { VotiveHour(officium: .defunctorum, hour: $0) }

private func votiveSelected(_ case: VotiveHour) -> Bool {
    // `BREVIARIUM_AUDIT_VOTIVES=C12` or `C9`, and `BREVIARIUM_AUDIT_HOURS`, narrow a run.
    let env = ProcessInfo.processInfo.environment
    if let only = env["BREVIARIUM_AUDIT_VOTIVES"], !only.isEmpty, !only.split(separator: ",").contains(Substring(`case`.votive)) { return false }
    if let only = env["BREVIARIUM_AUDIT_HOURS"], !only.isEmpty, !only.split(separator: ",").contains(Substring(`case`.hour.rawValue)) { return false }
    return true
}

@Test(arguments: votiveHours)
func votiveAudit(_ votiveHour: VotiveHour) async throws {
    guard votiveSelected(votiveHour), let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let english = bundle.makeEnglishCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    var report = DayHourAuditReport()
    for year in 2025...2040 {
        guard let archive = try await OracleFixture.shared.hourYear(set: "votives/\(votiveHour.votive)", hour: votiveHour.hour, year: year) else { continue }
        var (day, month, y) = (1, 1, year)
        while y == year {
            let date = String(format: "%04d-%02d-%02d", y, month, day)
            if let text = archive["\(year)/\(date)_priestN_bilingual.tsv"] {
                let (assembled, title) = assembleDayHour(
                    votiveHour.hour, day: day, month: month, year: y, priest: false, bundle: bundle, corpus: corpus, english: english,
                    calendar: calendar, officium: votiveHour.officium
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
    #expect(report.daysChecked >= 365, "\(votiveHour): checked \(report.daysChecked)")
    #expect(report.text.isEmpty, "\n\(votiveHour):\n\(report.text)")
}

@Test(arguments: votiveHours)
func votiveBeaAudit(_ votiveHour: VotiveHour) async throws {
    guard votiveSelected(votiveHour), let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    var problems: [String: [String]] = [:]
    var daysChecked = 0
    for year in 2025...2040 {
        guard let archive = try await OracleFixture.shared.hourYear(set: "votives-bea/\(votiveHour.votive)", hour: votiveHour.hour, year: year) else { continue }
        var (day, month, y) = (1, 1, year)
        while y == year {
            let date = String(format: "%04d-%02d-%02d", y, month, day)
            if let text = archive["\(year)/\(date)_priestN_latin.txt"] {
                let (assembled, _) = assembleDayHour(
                    votiveHour.hour, day: day, month: month, year: y, priest: false, bundle: bundle, corpus: corpus, english: nil,
                    calendar: calendar, officium: votiveHour.officium
                )
                if let assembled {
                    daysChecked += 1
                    for (kind, piece) in latinContentMisses(hour: assembled, rows: [BilingualRow(latin: text, english: "")]) {
                        problems["[\(kind)] \(piece.prefix(auditPrefix))", default: []].append(date)
                    }
                    let expected = dayHourFixturePsalms(text)
                    let actual = dayHourRenderedPsalms(assembled)
                    if expected.count != actual.count {
                        problems["DO \(expected.map { $0.title }) | engine \(actual.map { $0.title })", default: []].append(date)
                    } else if let (e, a) = zip(expected, actual).first(where: { $0 != $1 }) {
                        problems["DO \(e) | engine \(a)".prefix(400).description, default: []].append(date)
                    }
                } else {
                    problems["not assembled", default: []].append(date)
                }
            }
            (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
        }
    }
    let text = problems.sorted { $0.value.count > $1.value.count }.prefix(25)
        .map { "  \($0.value.count)x, e.g. \($0.value[0]): \($0.key)" }.joined(separator: "\n")
    #expect(daysChecked >= 365, "\(votiveHour): checked \(daysChecked)")
    #expect(problems.isEmpty, "\n\(votiveHour) (Pius XII):\n\(text)")
}

@Test(arguments: votiveHours)
func votiveHoldout2044(_ votiveHour: VotiveHour) async throws {
    guard votiveSelected(votiveHour), let bundle = RealCorpus.bundle else { return }
    let archivePath = OracleFixture.repoRoot.appendingPathComponent(
        "data/oracle-fixtures/holdout/2044-\(votiveHour.votive)-\(votiveHour.hour.doName).tar.gz"
    )
    guard FileManager.default.fileExists(atPath: archivePath.path) else { return }
    let archive = try OracleFixture.extractAndRead(archive: archivePath)
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let english = bundle.makeEnglishCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    var report = DayHourAuditReport()
    for priest in [false, true] {
        var (day, month, year) = (1, 1, 2044)
        while year == 2044 {
            let date = String(format: "%04d-%02d-%02d", year, month, day)
            if let text = archive["2044/\(date)_priest\(priest ? "Y" : "N")_bilingual.tsv"] {
                let (assembled, title) = assembleDayHour(
                    votiveHour.hour, day: day, month: month, year: year, priest: priest, bundle: bundle, corpus: corpus, english: english,
                    calendar: calendar, officium: votiveHour.officium
                )
                if let assembled {
                    report.add(hour: assembled, rows: withoutMartyrology(OracleFixture.rows(text)), title: title, date: date + (priest ? " priest" : ""))
                } else {
                    report.failedToAssemble.append(date)
                }
            }
            (day, month, year) = Computus.addDays(1, day: day, month: month, year: year)
        }
    }
    #expect(report.daysChecked == 732, "\(votiveHour): expected 366 dates twice, checked \(report.daysChecked)")
    #expect(report.text.isEmpty, "\n\(votiveHour) 2044:\n\(report.text)")
}
