import Foundation

/// One day of the *Kalendarium* (1.4, `docs/1.4_plan.md`): the weekday, the class, the
/// day's name and its colour, as one row of the month.
///
/// No calendar logic of its own: every field is copied from what the engine already
/// gives -- `LiturgicalCalendarEngine.day(day:month:year:)`, the day's own office as Lauds
/// and the calendar's colour dots have it, for the Roman and Dominican rites, and
/// `AmbrosianCalendar.titleBlock` and `.color` for the Ambrosian -- so a row always agrees
/// with the office it opens. The name has no monthday suffix (*I. Novembris*) or line
/// below it: a row is one name.
public struct KalendariumEntry: Equatable, Sendable {
    public var day: Int
    public var month: Int
    public var year: Int
    /// 0 = Sunday ... 6 = Saturday (`Computus.dayOfWeek`).
    public var weekday: Int
    /// The class as a Roman numeral (`"III"` from `"III. classis"`), or, where the title
    /// block's rank line isn't a class (the Ambrosian ranks), that line itself; `nil` for
    /// a feria, which has no rank line.
    public var classis: String?
    /// The day's title block: the rank line and the name (no line below it).
    public var titleBlock: TitleBlock
    /// The name in an Ordo's abbreviations, for a row too narrow for the whole name.
    public var shortName: String { Kalendarium.shortName(titleBlock.nameLine) }
    public var color: CalendarColor?

    public init(day: Int, month: Int, year: Int, weekday: Int, classis: String?, titleBlock: TitleBlock, color: CalendarColor?) {
        self.day = day
        self.month = month
        self.year = year
        self.weekday = weekday
        self.classis = classis
        self.titleBlock = titleBlock
        self.color = color
    }
}

public enum Kalendarium {
    /// Every day of a month under a rite read from Divinum Officium (Roman or Dominican).
    public static func month(
        year: Int, month: Int, rite: Rite, corpus: OfficeCorpus, sanctoralCalendar: SanctoralCalendar
    ) -> [KalendariumEntry] {
        days(year: year, month: month).compactMap { day, m, y in
            let context = ConditionalContextBuilder.build(
                day: day, month: m, year: y, ad: "Laudes", rubrica: rite.doVersion, corpus: corpus, sanctoralCalendar: sanctoralCalendar
            )
            let engine = LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: sanctoralCalendar)
            guard let office = engine.day(day: day, month: m, year: y) else { return nil }
            return KalendariumEntry(
                day: day, month: m, year: y, weekday: Computus.dayOfWeek(day: day, month: m, year: y),
                classis: classis(of: office.titleBlock.classisLine), titleBlock: office.titleBlock,
                color: CalendarColor(color: office.color, officePath: office.occurrence.winningPath)
            )
        }
    }

    /// Every day of a month in the Ambrosian calendar (*Kalendarium Ambrosianum*).
    public static func month(year: Int, month: Int, ambrosian calendar: AmbrosianCalendar) -> [KalendariumEntry] {
        days(year: year, month: month).map { day, m, y in
            var titleBlock = calendar.titleBlock(day: day, month: m, year: y)
            titleBlock.commemorationLine = nil
            return KalendariumEntry(
                day: day, month: m, year: y, weekday: Computus.dayOfWeek(day: day, month: m, year: y),
                classis: classis(of: titleBlock.classisLine), titleBlock: titleBlock,
                color: calendar.color(day: day, month: m, year: y)
            )
        }
    }

    /// A name in the abbreviations of a printed Ordo (decided 2026-11-12: "names that are
    /// too long should be shortened, and if impossible, cut off", on one line). The row
    /// shows the whole name when it fits on its line, this one when it doesn't, and cuts
    /// off what is still too long. Spelling only, no liturgy: *Feria Quinta infra
    /// Hebdomadam XXIII post Octavam Pentecostes* becomes *Feria V hebd. XXIII post Oct. Pent.*
    public static func shortName(_ name: String) -> String {
        var result = name
        for (pattern, replacement) in abbreviations {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }
        return result.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// In order: the longer phrases before the words inside them.
    private static let abbreviations: [(String, String)] = [
        (#"\bFeria Secunda\b"#, "Feria II"), (#"\bFeria Tertia\b"#, "Feria III"), (#"\bFeria Quarta\b"#, "Feria IV"),
        (#"\bFeria Quinta\b"#, "Feria V"), (#"\bFeria Sexta\b"#, "Feria VI"),
        (#"\binfra Hebdomadam\b"#, "hebd."), (#"\bHebdomadam\b"#, "hebd."), (#"\bHebdomadæ\b"#, "hebd."),
        (#"\bpost Octavam Pentecostes\b"#, "post Oct. Pent."), (#"\bpost Pentecosten\b"#, "post Pent."),
        (#"\bpost Octavam Paschæ\b"#, "post Oct. Paschæ"), (#"\bpost Epiphaniam\b"#, "post Epiph."),
        (#"\binfra Octavam\b"#, "infra Oct."), (#"\bOctavam\b"#, "Oct."),
        (#"\bQuattuor Temporum\b"#, "Q. T."),
        (#"\bBeatæ Mariæ Virginis\b"#, "B.M.V."),
        (#"\bDomini Nostri [IJ]esu Christi\b"#, "D.N.I.C."),
        (#"\bSanctissim(i|æ)\b"#, "Ss."),
        (#"\bEcclesiæ Doctoris\b"#, "Eccl. Doct."), (#"\bEcclesiæ Doctorum\b"#, "Eccl. Doct."),
        (#"\bEpiscopi\b"#, "Ep."), (#"\bEpiscoporum\b"#, "Epp."),
        (#"\bConfessoris\b"#, "Conf."), (#"\bConfessorum\b"#, "Conff."),
        (#"\bVirginis\b"#, "Virg."), (#"\bVirginum\b"#, "Virg."),
        (#"\bMartyris\b"#, "Mart."), (#"\bMartyrum\b"#, "Mm."),
        (#"\bAbbatis\b"#, "Abb."), (#"\bViduæ\b"#, "Vid."), (#"\bApostoli\b"#, "Ap."), (#"\bApostolorum\b"#, "App."),
        (#"\bEvangelistæ\b"#, "Evang."),
    ]

    /// `"III. classis"` as `"III"`; any other rank line as it is.
    static func classis(of line: String?) -> String? {
        guard let line, !line.isEmpty else { return nil }
        if line.hasSuffix(". classis") { return String(line.dropLast(". classis".count)) }
        return line
    }

    private static func days(year: Int, month: Int) -> [(Int, Int, Int)] {
        var result: [(Int, Int, Int)] = []
        var (day, m, y) = (1, month, year)
        while m == month, y == year {
            result.append((day, m, y))
            (day, m, y) = Computus.addDays(1, day: day, month: m, year: y)
        }
        return result
    }
}
