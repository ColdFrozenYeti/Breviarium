import Testing
@testable import BreviariumKit

// Beta 6 (B6-M1): directions that were shown in white. A 9 October 2026 scan of every hour
// on nine dates, both rites, found four kinds (`docs/Beta_6_plan.md` §5).

private let start = InlineRubrics.start
private let end = InlineRubrics.end

@Test func lowerCaseFitReverentiaIsMarked() {
    // Psalm 110:9 and 112:2 (`Psalterium/Psalmorum`), and their English.
    #expect(InlineRubrics.marking("(fit reverentia) Sanctum, et terríbile nomen eius:")
        == "\(start)(fit reverentia)\(end) Sanctum, et terríbile nomen eius:")
    #expect(InlineRubrics.marking("(bow head) Blessed be the name of the Lord,")
        == "\(start)(bow head)\(end) Blessed be the name of the Lord,")
    // The capitalised forms still match, as before.
    #expect(InlineRubrics.marking("(Fit reverentia:) Benedicámus Patrem")
        == "\(start)(Fit reverentia:)\(end) Benedicámus Patrem")
    // Rubrics off: the direction goes, the verse stays.
    #expect(InlineRubrics.withoutRubrics(InlineRubrics.marking("iter fácite ei: (fit reverentia) Dóminus nomen illi."))
        == "iter fácite ei: Dóminus nomen illi.")
}

@Test func inlineSmallPrintIsMarked() {
    // The Te Deum's English writes its directions in DO's small print, without brackets
    // (`English/Psalterium/Common/Prayers.txt:143,154`).
    let units = HourAssembler.unitsFromLines(["/:bow head:/ Holy, Holy, Holy * Lord God of Sabaoth;"])
    let texts = units.flatMap { unit -> [String] in
        switch unit {
        case .prose(let text, _), .antiphon(let text, _), .rubric(let text, _): [text]
        case .versicleResponse(let v, let r, _, _): [v, r]
        case .verse(_, let first, let second, _, _): [first, second]
        default: []
        }
    }.joined(separator: " ")
    #expect(texts.contains("\(start)bow head\(end) Holy, Holy, Holy"))
    #expect(!texts.contains("/:"))
}

@Test func aHymnsRubricLineIsMarked() {
    // Corpus Christi's *Pange lingua* (`Tempora/Pent01-4.txt:53`): the line before
    // *Tantum ergo* is a direction, not a stanza.
    let stanzas = HourAssembler.hymnStanzas("Sola fides súfficit.\n_\n!Sequens stropha, si coram Sanctissimo exposito Officium persolvatur, dicitur flexis genibus.\n_\nTantum ergo Sacraméntum")
    #expect(stanzas.contains("\(start)Sequens stropha, si coram Sanctissimo exposito Officium persolvatur, dicitur flexis genibus.\(end)"))
    #expect(stanzas.contains { $0.hasPrefix("Tantum ergo") })
}

@Test func aHymnsSmallPrintDirectionIsMarked() {
    // *Ave maris stella* (`Commune/C11.txt:27`) opens with a small-print direction, and
    // the Dominican *Christe qui lux es* (`Psalterium/Special/Minor Special.txt:760`) has
    // one inside a stanza. The year-wide scan found both in white.
    let ave = HourAssembler.hymnStanzas("/:Prima stropha sequentis hymni dicitur flexis genibus.:/\nv. Ave maris stella,\nDei Mater alma,")
    #expect(ave.first == "\(start)Prima stropha sequentis hymni dicitur flexis genibus.\(end)\nAve maris stella,\nDei Mater alma,")
    #expect(InlineRubrics.withoutRubrics(ave[0]) == "Ave maris stella,\nDei Mater alma,")
    let defensor = HourAssembler.hymnStanzas("Gubérna tuos fámulos,\n/:Ad hunc Vers. genuflectatur:/\nQuos Sánguine mercátus es.")
    #expect(defensor.first == "Gubérna tuos fámulos,\n\(start)Ad hunc Vers. genuflectatur\(end)\nQuos Sánguine mercátus es.")
    #expect(InlineRubrics.withoutRubrics(defensor[0]) == "Gubérna tuos fámulos,\nQuos Sánguine mercátus es.")
}

@Test func aGospelsGenuflectionIsMarked() {
    // The Dominican Prima reads the day's Gospel from the Missal (`missa/Latin/Sancti/
    // 01-06.txt`, Pentecost week, Christmas's third Mass); the year-wide scan found it white.
    #expect(InlineRubrics.marking("cum María Matre eius, (hic genuflectitur) et procidéntes")
        == "cum María Matre eius, \(start)(hic genuflectitur)\(end) et procidéntes")
    #expect(InlineRubrics.marking("(Hic genuflectitur) Veni, Sancte Spíritus")
        == "\(start)(Hic genuflectitur)\(end) Veni, Sancte Spíritus")
}
