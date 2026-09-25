import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 2: every day hour against Divinum Officium's bilingual page (`hours/<Hour>/`,
// Vulgate Latin + English, priest off), in both directions and both languages, as the
// Vespers audits do:
// - Latin and English content: every piece we render is on DO's page;
// - Latin and English coverage: nothing but chrome is left of DO's page once ours is
//   removed;
// - pairing: a unit's Latin and English sit in the same DO row;
// - the day title.
// Reported by frequency, so one root cause shows as one line.

/// Our Latin pieces missing from DO's Latin column (J→I-normalised both sides).
func latinContentMisses(hour: Hour, rows: [BilingualRow]) -> [(Section.Kind, String)] {
    let column = collapsedWhitespace(LatinOrthography.normalize(rows.map(\.latin).joined(separator: " ")))
    var misses: [(Section.Kind, String)] = []
    for section in [Section(kind: .introductio, units: hour.prelude)] + hour.sections {
        for unit in section.units {
            for piece in oracleComparisonTexts(unit).map({ collapsedWhitespace(LatinOrthography.normalize($0)) }) where !piece.isEmpty {
                if !column.contains(piece) { misses.append((section.kind, piece)) }
            }
        }
    }
    return misses
}

struct DayHourAuditReport {
    var latinMissing: [String: [String]] = [:]
    var englishMissing: [String: [String]] = [:]
    var uncovered: [String: [String]] = [:]
    var uncoveredLatin: [String: [String]] = [:]
    var mispaired: [String: [String]] = [:]
    var titles: [String: [String]] = [:]
    var failedToAssemble: [String] = []
    var daysChecked = 0

    mutating func add(hour: Hour, rows: [BilingualRow], title: String?, date: String) {
        daysChecked += 1
        for (kind, text) in latinContentMisses(hour: hour, rows: rows) { latinMissing["[\(kind)] \(text.prefix(140))", default: []].append(date) }
        let result = englishAudit(hour: hour, rows: rows)
        for (kind, text) in result.missingFromDO { englishMissing["[\(kind)] \(text.prefix(140))", default: []].append(date) }
        for text in result.uncovered { uncovered[String(text.prefix(140)), default: []].append(date) }
        for text in result.uncoveredLatin { uncoveredLatin[String(text.prefix(140)), default: []].append(date) }
        for text in result.mispaired { mispaired[text, default: []].append(date) }
        if let title, let expected = rows.first.flatMap({ fixtureTitle($0.latin) }), collapsedWhitespace(title) != expected {
            titles["DO \(expected) | engine \(collapsedWhitespace(title))", default: []].append(date)
        }
    }

    var text: String {
        func report(_ name: String, _ problems: [String: [String]]) -> String {
            guard !problems.isEmpty else { return "" }
            let dates = Set(problems.values.flatMap { $0 })
            let lines = problems.sorted { $0.value.count > $1.value.count }.prefix(25).map { text, dates in
                "  \(dates.count)x, e.g. \(dates.first!): \(text)"
            }
            return "-- \(name): \(problems.count) distinct, on \(dates.count) date(s) --\n" + lines.joined(separator: "\n")
        }
        return [
            failedToAssemble.isEmpty ? "" : "-- not assembled: \(failedToAssemble.count), e.g. \(failedToAssemble.prefix(5))",
            report("Latin we render that DO doesn't show", latinMissing),
            report("English we render that DO doesn't show", englishMissing),
            report("DO Latin we don't render", uncoveredLatin),
            report("DO English we don't render", uncovered),
            report("Latin and English in different rows", mispaired),
            report("Day title", titles),
        ].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

/// One hour, one date: assembled as the app assembles it.
func assembleDayHour(
    _ hour: CanonicalHour, day: Int, month: Int, year: Int, priest: Bool, bundle: DataBundle, corpus: OfficeCorpus, english: OfficeCorpus?,
    calendar: SanctoralCalendar
) -> (Hour?, String?) {
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: hour.doName, rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembled = HourAssembler(corpus: corpus, context: context, calendar: calendar, englishCorpus: english)
        .assemble(hour, day: day, month: month, year: year, priest: priest)
    let title = LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: calendar)
        .day(for: hour, day: day, month: month, year: year)?.titleBlock.nameLine
    return (assembled, title)
}

/// Every date 2025-2040 (every `BREVIARIUM_AUDIT_STRIDE`th), one hour. Skipped when the
/// hour's fixtures aren't there yet.
@Test(arguments: [CanonicalHour.completorium, .tertia, .sexta, .nona, .prima, .laudes])
func dayHoursFullRangeAudit(hour: CanonicalHour) async throws {
    // `BREVIARIUM_AUDIT_HOURS=Prima,Laudes` runs only those (several processes in parallel).
    if let only = ProcessInfo.processInfo.environment["BREVIARIUM_AUDIT_HOURS"], !only.split(separator: ",").contains(Substring(hour.rawValue)) {
        return
    }
    guard let bundle = RealCorpus.bundle, try await OracleFixture.shared.hourYear(hour: hour, year: 2040) != nil else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let english = bundle.makeEnglishCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let onlyYear = ProcessInfo.processInfo.environment["BREVIARIUM_AUDIT_YEAR"].flatMap(Int.init)

    var report = DayHourAuditReport()
    for year in 2025...2040 where onlyYear == nil || onlyYear == year {
        guard let archive = try await OracleFixture.shared.hourYear(hour: hour, year: year) else { continue }
        var (day, month, y) = (1, 1, year)
        var offset = 0
        while y == year {
            let date = String(format: "%04d-%02d-%02d", y, month, day)
            if offset % auditStride == 0, let text = archive["\(year)/\(date)_priestN_bilingual.tsv"] {
                let (assembled, title) = assembleDayHour(
                    hour, day: day, month: month, year: y, priest: false, bundle: bundle, corpus: corpus, english: english, calendar: calendar
                )
                if let assembled {
                    // The Martyrology is a separate "hour" in a later beta (decided
                    // 2026-09-24): its row on DO's Prime page isn't ours to show.
                    let rows = OracleFixture.rows(text).filter { !$0.latin.contains("Martyrologium") }
                    report.add(hour: assembled, rows: rows, title: title, date: date)
                } else {
                    report.failedToAssemble.append(date)
                }
            }
            offset += 1
            (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
        }
    }
    let expectedDays = onlyYear == nil ? 5_800 / auditStride : 360 / auditStride
    #expect(report.daysChecked > expectedDays, "\(hour): checked \(report.daysChecked)")
    #expect(report.text.isEmpty, "\n\(hour):\n\(report.text)")
}

/// Debugging aid: `BREVIARIUM_DEBUG_HOUR=Tertia BREVIARIUM_DEBUG_DATE=2025-01-02` prints the
/// assembled hour and DO's Latin column for one date. Does nothing otherwise.
@Test func debugOneDayHour() async throws {
    let env = ProcessInfo.processInfo.environment
    guard let hourName = env["BREVIARIUM_DEBUG_HOUR"], let hour = CanonicalHour(rawValue: hourName),
        let date = env["BREVIARIUM_DEBUG_DATE"], let bundle = RealCorpus.bundle
    else { return }
    let parts = date.split(separator: "-").compactMap { Int($0) }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar()
    let (assembled, title) = assembleDayHour(
        hour, day: parts[2], month: parts[1], year: parts[0], priest: false, bundle: bundle, corpus: corpus, english: bundle.makeEnglishCorpus(),
        calendar: calendar
    )
    var out = "TITLE: \(title ?? "-")\n"
    for section in assembled?.sections ?? [] {
        out += "## \(section.kind)\n"
        for unit in section.units { out += "  \(unit)\n".prefix(260) + "\n" }
    }
    // `BREVIARIUM_DEBUG_TSV` points at a single rendered page when the year isn't archived yet.
    var page = env["BREVIARIUM_DEBUG_TSV"].flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }
    if page == nil { page = try await OracleFixture.shared.hourYear(hour: hour, year: parts[0])?["\(parts[0])/\(date)_priestN_bilingual.tsv"] }
    if let text = page {
        out += "=== DO\n" + OracleFixture.rows(text).map { String($0.latin.prefix(400)) }.joined(separator: "\n")
        if let assembled {
            var report = DayHourAuditReport()
            report.add(hour: assembled, rows: OracleFixture.rows(text).filter { !$0.latin.contains("Martyrologium") }, title: title, date: date)
            out += "\n=== AUDIT\n" + (report.text.isEmpty ? "clean" : report.text)
        }
    }
    print(out)
}
