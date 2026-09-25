import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 2: every day hour with the Pius XII psalter against Divinum Officium's Latin-Bea
// page (`hours-bea/<Hour>/`, priest off): every Latin piece we render is on DO's page, and
// the psalms' titles and verse lists are DO's, psalm by psalm (as
// `vespersFullRangePsalmodyAudit` does for Vespers). The Vulgate side, with the English,
// is `dayHoursFullRangeAudit`.

private nonisolated(unsafe) let anyPsalmodyTitle = try! Regex(#"(?:Psalmus|Canticum|Symbolum)\b[^\[]{0,100}?\[\d\]"#)
private nonisolated(unsafe) let verseReference = try! Regex(#"(?:^| )(\d{1,3}:\d{1,3}) "#)

/// DO's psalms on a day hour's page: each "Psalmus … [n]" title and the verse references
/// up to the antiphon after it or the next psalm or canticle title (Lauds' canticles, the
/// Athanasian Creed at Prime), whichever comes first.
func dayHourFixturePsalms(_ fixtureText: String) -> [RenderedPsalm] {
    let text = LatinOrthography.normalize(fixtureText).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    let titles = text.matches(of: anyPsalmodyTitle)
    var psalms: [RenderedPsalm] = []
    for (index, match) in titles.enumerated() where text[match.range].hasPrefix("Psalmus") {
        let rest = text[match.range.upperBound...]
        let nextTitle = index + 1 < titles.count ? titles[index + 1].range.lowerBound : rest.endIndex
        // Compline's Nunc dimittis is titled without a number ("Canticum Simeonis Luc. …").
        let canticle = rest.range(of: " Canticum ")?.lowerBound ?? rest.endIndex
        let end = min(rest.range(of: " Ant. ")?.lowerBound ?? rest.endIndex, nextTitle, canticle)
        let references = (" " + rest[..<end]).matches(of: verseReference).map { String($0.output[1].substring ?? "") }
        psalms.append(RenderedPsalm(title: String(text[match.range]), references: references))
    }
    return psalms
}

/// The engine's psalms in every section (the Triduum's and All Souls' own forms of an
/// hour put them in one section), canticles left out as in `dayHourFixturePsalms`.
func dayHourRenderedPsalms(_ hour: Hour) -> [RenderedPsalm] {
    var psalms: [RenderedPsalm] = []
    var inPsalm = false
    for section in hour.sections {
        // A psalm never runs on into the next section (the Nunc dimittis, the chapter).
        inPsalm = false
        for unit in section.units {
        switch unit {
        case .psalmTitle(let title, _):
            inPsalm = title.hasPrefix("Psalmus")
            if inPsalm { psalms.append(RenderedPsalm(title: title.split(whereSeparator: { $0.isWhitespace }).joined(separator: " "), references: [])) }
        case .verse(let reference, _, _, _, _) where inPsalm && !reference.isEmpty:
            psalms[psalms.count - 1].references.append(reference)
        default:
            continue
        }
        }
    }
    return psalms
}

@Test(arguments: [CanonicalHour.completorium, .tertia, .sexta, .nona, .prima, .laudes])
func dayHoursFullRangeBeaAudit(hour: CanonicalHour) async throws {
    if let only = ProcessInfo.processInfo.environment["BREVIARIUM_AUDIT_HOURS"], !only.split(separator: ",").contains(Substring(hour.rawValue)) {
        return
    }
    guard let bundle = RealCorpus.bundle, try await OracleFixture.shared.hourYear(set: "hours-bea", hour: hour, year: 2040) != nil else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()

    var content: [String: [String]] = [:]
    var psalmody: [String: [String]] = [:]
    var failed: [String] = []
    var daysChecked = 0
    for year in 2025...2040 {
        guard let archive = try await OracleFixture.shared.hourYear(set: "hours-bea", hour: hour, year: year) else { continue }
        var (day, month, y) = (1, 1, year)
        while y == year {
            let date = String(format: "%04d-%02d-%02d", y, month, day)
            if let text = archive["\(year)/\(date)_priestN_latin.txt"] {
                let (assembled, _) = assembleDayHour(
                    hour, day: day, month: month, year: y, priest: false, bundle: bundle, corpus: corpus, english: nil, calendar: calendar
                )
                if let assembled {
                    daysChecked += 1
                    for (kind, piece) in latinContentMisses(hour: assembled, rows: [BilingualRow(latin: text, english: "")]) {
                        content["[\(kind)] \(piece.prefix(140))", default: []].append(date)
                    }
                    let expected = dayHourFixturePsalms(text)
                    let actual = dayHourRenderedPsalms(assembled)
                    if expected.count != actual.count {
                        psalmody["DO \(expected.map { $0.title }) | engine \(actual.map { $0.title })", default: []].append(date)
                    } else if let (e, a) = zip(expected, actual).first(where: { $0 != $1 }) {
                        psalmody["DO \(e) | engine \(a)".prefix(400).description, default: []].append(date)
                    }
                } else {
                    failed.append(date)
                }
            }
            (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
        }
    }

    func report(_ name: String, _ problems: [String: [String]]) -> String {
        guard !problems.isEmpty else { return "" }
        let lines = problems.sorted { $0.value.count > $1.value.count }.prefix(25).map { "  \($0.value.count)x, e.g. \($0.value.first!): \($0.key)" }
        return "-- \(name): \(problems.count) distinct --\n" + lines.joined(separator: "\n")
    }
    let text = [
        failed.isEmpty ? "" : "-- not assembled: \(failed.count), e.g. \(failed.prefix(5))",
        report("Latin we render that DO doesn't show", content),
        report("Psalmody", psalmody),
    ].filter { !$0.isEmpty }.joined(separator: "\n\n")
    #expect(daysChecked > 5_800, "expected the full 2025-2040 range, checked \(daysChecked)")
    #expect(text.isEmpty, "\n\(hour) (Pius XII):\n\(text)")
}
