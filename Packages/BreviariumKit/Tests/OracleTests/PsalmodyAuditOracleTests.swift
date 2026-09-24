import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// The psalmody, compared in the direction `vespersFullRangeContentAudit` can't: that audit
// checks that every text piece we render appears somewhere in Divinum Officium's page, so a
// verse we silently drop, or a title we word differently, passes it. (Beta 1, B1-M3 found
// both: the two halves of 144:13 missing at a divided psalm's split, and a stray-quoted
// "144(8-'13a')" title.) This one reads DO's own psalm titles and verse references from the
// fixture and requires ours to be the same, psalm by psalm.

/// One psalm or canticle as rendered in the Psalmodia: its title line and its verse
/// references, in order (the Gloria Patri, which has no reference, isn't listed).
struct RenderedPsalm: Equatable, CustomStringConvertible {
    var title: String
    var references: [String]
    var description: String { "\(title): \(references.joined(separator: " "))" }
}

private nonisolated(unsafe) let fixturePsalmTitle = try! Regex(#"Psalmus \d+[^\[]*?\[\d\]"#)
private nonisolated(unsafe) let fixtureVerseReference = try! Regex(#"(?:^| )(\d{1,3}:\d{1,3}) "#)

/// DO's psalms as its page shows them: every "Psalmus ... [n]" title, and the verse
/// references between it and the next "Ant." (the antiphon repeated after the psalm and
/// its Gloria) or the next title, whichever comes first. DO shows references without their sub-verse letter (`horasscripts.pl:400-
/// 403`), so these compare directly with the engine's display references.
func fixturePsalms(_ fixtureText: String) -> [RenderedPsalm] {
    let text = collapsedOracleText(LatinOrthography.normalize(fixtureText))
    var psalms: [RenderedPsalm] = []
    let titles = text.matches(of: fixturePsalmTitle)
    for (index, match) in titles.enumerated() {
        let rest = text[match.range.upperBound...]
        // A psalm ends at the antiphon repeated after it, or, where several psalms share
        // one antiphon (Paschaltide's single "Allelúia"), at the next psalm's title.
        let nextTitle = index + 1 < titles.count ? titles[index + 1].range.lowerBound : rest.endIndex
        let end = min(rest.range(of: " Ant. ")?.lowerBound ?? rest.endIndex, nextTitle)
        let block = " " + rest[..<end]
        let references = block.matches(of: fixtureVerseReference).map { String($0.output[1].substring ?? "") }
        psalms.append(RenderedPsalm(title: String(text[match.range]), references: references))
    }
    return psalms
}

/// The engine's psalms, in the same shape as `fixturePsalms`.
func renderedPsalms(_ hour: Hour) -> [RenderedPsalm] {
    guard let psalmodia = hour.sections.first(where: { $0.kind == .psalmodia }) else { return [] }
    var psalms: [RenderedPsalm] = []
    for unit in psalmodia.units {
        switch unit {
        case .psalmTitle(let title):
            psalms.append(RenderedPsalm(title: collapsedOracleText(title), references: []))
        case .verse(let reference, _, _, _, _) where !reference.isEmpty && !psalms.isEmpty:
            psalms[psalms.count - 1].references.append(reference)
        default:
            continue
        }
    }
    return psalms
}

/// Every psalm whose title or verse list differs from DO's, as readable lines; empty means
/// the Psalmodia matches.
func psalmodyMismatches(hour: Hour, fixtureText: String) -> [String] {
    let expected = fixturePsalms(fixtureText)
    let actual = renderedPsalms(hour)
    guard expected.count == actual.count else {
        return ["DO has \(expected.count) psalm(s) \(expected.map(\.title)), engine has \(actual.count) \(actual.map(\.title))"]
    }
    return zip(expected, actual).compactMap { expected, actual in
        expected == actual ? nil : "DO \(expected) | engine \(actual)"
    }
}

private func collapsedOracleText(_ text: String) -> String {
    text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
}

/// Every date 2025-2040, in both psalters: the Psalmodia's titles and verse lists match
/// DO's exactly. The report groups dates by the first differing psalm, so one root cause
/// shows as one line with its date count.
@Test(arguments: Psalter.allCases) func vespersFullRangePsalmodyAudit(psalter: Psalter) async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: psalter)
    let calendar = bundle.makeSanctoralCalendar()

    var byProblem: [String: [String]] = [:]
    var daysChecked = 0
    var (day, month, year) = (1, 1, 2025)
    while true {
        let dateLabel = String(format: "%04d-%02d-%02d", year, month, day)
        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
        )
        if let hour = HourAssembler(corpus: corpus, context: context, calendar: calendar).assembleVespers(day: day, month: month, year: year, priest: false),
            let fixtureText = try await OracleFixture.shared.range(psalter: psalter, year: year, date: dateLabel)
        {
            daysChecked += 1
            if let first = psalmodyMismatches(hour: hour, fixtureText: fixtureText).first {
                byProblem[first, default: []].append(dateLabel)
            }
        }
        if (day, month, year) == (31, 12, 2040) { break }
        (day, month, year) = Computus.addDays(1, day: day, month: month, year: year)
    }

    let dateCount = byProblem.values.reduce(0) { $0 + $1.count }
    let report = byProblem.sorted { $0.value.count > $1.value.count }.prefix(25).map { problem, dates in
        "\(dates.count) date(s), e.g. \(dates.prefix(3).joined(separator: ", ")): \(problem.prefix(400))"
    }.joined(separator: "\n")
    #expect(daysChecked > 5_800, "expected the full 2025-2040 range, checked \(daysChecked)")
    #expect(byProblem.isEmpty, "\n\(psalter): \(dateCount) date(s) differ in \(byProblem.count) way(s):\n\(report)")
}

@Test func fixturePsalmsReadsTitlesAndReferencesFromARealPage() async throws {
    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-01-17"))
    let psalms = fixturePsalms(fixture)
    #expect(psalms.map(\.title) == [
        "Psalmus 143(1-8) [1]", "Psalmus 143(9-15) [2]", "Psalmus 144(1-7) — Magnitudo et bonitas Dei [3]",
        "Psalmus 144(8-13a) [4]", "Psalmus 144(13b-21) [5]",
    ])
    #expect(psalms[3].references.last == "144:13")
    #expect(psalms[4].references.first == "144:13")
}
