import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 6: Ambrosian Compline (`docs/rubrics-ambrosian-compline.md`). Divinum Officium
// can't check it, so these tests come from the sources themselves: Church of Ambrose's
// four Compline parts and the 1957 *Kalendarium Ambrosianum* with its tables.

private func ambrosianData() throws -> AmbrosianData {
    let root = OracleFixture.repoRoot.appendingPathComponent("data/ambrosian")
    return try AmbrosianSource.data(
        compline: String(contentsOf: root.appendingPathComponent("completorium-1957.txt"), encoding: .utf8),
        corrections: String(contentsOf: root.appendingPathComponent("corrections.txt"), encoding: .utf8),
        calendar: String(contentsOf: root.appendingPathComponent("kalendarium.txt"), encoding: .utf8)
    )
}

private func texts(_ unit: BreviariumKit.Unit) -> [String] {
    switch unit {
    case .prose(let t, _), .antiphon(let t, _), .rubric(let t, _), .psalmTitle(let t, _): [t]
    case .versicleResponse(let v, let r, _, _): [v, r]
    case .verse(_, let a, let b, _, _): [a, b]
    default: []
    }
}

private func allText(_ hour: Hour) -> String {
    hour.sections.flatMap(\.units).flatMap(texts).map(InlineRubrics.unmarked).joined(separator: "\n")
}

// MARK: The sources

@Test func ambrosianSourcesBuild() throws {
    let data = try ambrosianData()
    #expect(data.compline.count > 40)
    #expect(data.calendar.count > 250)
    // The bundle the app ships carries them (a correction that failed to apply would make
    // the pipeline throw, and every oracle test skip: this catches it).
    if FileManager.default.fileExists(atPath: OracleFixture.repoRoot.appendingPathComponent("data/divinum-officium").path) {
        #expect(RealCorpus.bundle?.ambrosian == data)
    }
}

@Test func ambrosianCorrectionsAndSpellingAreApplied() throws {
    let joined = try ambrosianData().compline.flatMap(\.lines).joined(separator: "\n")
    for misprint in ["venitatem", "quæriis", "costituisti", "mandavit da te", "superme", "promissoinibus", "guadia", "Utrisuqe", "Indulgetiam", "AIma"] {
        #expect(!joined.contains(misprint), "\(misprint) is still there")
    }
    // Doubtful readings are left as printed.
    #expect(joined.contains("et dena millia"))
    // J -> I; the source's accents stay, none added.
    #expect(!joined.contains("j") && !joined.contains("J"))
    #expect(joined.contains("Halleluiah."))
    #expect(joined.contains("Kyrie, eleison. Kyrie, eleison. Kyrie, eleison."))
}

// MARK: The calendar

/// The *Tabella temporaria festorum mobilium*, 1955-2000 (*Missale Ambrosianum*, 1954, after p. XVIII):
/// year, Septuagesima, 1st Sunday of Lent, Easter, Ascension, Pentecost, Corpus Christi,
/// 1st Sunday of Advent (November), as "D.M".
private let tabella: [(Int, String, String, String, String, String, String, Int)] = [
    (1955, "6.2", "27.2", "10.4", "19.5", "29.5", "9.6", 13), (1956, "29.1", "19.2", "1.4", "10.5", "20.5", "31.5", 18),
    (1957, "17.2", "10.3", "21.4", "30.5", "9.6", "20.6", 17), (1958, "2.2", "23.2", "6.4", "15.5", "25.5", "5.6", 16),
    (1959, "25.1", "15.2", "29.3", "7.5", "17.5", "28.5", 15), (1960, "14.2", "6.3", "17.4", "26.5", "5.6", "16.6", 13),
    (1961, "29.1", "19.2", "2.4", "11.5", "21.5", "1.6", 12), (1962, "18.2", "11.3", "22.4", "31.5", "10.6", "21.6", 18),
    (1963, "10.2", "3.3", "14.4", "23.5", "2.6", "13.6", 17), (1964, "26.1", "16.2", "29.3", "7.5", "17.5", "28.5", 15),
    (1965, "14.2", "7.3", "18.4", "27.5", "6.6", "17.6", 14), (1966, "6.2", "27.2", "10.4", "19.5", "29.5", "9.6", 13),
    (1967, "22.1", "12.2", "26.3", "4.5", "14.5", "25.5", 12), (1968, "11.2", "3.3", "14.4", "23.5", "2.6", "13.6", 17),
    (1969, "2.2", "23.2", "6.4", "15.5", "25.5", "5.6", 16), (1970, "25.1", "15.2", "29.3", "7.5", "17.5", "28.5", 15),
    (1971, "7.2", "28.2", "11.4", "20.5", "30.5", "10.6", 14), (1972, "30.1", "20.2", "2.4", "11.5", "21.5", "1.6", 12),
    (1973, "18.2", "11.3", "22.4", "31.5", "10.6", "21.6", 18), (1974, "10.2", "3.3", "14.4", "23.5", "2.6", "13.6", 17),
    (1975, "26.1", "16.2", "30.3", "8.5", "18.5", "29.5", 16), (1976, "15.2", "7.3", "18.4", "27.5", "6.6", "17.6", 14),
    (1977, "6.2", "27.2", "10.4", "19.5", "29.5", "9.6", 13), (1978, "22.1", "12.2", "26.3", "4.5", "14.5", "25.5", 12),
    (1979, "11.2", "4.3", "15.4", "24.5", "3.6", "14.6", 18), (1980, "3.2", "24.2", "6.4", "15.5", "25.5", "5.6", 16),
    (1981, "15.2", "8.3", "19.4", "28.5", "7.6", "18.6", 15), (1982, "7.2", "28.2", "11.4", "20.5", "30.5", "10.6", 14),
    (1983, "30.1", "20.2", "3.4", "12.5", "22.5", "2.6", 13), (1984, "19.2", "11.3", "22.4", "31.5", "10.6", "21.6", 18),
    (1985, "3.2", "24.2", "7.4", "16.5", "26.5", "6.6", 17), (1986, "26.1", "16.2", "30.3", "8.5", "18.5", "29.5", 16),
    (1987, "15.2", "8.3", "19.4", "28.5", "7.6", "18.6", 15), (1988, "31.1", "21.2", "3.4", "12.5", "22.5", "2.6", 13),
    (1989, "22.1", "12.2", "26.3", "4.5", "14.5", "25.5", 12), (1990, "11.2", "4.3", "15.4", "24.5", "3.6", "14.6", 18),
    (1991, "27.1", "17.2", "31.3", "9.5", "19.5", "30.5", 17), (1992, "16.2", "8.3", "19.4", "28.5", "7.6", "18.6", 15),
    (1993, "7.2", "28.2", "11.4", "20.5", "30.5", "10.6", 14), (1994, "30.1", "20.2", "3.4", "12.5", "22.5", "2.6", 13),
    (1995, "12.2", "5.3", "16.4", "25.5", "4.6", "15.6", 19), (1996, "4.2", "25.2", "7.4", "16.5", "26.5", "6.6", 17),
    (1997, "26.1", "16.2", "30.3", "8.5", "18.5", "29.5", 16), (1998, "8.2", "1.3", "12.4", "21.5", "31.5", "11.6", 15),
    (1999, "31.1", "21.2", "4.4", "13.5", "23.5", "3.6", 14), (2000, "20.2", "12.3", "23.4", "1.6", "11.6", "22.6", 12),
]

/// Misprints in the printed *Tabella* (`docs/rubrics-ambrosian-compline.md` §3): 1995's
/// Advent is printed 19 November, but 11 November 1995 was a Saturday, so the first
/// Sunday after St Martin is the 12th (as in 1989, the same weekday pattern, printed 12).
private let tabellaMisprints: Set<String> = ["1995 advent"]

@Test func ambrosianMovableFeastsMatchTheTabella() {
    func doy(_ text: String, _ year: Int) -> Int {
        let parts = text.split(separator: ".").compactMap { Int($0) }
        return Computus.dayOfYear(day: parts[0], month: parts[1], year: year)
    }
    for (year, septuagesima, quadragesima, easter, ascension, pentecost, corpusChristi, advent) in tabella {
        let m = AmbrosianCalendar.movableFeasts(year: year)
        #expect(m.septuagesima == doy(septuagesima, year), "\(year) Septuagesima")
        #expect(m.quadragesima == doy(quadragesima, year), "\(year) Lent")
        #expect(m.easter == doy(easter, year), "\(year) Easter")
        #expect(m.ascension == doy(ascension, year), "\(year) Ascension")
        #expect(m.pentecost == doy(pentecost, year), "\(year) Pentecost")
        #expect(m.corpusChristi == doy(corpusChristi, year), "\(year) Corpus Christi")
        if tabellaMisprints.contains("\(year) advent") {
            #expect(m.advent != Computus.dayOfYear(day: advent, month: 11, year: year))
        } else {
            #expect(m.advent == Computus.dayOfYear(day: advent, month: 11, year: year), "\(year) Advent")
        }
    }
}

@Test func ambrosianPartsAndMarianAntiphonsChangeOnTheirDays() {
    // 2026: Lent from 22 February, Easter 5 April, Pentecost 24 May.
    typealias P = AmbrosianCalendar.Part
    let cases: [(Int, Int, P, AmbrosianCalendar.MarianAntiphon?)] = [
        (21, 2, .hiemalisPrima, .alma),        // the Saturday before Lent keeps its own season
        (22, 2, .hiemalisSecunda, .salve),
        (3, 4, .hiemalisSecunda, nil),         // Good Friday: no Salve
        (4, 4, .hiemalisSecunda, .salve),      // Holy Saturday is still Lent
        (5, 4, .aestivaPrima, .reginaCaeli),
        (30, 5, .aestivaPrima, .reginaCaeli),  // the Saturday after Pentecost (unsourced)
        (31, 5, .aestivaSecunda, .inviolata),
        (7, 9, .aestivaSecunda, .inviolata),
        (8, 9, .aestivaSecunda, .aveRegina),
        (4, 10, .hiemalisPrima, .aveRegina),
        (24, 12, .hiemalisPrima, .aveRegina),
        (25, 12, .hiemalisPrima, .alma),
    ]
    for (day, month, part, antiphon) in cases {
        #expect(AmbrosianCalendar.part(day: day, month: month, year: 2026) == part, "\(day).\(month)")
        #expect(AmbrosianCalendar.marianAntiphon(day: day, month: month, year: 2026) == antiphon, "\(day).\(month)")
    }
}

@Test func ambrosianFestalForm() throws {
    let calendar = AmbrosianCalendar(entries: try ambrosianData().calendar)
    let festal: [(Int, Int)] = [
        (7, 6),    // a Sunday
        (24, 6),   // the Nativity of St John Baptist (Wednesday)
        (29, 6),   // Ss Peter and Paul
        (15, 8),   // the Assumption
        (6, 8),    // the Transfiguration, Sol. Dom.
        (28, 12),  // in the octave of Christmas
        (19, 3),   // St Joseph, in Lent
        (7, 4),    // Easter Tuesday
        (4, 6),    // Corpus Christi, *In Solemnitate* (Series Missarum)
        (9, 6),    // in Corpus Christi's octave
    ]
    let ferial: [(Int, Int)] = [
        (2, 6),    // a Tuesday, Ss Marcellinus and Peter, no rank
        (21, 7),   // a Solemne saint on a Tuesday: not one of the rubric's days
        (24, 2),   // a weekday of Lent
        (31, 3),   // Tuesday in Holy Week
        (18, 5), (19, 5), (20, 5),  // the Triduum Litaniarum
        (12, 6),   // the Sacred Heart, a *Festum*, not a *Solemnitas* (unsourced)
    ]
    for (day, month) in festal { #expect(calendar.isFestal(day: day, month: month, year: 2026), "\(day).\(month)") }
    for (day, month) in ferial { #expect(!calendar.isFestal(day: day, month: month, year: 2026), "\(day).\(month)") }
}

@Test func ambrosianTitleBlock() throws {
    let calendar = AmbrosianCalendar(entries: try ambrosianData().calendar)
    func name(_ d: Int, _ m: Int, _ y: Int = 2026) -> String { calendar.titleBlock(day: d, month: m, year: y).nameLine }
    #expect(name(7, 12) == "ORDINATIO S. AMBROSII EPISC. CONF. ET DOCT.")
    #expect(calendar.titleBlock(day: 7, month: 12, year: 2026).classisLine == "Sol. I cl.")
    #expect(name(5, 4) == "Pascha")
    #expect(name(24, 2) == "Feria III hebdomadæ I Quadragesimæ")   // Lent: no saints
    #expect(name(15, 1) == "S. Ioannis Boni Episc. Mediol. et Conf.")
    #expect(calendar.titleBlock(day: 15, month: 1, year: 2026).commemorationLine == "Commem. S. Pauli primi Eremitæ Conf.")
}

/// The Sundays and the days of the season, as the Missal's *Series Missarum* names them.
@Test func ambrosianTemporalNames() throws {
    let calendar = AmbrosianCalendar(entries: try ambrosianData().calendar)
    func name(_ d: Int, _ m: Int, _ y: Int = 2026) -> String { calendar.titleBlock(day: d, month: m, year: y).nameLine }
    #expect(name(25, 1) == "Dominica VI post Epiphaniam")       // always the Sunday before Septuagesima
    #expect(name(26, 1) == "Festum S. Familiæ Iesu, Mariæ, Ioseph")  // Monday after the 3rd Sunday after Epiphany
    #expect(name(1, 3) == "Dominica II Quadragesimæ: de Samaritana")
    #expect(name(22, 3) == "Dominica V Quadragesimæ: de Lazaro")
    #expect(name(28, 3) == "Sabbato in traditione Symboli")
    #expect(name(29, 3) == "Dominica Palmarum")
    #expect(name(2, 4) == "Feria V in Cœna Domini")
    #expect(name(10, 4) == "Feria VI in Albis")
    #expect(name(12, 4) == "Dominica I post Pascha, in Albis depositis")
    #expect(name(17, 5) == "Dominica post Ascensionem")
    #expect(name(18, 5) == "Dies primus in Litaniis")
    #expect(name(31, 5) == "Dominica I post Pentecosten: SS. Trinitatis")
    #expect(name(4, 6) == "Solemnitas SS. Corporis Christi")
    #expect(name(12, 6) == "Festum SS. Cordis Iesu")
    #expect(name(23, 8) == "Dominica XIII post Pentecosten")
    #expect(name(30, 8) == "Dominica I post Decollationem")
    #expect(name(18, 10) == "Dominica III Octobris: in Dedicatione Ecclesiæ Maioris")
    #expect(name(25, 10) == "Dominica ultima Octobris: in Festo D. N. Iesu Christi Regis")
    #expect(name(8, 11) == "Dominica III post Dedicationem")
    #expect(name(15, 11) == "Dominica I Adventus")
    #expect(name(20, 12) == "Dominica VI Adventus")
    // The Deposition of St Ambrose, *cuius commem. semper fit Feria V in Albis*.
    #expect(calendar.titleBlock(day: 9, month: 4, year: 2026).commemorationLine == "Commem. Depositio S. Ambrosii Episc. et Doct.")
}

/// § 2: a Sunday gives way only to a Solemnity of the Lord; a saint moves to the Monday.
/// § 3: on a privileged day no saint is kept.
@Test func ambrosianOccurrence() throws {
    let calendar = AmbrosianCalendar(entries: try ambrosianData().calendar)
    func name(_ d: Int, _ m: Int, _ y: Int) -> String { calendar.titleBlock(day: d, month: m, year: y).nameLine }
    // 2026: the Finding of the Cross (Sol. Dom. II cl.) takes the Sunday, with its commemoration.
    #expect(name(3, 5, 2026) == "Inventio S. Crucis")
    #expect(calendar.titleBlock(day: 3, month: 5, year: 2026).commemorationLine == "Commem. Dominica IV post Pascha")
    // 2024: the Immaculate Conception on the 4th Sunday of Advent moves to the Monday, which
    // takes Our Lady's festal form; St Syrus, lower, is commemorated.
    #expect(name(8, 12, 2024) == "Dominica IV Adventus")
    #expect(name(9, 12, 2024) == "IMMACULATA CONCEPTIO B. M. V.")
    #expect(calendar.titleBlock(day: 9, month: 12, year: 2024).commemorationLine == "Commem. S. Syri Episc. et Conf.")
    #expect(calendar.isFestal(day: 9, month: 12, year: 2024))
    // 2023: St Joseph on a Sunday of Lent is kept (§ 42), with the Sunday commemorated.
    #expect(name(19, 3, 2023) == "S. IOSEPH SPONSI B. M. V. ET ECCL. CATHOL. PATRONI")
    // 2027: the Annunciation on Maundy Thursday gives way (Holy Week is privileged).
    #expect(name(25, 3, 2027) == "Feria V in Cœna Domini")
    #expect(!calendar.isFestal(day: 25, month: 3, year: 2027))
    // 2026: the Chair of St Peter at Antioch falls in Lent, so it is kept on 4 February.
    #expect(name(22, 2, 2026) == "Dominica in Quadragesima")
    #expect(name(4, 2, 2026) == "Cathedra S. Petri Antiochiæ")
}

/// The colours (§§ 38–43).
@Test func ambrosianColors() throws {
    let calendar = AmbrosianCalendar(entries: try ambrosianData().calendar)
    let cases: [(Int, Int, CalendarColor)] = [
        (24, 2, .black),   // a weekday of Lent
        (1, 3, .violet),   // a Sunday of Lent
        (28, 3, .red),     // from the Saturday *in traditione Symboli*
        (7, 4, .white),    // Easter week
        (12, 4, .green),   // *Dominica in Albis depositis*
        (18, 5, .black),   // the Litanies
        (26, 5, .white),   // St Philip Neri, a confessor, in Pentecost week
        (7, 6, .red),      // a Sunday after Pentecost
        (25, 10, .white),  // Christ the King
        (1, 11, .green),   // after the Dedication
        (15, 11, .violet), // Advent
        (20, 12, .white),  // the 6th Sunday of Advent, *Missus est*
        (7, 2, .red),      // St Matthias, an apostle
        (17, 1, .green),   // St Anthony, an abbot
        (7, 10, .violet),  // St Bridget, a matron
    ]
    for (day, month, color) in cases { #expect(calendar.color(day: day, month: month, year: 2026) == color, "\(day).\(month)") }
}

// MARK: The hour

@Test func ambrosianComplineShapes() throws {
    let compline = AmbrosianCompline(data: try ambrosianData())
    func kinds(_ d: Int, _ m: Int, priest: Bool = true) -> [Section.Kind] {
        compline.assemble(day: d, month: m, year: 2026, priest: priest).sections.map(\.kind)
    }
    // A weekday after Pentecost: ferial, with the preces.
    #expect(kinds(2, 6) == [.introductio, .hymnus, .psalmodia, .epistolella, .responsoriumBreve, .canticum, .capitulum,
                            .precesFeriales, .oratio, .conclusio, .antiphonaFinalis, .confessio])
    // A Sunday: festal, no preces.
    #expect(!kinds(7, 6).contains(.precesFeriales))
    // Lent: two hymns, Lux alma first.
    let lent = compline.assemble(day: 24, month: 2, year: 2026, priest: true)
    #expect(lent.sections.filter { $0.kind == .hymnus }.count == 2)
    #expect(allText(lent).contains("Lux alma, Christe, mentium"))
    #expect(allText(lent).contains("Laus tibi, Domine, Rex æternæ gloriæ."))
    #expect(!allText(lent).contains("Halleluiah"))
    // Good Friday: no Marian antiphon.
    #expect(!kinds(3, 4).contains(.antiphonaFinalis))
    // Paschaltide: Regina cæli.
    #expect(allText(compline.assemble(day: 7, month: 4, year: 2026, priest: true)).contains("Regina cæli, lætare."))
}

@Test func ambrosianComplineWithoutAPriest() throws {
    let compline = AmbrosianCompline(data: try ambrosianData())
    let text = allText(compline.assemble(day: 2, month: 6, year: 2026, priest: false))
    #expect(text.contains("Domine, exaudi orationem meam."))
    #expect(!text.contains("Dominus vobiscum."))
    #expect(!text.contains("vobis, fratres") && !text.contains("vos, fratres"))
    #expect(!text.contains("tibi, pater") && !text.contains("te, pater"))
    #expect(text.contains("Misereatur nostri omnipotens Deus"))
    #expect(text.contains("beato Ambrosio confessori"))
    let withPriest = allText(compline.assemble(day: 2, month: 6, year: 2026, priest: true))
    #expect(withPriest.contains("et vobis, fratres"))
}

/// The user's ruling (10 October 2026): the five texts Ambrosian Compline shares with the
/// Roman one take its signs of the cross, which the source doesn't print, with a priest
/// and without.
@Test func ambrosianComplineCrosses() throws {
    let compline = AmbrosianCompline(data: try ambrosianData())
    for priest in [true, false] {
        let text = allText(compline.assemble(day: 9, month: 10, year: 2026, priest: priest))
        #expect(text.contains("Converte nos, ✙︎ Deus salutaris noster:"))
        #expect(text.contains("Deus, + in adiutorium meum intende:"))
        #expect(text.contains("Indulgentiam, + absolutionem"))
        #expect(text.contains("Adiutorium nostrum + in nomine Domini:"))
        #expect(text.contains("Nunc dimittis, + Domine, servum tuum,*"))
        #expect(text.components(separatedBy: "+").count - 1 == 4, "only the Roman office's crosses")
    }
}

/// Every text the hour shows comes from the transcription (`ambrosian-sources.md`: no
/// Roman fallback, provenance for every text): each unit's text is found in the pieces,
/// and every piece used has its source pages.
@Test func ambrosianComplineComesOnlyFromItsSource() throws {
    let compline = AmbrosianCompline(data: try ambrosianData())
    let source = compline.pieces.values.flatMap(\.lines).map { line -> String in
        var line = line
        for prefix in ["^", "!", "V. ", "R. br. ", "R. ", "Ant. "] where line.hasPrefix(prefix) { line.removeFirst(prefix.count); break }
        return line
    }.joined(separator: "\n") + "\nDomine, exaudi orationem meam.\nEt clamor meus ad te veniat."
    // Psalm verses carry their asterisk on the first half; compare without it.
    func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "*", with: " ").split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }
    let plainSource = source.split(separator: "\n").map { plain(String($0)) }.joined(separator: "\n")
    var (day, month, year) = (1, 1, 2026)
    while year == 2026 {
        for priest in [true, false] {
            let hour = compline.assemble(day: day, month: month, year: year, priest: priest)
            for text in hour.sections.flatMap(\.units).flatMap(texts) where !text.isEmpty {
                let shown = InlineRubrics.unmarked(text).split(separator: "\n").map { plain(String($0)) }.joined(separator: "\n")
                #expect(plainSource.contains(shown), "\(day).\(month): not in the source: \(shown.prefix(80))")
            }
            // No Roman Compline text slips in: its lesson, its blessing, its responsory and
            // its hymn are not Ambrosian. Texts both share (*Converte nos*, *Te lucis*, Psalm 4, Psalm
            // 30's *In manus tuas commendo*) are not listed.
            let folded = hour.sections.flatMap(\.units).flatMap(texts).joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            for roman in ["iube, domne", "sobrii estote", "in manus tuas, domine", "tu autem, domine, miserere nobis", "benedicat et custodiat nos", "concedat nobis dominus omnipotens"] {
                #expect(!folded.contains(roman), "\(day).\(month): a Roman text: \(roman)")
            }
            for (piece, pages) in compline.provenance(day: day, month: month, year: year, priest: priest) {
                #expect(!pages.isEmpty, "\(piece) has no source page")
            }
        }
        (day, month, year) = Computus.addDays(1, day: day, month: month, year: year)
    }
}

// MARK: The user's checks (`docs/Beta_6_plan.md` §8)

/// Writes checks 4 and 5 as Markdown, from the engine itself, so the tables are what the
/// app does: `BREVIARIUM_AMBROSIAN_REPORT=<path> swift test --filter ambrosianChecksReport`.
/// The output is `docs/ambrosian-compline-checks-tables.md`.
@Test(.enabled(if: ProcessInfo.processInfo.environment["BREVIARIUM_AMBROSIAN_REPORT"] != nil))
func ambrosianChecksReport() throws {
    let data = try ambrosianData()
    let compline = AmbrosianCompline(data: data)
    let calendar = compline.calendar
    let months = ["", "ianuarii", "februarii", "martii", "aprilis", "maii", "iunii", "iulii", "augusti", "septembris", "octobris", "novembris", "decembris"]
    let partNames: [AmbrosianCalendar.Part: String] = [
        .hiemalisPrima: "hiemalis I", .hiemalisSecunda: "hiemalis II", .aestivaPrima: "æstiva I", .aestivaSecunda: "æstiva II",
    ]
    func date(_ doy: Int, _ year: Int) -> String {
        var (d, m, y) = (1, 1, year)
        for _ in 1..<doy { (d, m, y) = Computus.addDays(1, day: d, month: m, year: y) }
        return "\(d) \(months[m])"
    }
    func title(_ block: TitleBlock) -> String {
        [block.classisLine, block.nameLine, block.commemorationLine].compactMap { $0 }.joined(separator: " / ")
    }
    func cell(_ text: String) -> String { text.replacingOccurrences(of: "|", with: "\\|") }

    var out = """
        # Ambrosian Compline: tables for the user's checks

        Generated from the engine by `ambrosianChecksReport` (`AmbrosianComplineTests.swift`);
        don't edit by hand. The checks themselves are in `ambrosian-compline-checks.md`.


        """

    out += "## Check 4: the calendar, entry by entry, as the app reads it in 2026\n\n"
    out += "Form: **festal** (no *preces*) or ferial. Part: the Compline booklet the date takes.\n\n"
    out += "| Date | Page | Feast | Rank | Note | 2026 | Part | Form | Title block |\n|---|---|---|---|---|---|---|---|---|\n"
    for entry in data.calendar {
        let parts = entry.date.split(separator: "-").compactMap { Int($0) }
        let (month, day) = (parts[0], parts[1])
        if month == 2, day == 29 { continue }
        let weekday = AmbrosianCalendar.weekdays[Computus.dayOfWeek(day: day, month: month, year: 2026)]
        let part = AmbrosianCalendar.part(day: day, month: month, year: 2026)
        let festal = calendar.isFestal(day: day, month: month, year: 2026)
        out += "| \(day) \(months[month]) | \(entry.page) | \(cell(entry.feast)) | \(cell(entry.rank)) | \(cell(entry.note)) | \(weekday) | \(partNames[part]!) | \(festal ? "**festal**" : "ferial") | \(cell(title(calendar.titleBlock(day: day, month: month, year: 2026)))) |\n"
    }

    out += "\n## Check 5: the movable feasts\n\n"
    out += "Computed by the engine. 1955–2000 against the *Tabella temporaria* (✓ = the same; the one difference is marked).\n\n"
    out += "| Year | Septuagesima | Lent I | Easter | Ascension | Pentecost | Corpus Christi | Advent I | Tabella |\n|---|---|---|---|---|---|---|---|---|\n"
    let printed = Dictionary(tabella.map { ($0.0, $0) }, uniquingKeysWith: { a, _ in a })
    for year in Array(1955...2000) + Array(2025...2040) + [2044] {
        let m = AmbrosianCalendar.movableFeasts(year: year)
        var check = "—"
        if let row = printed[year] {
            func doy(_ text: String) -> Int {
                let p = text.split(separator: ".").compactMap { Int($0) }
                return Computus.dayOfYear(day: p[0], month: p[1], year: year)
            }
            let same = [m.septuagesima == doy(row.1), m.quadragesima == doy(row.2), m.easter == doy(row.3), m.ascension == doy(row.4),
                        m.pentecost == doy(row.5), m.corpusChristi == doy(row.6)].allSatisfy { $0 }
            let advent = m.advent == Computus.dayOfYear(day: row.7, month: 11, year: year)
            check = same && advent ? "✓" : same ? "Advent printed \(row.7) novembris (misprint: 11 November was a \(AmbrosianCalendar.weekdays[Computus.dayOfWeek(day: 11, month: 11, year: year)]))" : "**differs**"
        }
        out += "| \(year) | \(date(m.septuagesima, year)) | \(date(m.quadragesima, year)) | \(date(m.easter, year)) | \(date(m.ascension, year)) | \(date(m.pentecost, year)) | \(date(m.corpusChristi, year)) | \(date(m.advent, year)) | \(check) |\n"
    }

    out += "\n## Every day of 2026\n\n"
    out += "| Date | Day | Part | Form | Colour | Marian antiphon | Title block |\n|---|---|---|---|---|---|---|\n"
    let antiphonNames: [AmbrosianCalendar.MarianAntiphon: String] = [
        .aveRegina: "Ave, Regina cælorum", .alma: "Alma Redemptoris", .salve: "Salve, Regina", .reginaCaeli: "Regina cæli", .inviolata: "Inviolata",
    ]
    var (day, month, year) = (1, 1, 2026)
    while year == 2026 {
        let weekday = AmbrosianCalendar.weekdays[Computus.dayOfWeek(day: day, month: month, year: year)]
        let part = AmbrosianCalendar.part(day: day, month: month, year: year)
        let antiphon = AmbrosianCalendar.marianAntiphon(day: day, month: month, year: year).map { antiphonNames[$0]! } ?? "(none)"
        let festal = calendar.isFestal(day: day, month: month, year: year)
        out += "| \(day) \(months[month]) | \(weekday) | \(partNames[part]!) | \(festal ? "**festal**" : "ferial") | \(calendar.color(day: day, month: month, year: year).rawValue) | \(antiphon) | \(cell(title(calendar.titleBlock(day: day, month: month, year: year)))) |\n"
        (day, month, year) = Computus.addDays(1, day: day, month: month, year: year)
    }
    try out.write(toFile: ProcessInfo.processInfo.environment["BREVIARIUM_AMBROSIAN_REPORT"]!, atomically: true, encoding: .utf8)
}
