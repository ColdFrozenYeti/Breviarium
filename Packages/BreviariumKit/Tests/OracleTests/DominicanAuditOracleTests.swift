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
    "Sancti/01-06:Ant Laudes",                 // Epiphany, both Vespers: a reference DO prints instead of *Ante lucíferum génitus*
    "Oratio missing", "Ant missing", "Ant 2 missing", "Ant 3 missing",    // 24 April: the Crown of Thorns office is incomplete
    "Ant. ‡ Canticum",                         // Our Lady on Saturday in January: `CommuneOP/C10b`'s line 2 of a one-line reference (*Génuit puérpera*)
    "Ant. , allelúia.",                        // a Paschal commemoration whose Commune has no antiphon (Ss. Marcellinus and companions, 2 June)
    "mercántur pr'aemium",                     // 4 August: DO's `<sp>'ae</sp>` markup for *prǽmium*
    " is missing!",                            // any other DO error text: a reference to a section that doesn't exist
]

/// DO errors on one hour's pages, recognised by all of their texts (`docs/rubrics-op1962.md` §8).
private let hourDivergences: [(hour: CanonicalHour, all: [String])] = [
    // Two Saturdays (14 February, 10 October 2026): Prime's chapter at first Vespers of Sunday.
    (.vesperae, ["Dóminus dírigat corda et córpora"]),
    // First Vespers of Passion Sunday: the Holy Cross's *In hac triúmphi glória*.
    (.vesperae, ["Dominica de Passione", "In hac triúmphi glória"]),
    // 2 to 5 January: the Roman Christmas hymn, through `TemporaOP/Nat02`…`Nat05`'s `vide
    // Sancti/01-01`; every other Dominican Vespers of Christmastide says *Veni, redémptor
    // géntium*.
    (.vesperae, ["Januarii ~ IV. classis", "Christe Redémptor ómnium"]),
    // 12 November (All Saints of the Order, `ex Sancti/11-01`): one antiphon from the
    // Common of Martyrs' Lauds over the Martyrs' Vespers psalms, not All Saints' office.
    (.vesperae, ["Festivitas Omnium Sanctorum OP", "Justórum autem ánimæ"]),
    // A Sunday commemorated at a Saturday's Vespers takes Saturday's versicle, *Vespertína
    // orátio*, as on most such Saturdays; on a few (St Joachim, the Rosary, St Thomas) DO
    // shows Sunday's *Dirigátur*, by the order in which it first reads `Major Special`.
    // The Triduum's Lauds: the fifth antiphon ends in DO's stray `_`, shown as "portávit. ."
    // (`SectionResolver.doTextCorrections`).
    (.laudes, ["Oblátus est * quia ipse vóluit, et peccáta nostra ipse portávit. ."]),
    (.laudes, ["Meménto mei, * Dómine, dum véneris in regnum tuum. ."]),
    (.laudes, ["si est dolor sicut dolor meus. ."]),
    (.vesperae, ["Commemoratio Dominica", "℣. Dirigátur, Dómine, orátio mea. ℟. Sicut incénsum in conspéctu tuo. Orémus."]),
]

/// DO errors on a date every year, at one hour or (`nil`) all (`docs/rubrics-op1962.md` §8).
private let dateDivergences: [(hour: CanonicalHour?, monthday: String)] = [
    (nil, "08-30"),             // St Rose of Lima: DO loses her rank and says the feria or Our Lady's Saturday
    (.completorium, "11-01"),   // the title names the weekday after All Saints' second Vespers
    (.laudes, "09-17"),         // St Lambert's commemoration before the Stigmata's: DO orders them by their Commons' ranks
]

private func hourSelected(_ hour: CanonicalHour) -> Bool {
    guard let only = ProcessInfo.processInfo.environment["BREVIARIUM_AUDIT_HOURS"], !only.isEmpty else { return true }
    return only.split(separator: ",").contains(Substring(hour.rawValue))
}

private func votiveSelected(_ votive: VotiveHour) -> Bool {
    let env = ProcessInfo.processInfo.environment
    if let only = env["BREVIARIUM_AUDIT_VOTIVES"], !only.isEmpty, !only.split(separator: ",").contains(Substring(votive.votive)) { return false }
    return hourSelected(votive.hour)
}

/// The bilingual Dominican pages of `archives` (one per year), with the corrections check:
/// a page that differs from DO only by a corrected DO error counts as checked.
private func dominicanBilingualReport(
    hour: CanonicalHour, officium: Officium, archives: [(year: Int, archive: [String: String])], priests: [Bool]
) -> (report: DayHourAuditReport, corrected: [String])? {
    guard let bundle = RealCorpus.bundle else { return nil }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let english = bundle.makeEnglishCorpus()
    let calendar = bundle.makeSanctoralCalendar(rite: .dominicanus)
    var report = DayHourAuditReport()
    var corrected: [String] = []
    for (year, archive) in archives {
        for priest in priests {
            var (day, month, y) = (1, 1, year)
            while y == year {
                let date = String(format: "%04d-%02d-%02d", y, month, day)
                let label = date + (priest ? " priest" : "")
                // Known DO divergences, where DO prints an error and the app the corrected
                // text (`docs/rubrics-op1962.md` §8).
                let page = archive["\(year)/\(date)_priest\(priest ? "Y" : "N")_bilingual.tsv"]
                let monthday = String(format: "%02d-%02d", month, day)
                let hourDivergence = officium == .diei && (page.map { text in
                    hourDivergences.contains { $0.hour == hour && $0.all.allSatisfy(text.contains) }
                } ?? false || dateDivergences.contains { ($0.hour == nil || $0.hour == hour) && $0.monthday == monthday })
                if let text = page, !knownDivergences.contains(where: text.contains), !hourDivergence {
                    func assemble() -> (Hour?, String?) {
                        assembleDayHour(
                            hour, day: day, month: month, year: y, priest: priest, bundle: bundle, corpus: corpus, english: english,
                            calendar: calendar, officium: officium, rite: .dominicanus
                        )
                    }
                    let (assembled, title) = assemble()
                    if let assembled {
                        let (assembled, rows) = reconciledEnglish(assembled, rows: withoutMartyrology(OracleFixture.rows(text)))
                        var single = DayHourAuditReport()
                        single.add(hour: assembled, rows: rows, title: title, date: label)
                        // A page that differs only by a correction of DO's data (`SectionResolver.
                        // correctsDOErrors`) must match DO exactly with the corrections off.
                        if !single.text.isEmpty {
                            let (uncorrected, uncorrectedTitle) = SectionResolver.$correctsDOErrors.withValue(false) { assemble() }
                            if let uncorrected {
                                let (uncorrected, rows) = reconciledEnglish(uncorrected, rows: withoutMartyrology(OracleFixture.rows(text)))
                                var check = DayHourAuditReport()
                                check.add(hour: uncorrected, rows: rows, title: uncorrectedTitle, date: label)
                                if check.text.isEmpty { corrected.append(label) }
                            }
                        }
                        if corrected.last == label {
                            report.daysChecked += 1
                        } else {
                            report.add(hour: assembled, rows: rows, title: title, date: label)
                        }
                    } else {
                        report.failedToAssemble.append(label)
                    }
                } else if page != nil {
                    report.daysChecked += 1    // a known DO error: the page is DO's fault, not unchecked
                }
                (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
            }
        }
    }
    return (report, corrected)
}

/// The Latin of the Pius XII pages: content and every psalm's title and verses, as
/// `dayHoursFullRangeBeaAudit`.
private func dominicanBeaProblems(
    hour: CanonicalHour, officium: Officium, archives: [(year: Int, archive: [String: String])]
) -> (problems: [String: [String]], daysChecked: Int)? {
    guard let bundle = RealCorpus.bundle else { return nil }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar(rite: .dominicanus)
    var problems: [String: [String]] = [:]
    var daysChecked = 0
    for (year, archive) in archives {
        var (day, month, y) = (1, 1, year)
        while y == year {
            let date = String(format: "%04d-%02d-%02d", y, month, day)
            let monthday = String(format: "%02d-%02d", month, day)
            if let text = archive["\(year)/\(date)_priestN_latin.txt"] {
                let divergence = officium == .diei && (knownDivergences.contains(where: text.contains)
                    || hourDivergences.contains { $0.hour == hour && $0.all.allSatisfy(text.contains) }
                    || dateDivergences.contains { ($0.hour == nil || $0.hour == hour) && $0.monthday == monthday })
                if divergence {
                    daysChecked += 1
                } else {
                    func misses(_ correcting: Bool) -> [String]? {
                        let (assembled, _) = SectionResolver.$correctsDOErrors.withValue(correcting) {
                            assembleDayHour(
                                hour, day: day, month: month, year: y, priest: false, bundle: bundle, corpus: corpus, english: nil,
                                calendar: calendar, officium: officium, rite: .dominicanus
                            )
                        }
                        guard let assembled else { return nil }
                        var found = latinContentMisses(hour: assembled, rows: [BilingualRow(latin: text, english: "")])
                            .map { "[\($0.0)] \($0.1.prefix(auditPrefix))" }
                        let expected = dayHourFixturePsalms(text)
                        let actual = dayHourRenderedPsalms(assembled)
                        if expected.count != actual.count {
                            found.append("DO \(expected.map { $0.title }) | engine \(actual.map { $0.title })")
                        } else if let (e, a) = zip(expected, actual).first(where: { $0 != $1 }) {
                            found.append("DO \(e) | engine \(a)".prefix(400).description)
                        }
                        return found
                    }
                    if let found = misses(true) {
                        daysChecked += 1
                        if !found.isEmpty, misses(false)?.isEmpty != true {
                            for key in found { problems[key, default: []].append(date) }
                        }
                    } else {
                        problems["not assembled", default: []].append(date)
                    }
                }
            }
            (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
        }
    }
    return (problems, daysChecked)
}

private func problemsText(_ problems: [String: [String]]) -> String {
    problems.sorted { $0.value.count > $1.value.count }.prefix(25)
        .map { "  \($0.value.count)x, e.g. \($0.value.first!): \($0.key)" }.joined(separator: "\n")
}

@Test(arguments: [CanonicalHour.vesperae, .completorium, .tertia, .sexta, .nona, .prima, .laudes, .matutinum])
func dominicanFullRangeAudit(hour: CanonicalHour) async throws {
    guard hourSelected(hour), try await OracleFixture.shared.hourYear(set: "op/hours", hour: hour, year: 2040) != nil else { return }
    var archives: [(year: Int, archive: [String: String])] = []
    for year in auditYears {
        if let archive = try await OracleFixture.shared.hourYear(set: "op/hours", hour: hour, year: year) { archives.append((year, archive)) }
    }
    guard let (report, corrected) = dominicanBilingualReport(hour: hour, officium: .diei, archives: archives, priests: [false]) else { return }
    if !corrected.isEmpty { print("Dominican \(hour): \(corrected.count) page(s) differ from DO only by a corrected DO error: \(corrected.prefix(20).joined(separator: ", "))") }
    #expect(report.daysChecked > auditYears.count * 362, "\(hour): checked \(report.daysChecked)")
    #expect(report.text.isEmpty, "\nDominican \(hour):\n\(report.text)")
}

/// The Pius XII psalter under *Dominicanus* (`op/hours-bea`).
@Test(arguments: [CanonicalHour.vesperae, .completorium, .tertia, .sexta, .nona, .prima, .laudes, .matutinum])
func dominicanFullRangeBeaAudit(hour: CanonicalHour) async throws {
    guard hourSelected(hour), try await OracleFixture.shared.hourYear(set: "op/hours-bea", hour: hour, year: 2040) != nil else { return }
    var archives: [(year: Int, archive: [String: String])] = []
    for year in auditYears {
        if let archive = try await OracleFixture.shared.hourYear(set: "op/hours-bea", hour: hour, year: year) { archives.append((year, archive)) }
    }
    guard let (problems, daysChecked) = dominicanBeaProblems(hour: hour, officium: .diei, archives: archives) else { return }
    #expect(daysChecked > auditYears.count * 362, "\(hour) (Pius XII): checked \(daysChecked)")
    #expect(problems.isEmpty, "\nDominican \(hour) (Pius XII): \(problems.count) distinct\n\(problemsText(problems))")
}

/// The 2044 hold-out, priest on and off.
@Test(arguments: [CanonicalHour.vesperae, .completorium, .tertia, .sexta, .nona, .prima, .laudes, .matutinum])
func dominicanHoldout2044(hour: CanonicalHour) async throws {
    let path = OracleFixture.repoRoot.appendingPathComponent("data/oracle-fixtures/op/holdout/2044-\(hour.doName).tar.gz")
    guard hourSelected(hour), FileManager.default.fileExists(atPath: path.path) else { return }
    let archive = try OracleFixture.extractAndRead(archive: path)
    guard let (report, corrected) = dominicanBilingualReport(hour: hour, officium: .diei, archives: [(2044, archive)], priests: [false, true])
    else { return }
    if !corrected.isEmpty { print("Dominican 2044 \(hour): \(corrected.count) corrected page(s)") }
    #expect(report.daysChecked >= 2 * 366, "2044 \(hour): checked \(report.daysChecked)")
    #expect(report.text.isEmpty, "\nDominican 2044 \(hour):\n\(report.text)")
}

/// The Little Office (C12) and the Office of the Dead (C9) under *Dominicanus*, both
/// psalters, and their 2044 hold-outs.
@Test(arguments: votiveHours)
func dominicanVotiveAudit(_ votive: VotiveHour) async throws {
    guard votiveSelected(votive) else { return }
    var archives: [(year: Int, archive: [String: String])] = []
    for year in 2025...2040 {
        if let archive = try await OracleFixture.shared.hourYear(set: "op/votives/\(votive.votive)", hour: votive.hour, year: year) {
            archives.append((year, archive))
        }
    }
    guard !archives.isEmpty, let (report, _) = dominicanBilingualReport(hour: votive.hour, officium: votive.officium, archives: archives, priests: [false])
    else { return }
    #expect(report.daysChecked >= 365, "Dominican \(votive): checked \(report.daysChecked)")
    #expect(report.text.isEmpty, "\nDominican \(votive):\n\(report.text)")

    var beaArchives: [(year: Int, archive: [String: String])] = []
    for year in 2025...2040 {
        if let archive = try await OracleFixture.shared.hourYear(set: "op/votives-bea/\(votive.votive)", hour: votive.hour, year: year) {
            beaArchives.append((year, archive))
        }
    }
    if let (problems, daysChecked) = dominicanBeaProblems(hour: votive.hour, officium: votive.officium, archives: beaArchives), !beaArchives.isEmpty {
        #expect(daysChecked >= 365, "Dominican \(votive) (Pius XII): checked \(daysChecked)")
        #expect(problems.isEmpty, "\nDominican \(votive) (Pius XII): \(problems.count) distinct\n\(problemsText(problems))")
    }

    let path = OracleFixture.repoRoot.appendingPathComponent("data/oracle-fixtures/op/holdout/2044-\(votive.votive)-\(votive.hour.doName).tar.gz")
    if FileManager.default.fileExists(atPath: path.path) {
        let archive = try OracleFixture.extractAndRead(archive: path)
        if let (report, _) = dominicanBilingualReport(hour: votive.hour, officium: votive.officium, archives: [(2044, archive)], priests: [false, true]) {
            #expect(report.daysChecked >= 2 * 366, "Dominican 2044 \(votive): checked \(report.daysChecked)")
            #expect(report.text.isEmpty, "\nDominican 2044 \(votive):\n\(report.text)")
        }
    }
}

/// DO English that translates another text than the Dominican Latin it stands beside, as
/// (its first words, the whole of it as a pattern).
private let dominicanMistranslations: [(start: String, pattern: String)] = [
    ("The morn had spread her crimson rays", #"(?s)The morn had spread her crimson rays,.*?The Spirit, God forevermore\. Amen\."#),
    ("Grace is poured into thy lips, therefore;", #"(?s)(℟\.(br\.)?\s*)?Grace is poured into thy lips, therefore;.*?Go forward, fare prosperously, and reign\."#),
    // St Mary Magdalene: *Lauda mater Ecclésia* beside *Pater supérni lúminis*'s English.
    ("Father of lights! one glance of thine", #"(?s)Father of lights! one glance of thine,.*?Be glory through eternity\. Amen\."#),
    // Saturday Vespers' responsory *Igitur perfécti sunt*: the Roman Matins responsory's
    // English, its lines not cut as the Order's Latin is.
    ("So the heavens and the earth were finished", #"(?s)(℟\.\s*)?So the heavens and the earth were finished,.*?(℣\.\s*)?Glory be to the Father, and to the Son, \* and to the Holy Ghost\.\s*(℟\.\s*)?[^℣℟]*?which he had done\."#),
    ("Grace is poured into thy lips, therefore, alleluia.", #"(?s)(℟\.(br\.)?\s*)?Grace is poured into thy lips, therefore, alleluia\..*?reign, alleluia\."#),
]

/// Decisions 5 and 6 of `docs/Beta_5_plan.md`: where the Order's text has no English, DO's
/// English column repeats the Latin, and the app shows the Latin alone or a matching
/// Roman text's English. Neither side is compared there: the Latin DO repeats is taken out
/// of its English column, and the units it repeats lose their English for the comparison.
func reconciledEnglish(_ hour: Hour, rows: [BilingualRow]) -> (Hour, [BilingualRow]) {
    var hour = hour
    var repeated: Set<String> = []
    var rows = rows
    // A Latin text our English column shows too (a responsory's "Sicut dixit vobis." over
    // an English response) is a match, not a repetition.
    let englishShown = Set(hour.sections.flatMap(\.units).flatMap(englishComparisonTexts).map { collapsedWhitespace(LatinOrthography.normalize($0)) })
    func folded(_ text: String) -> String {
        text.replacingOccurrences(of: "ǽ", with: "æ").replacingOccurrences(of: "Ǽ", with: "Æ")
            .folding(options: .diacriticInsensitive, locale: nil).replacingOccurrences(of: "j", with: "i").replacingOccurrences(of: "J", with: "I")
    }
    // Pieces of 12 letters and more, and shorter ones (*Et suávis.*, *Allelúia.*) from a
    // unit the app shows in Latin alone, or a rubric ("Et chorus:").
    var pieceSet: Set<String> = []
    for unit in hour.sections.flatMap(\.units) {
        let latinOnly = englishComparisonTexts(unit).isEmpty
        for text in oracleComparisonTexts(unit).map({ collapsedWhitespace(LatinOrthography.normalize($0)) }) where !englishShown.contains(text) {
            if text.count >= 12 || (text.count >= 8 && (latinOnly || text.hasSuffix(":")))
                || (text.count >= 6 && latinOnly && text.contains(where: \.isNumber)) // a Gospel's "Cap. 13"
            {
                pieceSet.insert(text)
            }
        }
    }
    // Nor Latin whose letters the app's English shows too ("Allelúia, allelúia." beside
    // "Alleluia, alleluia.").
    let foldedShown = Set(englishShown.map(folded))
    let pieces = pieceSet.filter { $0.count < 12 || !foldedShown.contains(folded($0)) }.sorted { $0.count > $1.count }
    // DO's English column keeps its J spelling ("cujus"), its English its J's ("Jesu"),
    // and its Latin sometimes another accentuation ("alleluia"): a long piece is matched
    // either way, a short one exactly, and the English is left as DO has it.
    // Matched on decomposed text, each letter with any accents it carries.
    func pattern(_ piece: String) -> String {
        guard piece.count >= 12 else {
            return NSRegularExpression.escapedPattern(for: piece)
                .replacingOccurrences(of: "i", with: "[ij]").replacingOccurrences(of: "I", with: "[IJ]")
        }
        return folded(piece).map { character -> String in
            switch character {
            case "i", "I": return "[iIjJ]\\p{M}*"
            case let letter where letter.isLetter: return "[\(letter.lowercased())\(letter.uppercased())]\\p{M}*"
            default: return NSRegularExpression.escapedPattern(for: String(character))
            }
        }.joined()
    }
    // DO's English for a Dominican text it has no translation of, wrongly: a different
    // hymn's (the Paschal Lauds hymn, *Sermóne blando*, under *Aurora cælum purpurat*'s
    // English) or a substitution's mangled lines (the virgins' short responsory at
    // Terce, 21 January). The app shows the Latin alone; the English DO shows is left out
    // of the comparison when the app shows none of it.
    let shownEnglish = hour.sections.flatMap(\.units).flatMap(englishComparisonTexts).joined(separator: " ")
    for (start, pattern) in dominicanMistranslations where !shownEnglish.contains(start) {
        for index in rows.indices where rows[index].english.contains(start) {
            rows[index].english = rows[index].english.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
    }
    // A chapter whose English DO takes from another text (Advent Sundays at Sext and
    // None: Romans beside the Order's Isaiah): DO's Latin column has the app's reference,
    // its English column another one. That English is left out, and so is the app's.
    var swappedChapters: Set<String> = []
    for unit in hour.sections.filter({ $0.kind == .capitulum }).flatMap(\.units) {
        // The app's English is this chapter's own, or none (`DominicanEnglish`'s foreign chapter).
        guard case .psalmTitle(let latinReference, let english) = unit, let citation = DominicanEnglish.citation(latinReference),
            english.map({ DominicanEnglish.citation($0) == citation }) ?? true else { continue }
        for index in rows.indices where rows[index].latin.contains(latinReference) && !rows[index].english.contains(citation) {
            let other = #"(?s)\b(?:\d )?[A-Z][a-z]+\.? \d+:\d+(?:-\d+)? .*?(?=℟\. Thanks be to God)"#
            if rows[index].english.range(of: other, options: .regularExpression) != nil {
                rows[index].english = rows[index].english.replacingOccurrences(of: other, with: " ", options: .regularExpression)
                swappedChapters.insert(latinReference)
            }
        }
    }
    if !swappedChapters.isEmpty {
        hour.sections = hour.sections.map { section in
            guard section.kind == .capitulum else { return section }
            var section = section
            var inChapter = false
            section.units = section.units.map { unit in
                switch unit {
                case .psalmTitle(let text, _) where swappedChapters.contains(text):
                    inChapter = true
                    return .psalmTitle(text)
                case .prose(let text, _) where inChapter: return .prose(text)
                default:
                    inChapter = false
                    return unit
                }
            }
            return section
        }
    }
    // Latin the app shows in its English column too (half a responsory DO has no English
    // for) is spelt with I, as DO's Latin column; DO's English column keeps its J.
    let latinShownAsEnglish = englishShown.filter { $0.count >= 12 && $0.rangeOfCharacter(from: CharacterSet(charactersIn: "áéíóúǽ")) != nil }
    for index in rows.indices where rows[index].english.contains("J") || rows[index].english.contains("j") {
        for text in latinShownAsEnglish {
            rows[index].english = rows[index].english.decomposedStringWithCanonicalMapping
                .replacingOccurrences(of: pattern(text), with: NSRegularExpression.escapedTemplate(for: text), options: .regularExpression)
                .precomposedStringWithCanonicalMapping
        }
    }
    for index in rows.indices {
        var english = collapsedWhitespace(rows[index].english)
        let normalized = LatinOrthography.normalize(english)
        let foldedEnglish = folded(english)
        for piece in pieces where piece.count >= 12 ? foldedEnglish.contains(folded(piece)) : normalized.contains(piece) {
            // With its verse number, if it has one (a lesson's "9 Et idcírco…"), but not
            // the end of a chapter's reference ("Sir 45:1-2 Diléctus…").
            english = english.decomposedStringWithCanonicalMapping.replacingOccurrences(
                of: #"((?<!\p{L} )(?<!Cap\. )(?<![-:.,])\b\d+ )?"# + pattern(piece), with: " ", options: .regularExpression
            ).precomposedStringWithCanonicalMapping
            repeated.insert(piece)
        }
        if !repeated.isEmpty { rows[index].english = collapsedWhitespace(english) }
    }
    guard !repeated.isEmpty else { return (hour, rows) }
    let doEnglish = rows.map { collapsedWhitespace($0.english) }.joined(separator: " ")
    hour.sections = hour.sections.map { section in
        var section = section
        section.units = section.units.map { unit in
            let latin = oracleComparisonTexts(unit).map { collapsedWhitespace(LatinOrthography.normalize($0)) }
            // A lesson whose one written-out line DO repeats keeps the English of the rest.
            let long = latin.filter { $0.count >= 12 }
            // The same Latin said twice, once with English (All Souls' Compline: the
            // *Requiéscant in pace* of the prayers, and of the special conclusion without).
            let english = englishComparisonTexts(unit).filter { $0.count >= 8 }
            if !english.isEmpty, english.allSatisfy({ text in doEnglish.contains(collapsedWhitespace(text)) }) { return unit }
            // A versicle DO repeats in Latin over an English response keeps that response.
            if case .versicleResponse(let v, let r, let ve, let re) = unit, ve != nil, re != nil {
                let vRepeated = repeated.contains(collapsedWhitespace(LatinOrthography.normalize(v)))
                let rRepeated = repeated.contains(collapsedWhitespace(LatinOrthography.normalize(r)))
                if vRepeated != rRepeated {
                    return .versicleResponse(versicle: v, response: r, versicleEnglish: vRepeated ? nil : ve, responseEnglish: rRepeated ? nil : re)
                }
            }
            guard !long.isEmpty, long.allSatisfy(repeated.contains) else { return unit }
            switch unit {
            case .rubric(let text, _): return .rubric(text)
            case .versicleResponse(let v, let r, _, _): return .versicleResponse(versicle: v, response: r)
            case .verse(let reference, let first, let second, _, _): return .verse(reference: reference, firstHalf: first, secondHalf: second)
            case .antiphon(let text, _): return .antiphon(text)
            case .prose(let text, _): return .prose(text)
            case .psalmTitle(let text, _): return .psalmTitle(text)
            case .lesson(let paragraph): return .lesson(LessonParagraph(lines: paragraph.lines))
            default: return unit
            }
        }
        return section
    }
    return (hour, rows)
}
