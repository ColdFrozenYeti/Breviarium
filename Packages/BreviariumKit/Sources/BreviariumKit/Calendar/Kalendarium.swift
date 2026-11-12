/// One day of the *Kalendarium* (1.4, `docs/1.4_plan.md`): the weekday, the class, the
/// day's name and its colour, as one row of the month.
///
/// No calendar logic of its own: every field is copied from what the engine already
/// gives the hours -- `LiturgicalCalendarEngine.day(for: .laudes, …)`, the day as Lauds
/// shows it, for the Roman and Dominican rites, and `AmbrosianCalendar.titleBlock` and
/// `.color` for the Ambrosian -- so a row always agrees with the office it opens.
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
    /// The title block Lauds shows: the rank line, the name, and the line below it.
    public var titleBlock: TitleBlock
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
            guard let office = engine.day(for: .laudes, day: day, month: m, year: y) else { return nil }
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
            let titleBlock = calendar.titleBlock(day: day, month: m, year: y)
            return KalendariumEntry(
                day: day, month: m, year: y, weekday: Computus.dayOfWeek(day: day, month: m, year: y),
                classis: classis(of: titleBlock.classisLine), titleBlock: titleBlock,
                color: calendar.color(day: day, month: m, year: y)
            )
        }
    }

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
