import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 6 (B6-M1, `docs/Beta_6_plan.md` §5): no direction is shown in white. Every hour of
// one year under both rites, with the English, is searched for direction wording outside
// a rubric (a `.rubric` unit or an inline-rubric span). `BREVIARIUM_DIRECTION_SCAN=1`
// runs it (it assembles about six thousand hours).

nonisolated(unsafe) private let directionWords = #/(?i)\b(fit reverentia|bow head|genuflect\w*|flexis genibus|profound bow|secreto|sub silentio|dicitur|dicuntur|omittitur|during the following)\b/#
// Not "kneeling", "is said" or "are said": the psalms, hymns and collects use them
// (*Glorious things are said of thee*, *as we kneel before thee*).

/// The unit's texts with any inline-rubric spans removed.
private func plainTexts(_ unit: BreviariumKit.Unit) -> [String] {
    let texts: [String]
    switch unit {
    case .rubric: return []
    case .prose(let t, let e), .antiphon(let t, let e): texts = [t, e ?? ""]
    case .versicleResponse(let v, let r, let ve, let re): texts = [v, r, ve ?? "", re ?? ""]
    case .verse(_, let a, let b, let ae, let be): texts = [a, b, ae ?? "", be ?? ""]
    // The Matins lessons are narrative (*And he kneeled down*); DO marks no direction
    // inside one.
    case .lesson: return []
    case .englishPsalm(let verses): texts = verses.flatMap { [$0.firstHalf, $0.secondHalf] }
    case .psalmTitle, .englishNote: return []
    }
    return texts.map { $0.replacing(#/\u{E000}[^\u{E001}]*\u{E001}/#, with: "") }.filter { !$0.isEmpty }
}

@Test func noDirectionShownInWhite() async throws {
    guard ProcessInfo.processInfo.environment["BREVIARIUM_DIRECTION_SCAN"] != nil, let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let english = bundle.makeEnglishCorpus()
    var found: [String: [String]] = [:]
    for rite in [Rite.romanus, .dominicanus] {
        let calendar = bundle.makeSanctoralCalendar(rite: rite)
        var (day, month, year) = (1, 1, 2026)
        while year == 2026 {
            for hour in CanonicalHour.allCases {
                let (assembled, _) = assembleDayHour(
                    hour, day: day, month: month, year: year, priest: false, bundle: bundle, corpus: corpus, english: english,
                    calendar: calendar, rite: rite
                )
                for unit in assembled?.sections.flatMap(\.units) ?? [] {
                    for text in plainTexts(unit) {
                        guard let match = text.firstMatch(of: directionWords) else { continue }
                        found["\(rite) \(hour.rawValue) [\(match.output.0)]: \(text.prefix(140))", default: []].append(String(format: "%04d-%02d-%02d", year, month, day))
                    }
                }
            }
            (day, month, year) = Computus.addDays(1, day: day, month: month, year: year)
        }
    }
    let report = found.sorted { $0.value.count > $1.value.count }.map { "\($0.value.count)x, e.g. \($0.value[0]): \($0.key)" }
    print(report.joined(separator: "\n"))
    #expect(found.isEmpty, "\n\(report.prefix(40).joined(separator: "\n"))")
}
