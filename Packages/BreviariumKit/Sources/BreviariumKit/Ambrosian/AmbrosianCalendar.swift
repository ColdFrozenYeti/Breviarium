/// Beta 6: what Ambrosian Compline needs from the Ambrosian calendar
/// (`docs/rubrics-ambrosian-compline.md` §3): the part of the breviary a date falls in,
/// whether its Compline takes the festal form, its Marian antiphon, and its title block.
///
/// Every rule is from the 1957 *Breviarium Ambrosianum* as Church of Ambrose's sources
/// give it: the four Compline parts' own rubrics, the *Kalendarium Ambrosianum*, and the
/// *Tabula paschalis perpetua*. Where they are silent, the choice is marked `Unsourced`
/// in a comment and listed for the user's check (`docs/Beta_6_plan.md` §8). Nothing is
/// taken from the Roman calendar.
public struct AmbrosianCalendar: Sendable {
    /// The *Kalendarium*, by `MM-DD`.
    public let entries: [String: AmbrosianCalendarEntry]

    public init(entries: [AmbrosianCalendarEntry]) {
        self.entries = Dictionary(entries.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: The movable feasts

    /// The *Tabula paschalis perpetua*'s columns for a year, as days of the year. Easter
    /// is the Gregorian one (the Ambrosian Easter is the same); the rest follow from it
    /// as the *Tabula* lists them, and Advent by its own rule, *Adventus Domini inchoatur
    /// Dominica prima post Festum sancti Martini* (the first Sunday after 11 November).
    public struct MovableFeasts: Equatable, Sendable {
        public var septuagesima: Int
        public var quadragesima: Int
        public var easter: Int
        public var ascension: Int
        public var pentecost: Int
        public var corpusChristi: Int
        public var advent: Int
    }

    public static func movableFeasts(year: Int) -> MovableFeasts {
        let easter = Computus.easter(year: year)
        let e = Computus.dayOfYear(day: easter.day, month: easter.month, year: year)
        let martin = Computus.dayOfYear(day: 11, month: 11, year: year)
        let martinWeekday = Computus.dayOfWeek(day: 11, month: 11, year: year)
        return MovableFeasts(
            septuagesima: e - 63, quadragesima: e - 42, easter: e, ascension: e + 39, pentecost: e + 49,
            corpusChristi: e + 60, advent: martin + (7 - martinWeekday)
        )
    }

    // MARK: The part of the breviary

    /// The four volumes of the 1957 breviary, each with its own Compline booklet.
    public enum Part: String, CaseIterable, Sendable {
        case hiemalisPrima = "HI", hiemalisSecunda = "HII", aestivaPrima = "AI", aestivaSecunda = "AII"
    }

    /// The part a date's Compline is taken from. Compline takes its own date's part,
    /// never the next day's (the user, 9 October 2026): the Saturday before Lent is still
    /// *hiemalis prima*, and Holy Saturday still Lent.
    /// - *Hiemalis secunda*: the 1st Sunday of Lent to Holy Saturday.
    /// - *Æstiva prima*: Easter to the octave of Pentecost (its rubric: *a Resurrectione
    ///   … usque ad Octavam Pentecostes inclusive*), that is to the Saturday before the
    ///   Sunday after Pentecost.
    /// - *Æstiva secunda* from the 1st Sunday after Pentecost to the Saturday before the
    ///   1st Sunday of October; *hiemalis prima* the rest of the year. These two print the
    ///   same Compline, so the boundary between them changes nothing on the page.
    public static func part(day: Int, month: Int, year: Int) -> Part {
        let d = Computus.dayOfYear(day: day, month: month, year: year)
        let m = movableFeasts(year: year)
        if d >= m.quadragesima, d < m.easter { return .hiemalisSecunda }
        if d >= m.easter, d < m.pentecost + 7 { return .aestivaPrima }
        let october1 = Computus.dayOfYear(day: 1, month: 10, year: year)
        let firstSundayOfOctober = october1 + (7 - Computus.dayOfWeek(day: 1, month: 10, year: year)) % 7
        if d >= m.pentecost + 7, d < firstSundayOfOctober { return .aestivaSecunda }
        return .hiemalisPrima
    }

    // MARK: The Marian antiphon

    public enum MarianAntiphon: String, Sendable {
        case aveRegina = "ant-averegina", alma = "ant-alma", salve = "ant-salve"
        case reginaCaeli = "ant-reginacaeli", inviolata = "ant-inviolata"
    }

    /// From the parts' own rubrics: *Ave, Regina cælorum* from the Nativity of Our Lady to
    /// Christmas exclusive; *Alma Redemptoris* from Christmas to Lent exclusive; *Salve,
    /// Regina* in Lent, *quæ omittitur Fer. VI in Parasceve* (`nil` on Good Friday);
    /// *Regina cæli* from Easter to Pentecost inclusive; *Inviolata* from the 1st Sunday
    /// after Pentecost to the Nativity of Our Lady exclusive.
    ///
    /// Unsourced: the Monday to Saturday after Pentecost, which neither *Regina cæli*
    /// (*usque ad Pentecost. inclusive*) nor *Inviolata* (*a Dominica I post
    /// Pentecostem*) names, take *Regina cæli*, the only antiphon *æstiva prima* prints.
    public static func marianAntiphon(day: Int, month: Int, year: Int) -> MarianAntiphon? {
        let d = Computus.dayOfYear(day: day, month: month, year: year)
        let m = movableFeasts(year: year)
        if d == m.easter - 2 { return nil }
        if d >= m.quadragesima, d < m.easter { return .salve }
        if d >= m.easter, d < m.pentecost + 7 { return .reginaCaeli }
        let september8 = Computus.dayOfYear(day: 8, month: 9, year: year)
        let december25 = Computus.dayOfYear(day: 25, month: 12, year: year)
        if d >= september8, d < december25 { return .aveRegina }
        if d >= december25 || d < m.quadragesima { return .alma }
        return .inviolata
    }

    // MARK: The festal form

    /// Our Lady's feasts in the *Kalendarium* (*festis diebus B. M. V.*): the feasts *of*
    /// Our Lady, not St Anne's, St Joachim's or St Joseph's, whose titles also name her.
    static let feastsOfOurLady: Set<String> = [
        "02-02", "03-25", "07-02", "07-16", "08-05", "08-15", "09-08", "09-12", "09-15", "11-21", "12-08",
    ]

    /// Whether Compline goes from the *Capitulum* straight to *Dominus vobiscum* and the
    /// collect *Illumina*, without the kneeling *preces*. The parts' own rubrics:
    /// - *Hiemalis* and *æstiva secunda*: Solemnities of the Lord, octaves, Sundays, Our
    ///   Lady's feasts, the Nativity of St John Baptist, Ss Peter and Paul (and pontifical
    ///   and patronal days, which a private recitation doesn't keep).
    /// - Lent (*hiemalis secunda*): Sundays, St Joseph and the Annunciation.
    /// - *Æstiva prima*: every day, except the *Triduum Litaniarum*.
    public func isFestal(day: Int, month: Int, year: Int) -> Bool {
        let d = Computus.dayOfYear(day: day, month: month, year: year)
        let m = Self.movableFeasts(year: year)
        let sunday = Computus.dayOfWeek(day: day, month: month, year: year) == 0
        let key = String(format: "%02d-%02d", month, day)
        switch Self.part(day: day, month: month, year: year) {
        case .hiemalisSecunda:
            // Unsourced: in Holy Week St Joseph and the Annunciation are not kept (the
            // ferial form), as their feasts give way to the week.
            let holyWeek = d >= m.easter - 7
            return sunday || (!holyWeek && (key == "03-19" || key == "03-25"))
        case .aestivaPrima:
            return !Self.isTriduumLitaniarum(dayOfYear: d, movable: m)
        case .hiemalisPrima, .aestivaSecunda:
            if sunday { return true }
            // Unsourced: Corpus Christi is a Solemnity of the Lord, though the
            // *Kalendarium* (a fixed calendar) can't list it.
            if d == m.corpusChristi { return true }
            // Octaves: Christmas's (26-31 December, each *Commem. Octavæ*) and 1 January,
            // and the Epiphany's, which the *Kalendarium* ranks *Sol. Dom.*
            if (month == 12 && day >= 25) || key == "01-01" { return true }
            if Self.feastsOfOurLady.contains(key) || key == "06-24" || key == "06-29" { return true }
            return entries[key].map { $0.rank.contains("Dom.") } ?? false
        }
    }

    /// Unsourced (to be checked): the *Triduum Litaniarum*, the Ambrosian Rogation days,
    /// are taken to be the Monday to Wednesday after the Sunday after the Ascension.
    static func isTriduumLitaniarum(dayOfYear d: Int, movable m: MovableFeasts) -> Bool {
        d >= m.ascension + 4 && d <= m.ascension + 6
    }

    // MARK: The title block

    static let weekdays = ["Dominica", "Feria II", "Feria III", "Feria IV", "Feria V", "Feria VI", "Sabbato"]

    /// The day's name: a movable feast of the *Tabula* by its column heading; else the
    /// *Kalendarium*'s feast, with its rank and commemoration (none on a weekday of Lent,
    /// which the calendar leaves empty but for St Joseph and the Annunciation); else the
    /// weekday. On a Sunday the *Kalendarium*'s feast is named only if it is a Solemnity
    /// of the Lord or of the I or II class (unsourced: the Ambrosian precedence of
    /// Sundays isn't in these sources), otherwise "Dominica".
    public func titleBlock(day: Int, month: Int, year: Int) -> TitleBlock {
        let d = Computus.dayOfYear(day: day, month: month, year: year)
        let m = Self.movableFeasts(year: year)
        let weekday = Computus.dayOfWeek(day: day, month: month, year: year)
        let movable: [Int: String] = [
            m.septuagesima: "Dominica in Septuagesima", m.quadragesima: "Dominica I Quadragesimæ", m.easter: "Pascha",
            m.ascension: "Ascensio Domini", m.pentecost: "Pentecostes", m.corpusChristi: "Corpus Christi",
            m.advent: "Dominica I Adventus",
        ]
        if let name = movable[d] { return TitleBlock(classisLine: nil, nameLine: name, commemorationLine: nil) }
        let key = String(format: "%02d-%02d", month, day)
        let lent = Self.part(day: day, month: month, year: year) == .hiemalisSecunda
        if let entry = entries[key], !entry.feast.isEmpty, !lent || key == "03-19" || key == "03-25" {
            let high = entry.rank.contains("Dom.") || entry.rank.contains(" cl.")
            if weekday != 0 || high {
                let commemoration = entry.note.hasPrefix("Comm") ? entry.note.replacingOccurrences(of: " Vigilia seq.", with: "") : nil
                return TitleBlock(classisLine: entry.rank.isEmpty ? nil : entry.rank, nameLine: entry.feast, commemorationLine: commemoration)
            }
        }
        return TitleBlock(classisLine: nil, nameLine: Self.weekdays[weekday], commemorationLine: nil)
    }
}
