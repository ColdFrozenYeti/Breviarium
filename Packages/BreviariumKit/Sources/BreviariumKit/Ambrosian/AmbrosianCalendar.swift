/// Beta 6: what Ambrosian Compline needs from the Ambrosian calendar
/// (`docs/rubrics-ambrosian-compline.md` §3): the part of the breviary a date falls in,
/// the office it keeps, whether its Compline takes the festal form, its Marian antiphon,
/// its title block and its colour.
///
/// Every rule is from Church of Ambrose's sources: the four Compline parts' own rubrics
/// (the 1957 breviary), and the 1954 *Missale Ambrosianum*'s *Kalendarium*, *Tabula
/// paschalis perpetua*, *Series Missarum* and *Rubricæ generales* (whose first rule is
/// that the Mass agrees with the day's Office, so they give the Office's occurrence
/// too). Where they are silent, the choice is marked `Unsourced` in a comment and listed
/// for the user's check (`docs/ambrosian-compline-checks.md`). Nothing is taken from the
/// Roman calendar.
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

    // MARK: The office of the day

    /// Our Lady's feasts in the *Kalendarium* (*festis diebus B. M. V.*): the feasts *of*
    /// Our Lady, not St Anne's, St Joachim's or St Joseph's, whose titles also name her.
    static let feastsOfOurLady: Set<String> = [
        "02-02", "03-25", "07-02", "07-16", "08-05", "08-15", "09-08", "09-12", "09-15", "11-21", "12-08",
    ]

    static let weekdays = ["Dominica", "Feria II", "Feria III", "Feria IV", "Feria V", "Feria VI", "Sabbato"]

    /// The day's office: what the Missal's *Rubricæ generales* (§§ 2–3) and the
    /// *Kalendarium* make of the date. It names the day, chooses Compline's form and the
    /// colour.
    public func office(day: Int, month: Int, year: Int) -> AmbrosianOffice {
        let d = Computus.dayOfYear(day: day, month: month, year: year)
        let weekday = Computus.dayOfWeek(day: day, month: month, year: year)
        let temporal = Self.temporal(dayOfYear: d, weekday: weekday, day: day, month: month, year: year)
        if temporal.excludesSaints {
            return AmbrosianOffice(kind: temporal.kind, name: temporal.name, temporalName: temporal.name, commemoration: temporal.commemoration)
        }
        let key = Self.key(day, month)
        if weekday == 0 {
            // § 2: *De Dominica Officium et Missa numquam prætermittuntur*, but for a
            // *Solemnitas Domini, non tamen Octava*, which takes the Sunday *cum
            // commemoratione Dominicæ, quæ omittitur in Solemnitatibus Domini primæ classis*.
            // And St Joseph on a Sunday of Lent, which the rubric on violet (§ 42) keeps:
            // *in Dominicis Quadragesimæ (nisi Festum S. Ioseph … occurrerit)*.
            if let entry = keptEntry(key, dayOfYear: d, year: year), entry.isSolemnityOfTheLord && !entry.isOctaveDay || key == "03-19" {
                let commemoration = entry.precedence == 10 ? nil : "Commem. \(temporal.name)"
                return AmbrosianOffice(kind: .feast, name: entry.feast, temporalName: temporal.name, feast: entry, commemoration: commemoration)
            }
            return AmbrosianOffice(kind: .sunday, name: temporal.name, temporalName: temporal.name, commemoration: temporal.commemoration)
        }
        // A movable feast that is not a privileged day (the Sacred Heart, the Holy
        // Family) is the day's office. Unsourced: a saint of the Kalendarium on it gives
        // way to it, as a commemoration.
        if temporal.kind == .feast {
            let own = keptEntry(key, dayOfYear: d, year: year).map { "Commem. \($0.feast)" }
            return AmbrosianOffice(kind: .feast, name: temporal.name, temporalName: temporal.name, commemoration: own)
        }
        // § 2: a saint on a Sunday *in feriam secundam immediate sequentem transferuntur
        // officio paris ritus non impeditam*: it takes the Monday unless the Monday has a
        // feast of the same rank or higher (then it is impeded, and not said). Unsourced:
        // a lower feast on the Monday is commemorated.
        var candidates: [(entry: AmbrosianCalendarEntry, transferred: Bool)] = []
        if let own = keptEntry(key, dayOfYear: d, year: year) { candidates.append((own, false)) }
        if let moved = movedHere(day: day, month: month, year: year) { candidates.append((moved, true)) }
        if let best = candidates.max(by: { a, b in
            a.entry.precedence != b.entry.precedence ? a.entry.precedence < b.entry.precedence : a.transferred && !b.transferred
        }) {
            let other = candidates.first { $0.entry.date != best.entry.date }
            var lines: [String] = []
            if let note = Self.commemoration(in: best.entry) { lines.append(note) }
            if let other, !other.transferred {
                lines.append(other.entry.feast.hasPrefix("Commem.") ? other.entry.feast : "Commem. \(other.entry.feast)")
            }
            if let extra = temporal.commemoration { lines.append(extra) }
            return AmbrosianOffice(
                kind: .feast, name: best.entry.feast, temporalName: temporal.name, feast: best.entry,
                commemoration: lines.isEmpty ? nil : lines.joined(separator: "; "), transferred: best.transferred
            )
        }
        if entries[key].map({ $0.feast.isEmpty && $0.note.hasPrefix("Vigilia seq.") }) == true {
            return AmbrosianOffice(kind: .vigil, name: temporal.name, temporalName: temporal.name, commemoration: temporal.commemoration)
        }
        return AmbrosianOffice(kind: temporal.kind, name: temporal.name, temporalName: temporal.name, commemoration: temporal.commemoration)
    }

    /// The *Kalendarium*'s feast on this date, if it is kept there: not in Lent but for
    /// St Joseph and the Annunciation (the *Kalendarium* lists no other saint in March,
    /// and moves the Chair of St Peter out of Lent, below), and never the Deposition of
    /// St Ambrose, which its own note puts on Thursday of Easter week.
    private func keptEntry(_ key: String, dayOfYear d: Int, year: Int) -> AmbrosianCalendarEntry? {
        guard let entry = entries[key], !entry.feast.isEmpty, !entry.feast.hasPrefix("Vigilia"), key != "04-04" else { return nil }
        let m = Self.movableFeasts(year: year)
        if d >= m.quadragesima, d < m.easter, key != "03-19", key != "03-25" { return nil }
        return entry
    }

    /// A feast moved to this date: from the Sunday before (§ 2), or the Chair of St Peter
    /// at Antioch, which the *Kalendarium* moves to 4 February when 22 February is in Lent
    /// (*Si Festum incidat in Quadragesimam, celebratur die 4 huius*).
    private func movedHere(day: Int, month: Int, year: Int) -> AmbrosianCalendarEntry? {
        if month == 2, day == 4 {
            let m = Self.movableFeasts(year: year)
            let d22 = Computus.dayOfYear(day: 22, month: 2, year: year)
            if d22 >= m.quadragesima, let chair = entries["02-22"] { return chair }
        }
        guard Computus.dayOfWeek(day: day, month: month, year: year) == 1 else { return nil }
        let y = Computus.addDays(-1, day: day, month: month, year: year)
        let dy = Computus.dayOfYear(day: y.day, month: y.month, year: y.year)
        let sunday = Self.temporal(dayOfYear: dy, weekday: 0, day: y.day, month: y.month, year: y.year)
        guard let entry = keptEntry(Self.key(y.day, y.month), dayOfYear: dy, year: y.year) else { return nil }
        let keptOnSunday = !sunday.excludesSaints && (entry.isSolemnityOfTheLord && !entry.isOctaveDay || entry.date == "03-19")
        return keptOnSunday ? nil : entry
    }

    private static func commemoration(in entry: AmbrosianCalendarEntry) -> String? {
        guard entry.note.hasPrefix("Comm") else { return nil }
        return entry.note.replacingOccurrences(of: " Vigilia seq.", with: "")
    }

    static func key(_ day: Int, _ month: Int) -> String {
        (month < 10 ? "0" : "") + "\(month)-" + (day < 10 ? "0" : "") + "\(day)"
    }

    // MARK: The temporal cycle

    struct Temporal {
        var name: String
        var kind: AmbrosianOffice.Kind
        /// A privileged day (§ 3: *numquam fit de Sancto*) or a solemnity of the Lord of
        /// the movable cycle: no saint is kept.
        var excludesSaints: Bool
        var commemoration: String? = nil
    }

    static let roman = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI"]

    /// The day of the *Proprium de Tempore*, named as the Missal's *Series Missarum*
    /// (pp. X–XI) names its Masses.
    static func temporal(dayOfYear d: Int, weekday: Int, day: Int, month: Int, year: Int) -> Temporal {
        let m = movableFeasts(year: year)
        let name = weekdays[weekday]
        let december24 = Computus.dayOfYear(day: 24, month: 12, year: year)
        let january6 = Computus.dayOfYear(day: 6, month: 1, year: year)
        func privileged(_ name: String, _ kind: AmbrosianOffice.Kind = .privilegedFeria) -> Temporal { Temporal(name: name, kind: kind, excludesSaints: true) }

        // The movable solemnities and the days the rubrics privilege (§ 3).
        switch d - m.easter {
        case 0: return privileged("Pascha", .solemnity)
        case -7: return privileged("Dominica Palmarum", .sunday)
        case -6: return privileged("Feria II in Authentica")
        case -5: return privileged("Feria III in Authentica")
        case -4: return privileged("Feria IV in Authentica")
        case -3: return privileged("Feria V in Cœna Domini")
        case -2: return privileged("Feria VI in Parasceve")
        case -1: return privileged("Sabbato Sancto")
        case -8: return privileged("Sabbato in traditione Symboli")
        // Unsourced: the days of Easter week, each with its own Masses *pro Baptizatis* and
        // *de Octava*, are taken to exclude the saints, as the Roman octave did.
        case 1...6: return privileged("\(name) in Albis", .octaveDay)
        case 7: return Temporal(name: "Dominica I post Pascha, in Albis depositis", kind: .sunday, excludesSaints: false)
        case 39: return privileged("Ascensio Domini", .solemnity)
        case 38: return Temporal(name: "Vigilia Ascensionis Domini", kind: .vigil, excludesSaints: false)
        case 43: return privileged("Dies primus in Litaniis")
        case 44: return privileged("Dies secundus in Litaniis")
        case 45: return privileged("Dies tertius in Litaniis")
        case 48: return privileged("Vigilia Pentecostes", .vigil)
        case 49: return privileged("Dominica Pentecostes", .solemnity)
        case 56: return privileged("Dominica I post Pentecosten: SS. Trinitatis", .sunday)
        case 60: return privileged("Solemnitas SS. Corporis Christi", .solemnity)
        // *Feria VI post Oct. SS. Corporis Domini, in Festo SS. Cordis Iesu*.
        case 68: return Temporal(name: "Festum SS. Cordis Iesu", kind: .feast, excludesSaints: false)
        default: break
        }
        if d == december24 { return privileged("Vigilia Nativitatis Domini", .vigil) }
        if d == january6 - 1, weekday != 0 { return privileged("Vigilia Epiphaniæ", .vigil) }

        // The Holy Family: *Feria II infra Hebd. Dom. III post Epiphaniam*.
        if weekday == 1, let third = sundayAfterEpiphany(3, year: year), d == third + 1, third < m.septuagesima {
            return Temporal(name: "Festum S. Familiæ Iesu, Mariæ, Ioseph", kind: .feast, excludesSaints: false)
        }
        if weekday == 0 { return Temporal(name: sundayName(dayOfYear: d, year: year), kind: .sunday, excludesSaints: false) }

        // Lent: the ferias *Hebd.* I to V (*Series Missarum*).
        if d > m.quadragesima, d < m.easter - 8 {
            return Temporal(name: "\(name) hebdomadæ \(roman[(d - m.quadragesima) / 7 + 1]) Quadragesimæ", kind: .feria, excludesSaints: false)
        }
        // Advent: the Friday and Saturday of its fourth and fifth weeks are privileged.
        if d > m.advent, d < december24 {
            let week = (d - m.advent) / 7 + 1
            if (week == 4 || week == 5) && weekday >= 5 { return privileged(name) }
        }
        // Unsourced: the weekdays after Pentecost to its octave, and those of Corpus
        // Christi's octave (the rubric on red, § 40, gives both octaves), are named as
        // such; they don't exclude the saints, as § 3 doesn't privilege them.
        if d > m.pentecost, d < m.pentecost + 7 {
            return Temporal(name: "\(name) infra Octavam Pentecostes", kind: .octaveDay, excludesSaints: false)
        }
        if d > m.corpusChristi, d <= m.corpusChristi + 7 {
            return Temporal(name: "\(name) infra Octavam SS. Corporis Christi", kind: .octaveDay, excludesSaints: false)
        }
        // The Deposition of St Ambrose, *cuius commem. semper fit Feria V in Albis*, is
        // added in `office`; this keeps its note with the day.
        return Temporal(name: name, kind: .feria, excludesSaints: false)
    }

    /// The *n*th Sunday after the Epiphany, as a day of the year.
    static func sundayAfterEpiphany(_ n: Int, year: Int) -> Int? {
        let january6 = Computus.dayOfYear(day: 6, month: 1, year: year)
        let first = january6 + (7 - Computus.dayOfWeek(day: 6, month: 1, year: year))
        return first + 7 * (n - 1)
    }

    /// A Sunday's name (*Series Missarum*).
    static func sundayName(dayOfYear d: Int, year: Int) -> String {
        let m = movableFeasts(year: year)
        let december24 = Computus.dayOfYear(day: 24, month: 12, year: year)
        let january6 = Computus.dayOfYear(day: 6, month: 1, year: year)
        if d >= m.advent, d < december24 { return "Dominica \(roman[(d - m.advent) / 7 + 1]) Adventus" }
        // Unsourced: a Sunday from 2 to 5 January is named as the one after Christmas.
        if d > december24 || d < january6 { return "Dominica post Nativitatem Domini" }
        if d < m.septuagesima {
            // *Dominica VI post Epiphaniam: Missa quæ semper celebratur Dominica
            // Septuagesimam proxime præcedente*.
            if d == m.septuagesima - 7 { return "Dominica VI post Epiphaniam" }
            return "Dominica \(roman[(d - january6 - 1) / 7 + 1]) post Epiphaniam"
        }
        switch d - m.septuagesima {
        case 0: return "Dominica in Septuagesima"
        case 7: return "Dominica in Sexagesima"
        case 14: return "Dominica in Quinquagesima"
        case 21: return "Dominica in Quadragesima"
        case 28: return "Dominica II Quadragesimæ: de Samaritana"
        case 35: return "Dominica III Quadragesimæ: de Abraham"
        case 42: return "Dominica IV Quadragesimæ: de Cæco"
        case 49: return "Dominica V Quadragesimæ: de Lazaro"
        default: break
        }
        if d > m.easter, d < m.ascension { return "Dominica \(roman[(d - m.easter) / 7]) post Pascha" }
        if d > m.ascension, d < m.pentecost { return "Dominica post Ascensionem" }
        let august29 = Computus.dayOfYear(day: 29, month: 8, year: year)
        let october1 = Computus.dayOfYear(day: 1, month: 10, year: year)
        let firstOfOctober = october1 + (7 - Computus.dayOfWeek(day: 1, month: 10, year: year)) % 7
        if d <= august29 { return "Dominica \(roman[(d - m.pentecost) / 7]) post Pentecosten" }
        if d < firstOfOctober { return "Dominica \(roman[(d - august29 - 1) / 7 + 1]) post Decollationem" }
        switch d - firstOfOctober {
        case 0: return "Dominica I Octobris"
        case 7: return "Dominica II Octobris"
        case 14: return "Dominica III Octobris: in Dedicatione Ecclesiæ Maioris"
        default: break
        }
        let october31 = Computus.dayOfYear(day: 31, month: 10, year: year)
        if d > october31 - 7, d <= october31 { return "Dominica ultima Octobris: in Festo D. N. Iesu Christi Regis" }
        // The Sundays after the Dedication are counted with Christ the King's among them:
        // the *Series Missarum* has a third, which only that count can reach.
        return "Dominica \(roman[(d - firstOfOctober - 14) / 7]) post Dedicationem"
    }

    // MARK: The festal form

    /// Whether Compline goes from the *Capitulum* straight to *Dominus vobiscum* and the
    /// collect *Illumina*, without the kneeling *preces*. The parts' own rubrics:
    /// - *Hiemalis* and *æstiva secunda*: Solemnities of the Lord, octaves, Sundays, Our
    ///   Lady's feasts, the Nativity of St John Baptist, Ss Peter and Paul (and pontifical
    ///   and patronal days, which a private recitation doesn't keep).
    /// - Lent (*hiemalis secunda*): Sundays, St Joseph and the Annunciation.
    /// - *Æstiva prima*: every day, except the *Triduum Litaniarum*.
    /// Applied to the office the day keeps (`office`): a feast moved to the Monday brings
    /// its form with it, and one a privileged day impedes doesn't.
    public func isFestal(day: Int, month: Int, year: Int) -> Bool {
        let d = Computus.dayOfYear(day: day, month: month, year: year)
        let m = Self.movableFeasts(year: year)
        let office = office(day: day, month: month, year: year)
        let feastKey = office.feast?.date
        switch Self.part(day: day, month: month, year: year) {
        case .hiemalisSecunda:
            return office.kind == .sunday || feastKey == "03-19" || feastKey == "03-25"
        case .aestivaPrima:
            return !Self.isTriduumLitaniarum(dayOfYear: d, movable: m)
        case .hiemalisPrima, .aestivaSecunda:
            if office.kind == .sunday || office.kind == .solemnity || office.kind == .octaveDay { return true }
            if office.temporalName.contains("infra Octavam") { return true }
            // Octaves: Christmas's (26-31 December, each *Commem. Octavæ*) and the
            // Epiphany's, which the *Kalendarium* ranks *Sol. Dom.*
            if (month == 12 && day >= 25) || (month == 1 && day <= 13) { return true }
            guard let feast = office.feast else { return false }
            return feast.isSolemnityOfTheLord || Self.feastsOfOurLady.contains(feast.date) || feast.date == "06-24" || feast.date == "06-29"
        }
    }

    /// The *Triduum Litaniarum*, the Ambrosian Rogation days: the Monday to Wednesday
    /// after the Sunday after the Ascension (the *Series Missarum*: *Dominica post
    /// Ascensionem*, then *Die primo, secundo, tertio in Litaniis*).
    static func isTriduumLitaniarum(dayOfYear d: Int, movable m: MovableFeasts) -> Bool {
        d >= m.ascension + 4 && d <= m.ascension + 6
    }

    // MARK: The title block

    /// The day's name, with the feast's rank above it and its commemorations below.
    public func titleBlock(day: Int, month: Int, year: Int) -> TitleBlock {
        var office = office(day: day, month: month, year: year)
        // The Deposition of St Ambrose, *cuius commem. semper fit Feria V in Albis*.
        let m = Self.movableFeasts(year: year)
        if Computus.dayOfYear(day: day, month: month, year: year) == m.easter + 4, let ambrose = entries["04-04"] {
            office.commemoration = "Commem. \(ambrose.feast)"
        }
        let rank = office.feast.map(\.rank).flatMap { $0.isEmpty ? nil : $0 }
        return TitleBlock(classisLine: rank, nameLine: office.name, commemorationLine: office.commemoration)
    }

    // MARK: The colour

    /// The colour of the day's office, by the Missal's rubrics *De coloribus paramentorum*
    /// (§§ 38–43).
    public func color(day: Int, month: Int, year: Int) -> CalendarColor {
        let office = office(day: day, month: month, year: year)
        if let feast = office.feast, let color = Self.color(of: feast) { return color }
        // Christ the King, a Solemnity of the Lord without red (§ 39).
        if office.name.contains("Christi Regis") { return .white }
        if office.kind == .feast, office.feast == nil {
            // The Sacred Heart (red, § 40) and the Holy Family.
            return office.name.contains("Cordis") ? .red : .white
        }
        let d = Computus.dayOfYear(day: day, month: month, year: year)
        if office.kind == .vigil, d != Computus.dayOfYear(day: 24, month: 12, year: year), d != Computus.dayOfYear(day: 5, month: 1, year: year) {
            let m = Self.movableFeasts(year: year)
            // § 42: violet *in Vigiliis, exceptis tamen Vigiliis Nativitatis, Epiphaniæ,
            // Paschatis Resurrectionis, Ascensionis, et Pentecostes*.
            if d != m.ascension - 1, d != m.pentecost - 1 { return .violet }
        }
        return Self.seasonColor(dayOfYear: d, weekday: Computus.dayOfWeek(day: day, month: month, year: year), year: year)
    }

    /// The colour of the season (§§ 39–43).
    static func seasonColor(dayOfYear d: Int, weekday: Int, year: Int) -> CalendarColor {
        let m = movableFeasts(year: year)
        let december24 = Computus.dayOfYear(day: 24, month: 12, year: year)
        let january13 = Computus.dayOfYear(day: 13, month: 1, year: year)
        let october1 = Computus.dayOfYear(day: 1, month: 10, year: year)
        let dedication = october1 + (7 - Computus.dayOfWeek(day: 1, month: 10, year: year)) % 7 + 14
        if d >= m.advent, d < december24 {
            // Violet, *excepta Dominica sexta, in qua legitur Evangelium, Missus est*.
            return weekday == 0 && (d - m.advent) / 7 == 5 ? .white : .violet
        }
        if d >= december24 || d <= january13 { return .white }
        if d < m.septuagesima { return .green }
        if d < m.quadragesima { return .violet }
        // Red *a Sabbato in Traditione Symboli usque ad Benedictionem Cerei Sabbato Sancto
        // exclusive*; before it, violet Sundays and black ferias (§§ 42–43).
        if d < m.easter - 8 { return weekday == 0 ? .violet : .black }
        if d < m.easter { return .red }
        if d < m.easter + 7 { return .white }
        if isTriduumLitaniarum(dayOfYear: d, movable: m) { return .black }
        if d == m.ascension - 1 || d == m.ascension { return .white }
        if d < m.pentecost - 1 { return .green }
        if d < m.pentecost + 7 { return .red }
        if d == m.pentecost + 7 { return .white }    // the Holy Trinity
        if d < dedication { return .red }
        if d == dedication { return .white }
        return .green
    }

    /// A feast's colour by what its title says it is (§§ 39–42); `nil` when the title
    /// doesn't say, and the season's colour stands.
    static func color(of feast: AmbrosianCalendarEntry) -> CalendarColor? {
        let n = feast.feast.lowercased()
        switch feast.date {
        case "01-01", "05-03", "09-14", "08-29", "12-28": return .red     // Circumcision, the Cross, the Beheading, the Innocents
        case "12-27", "01-25", "01-18", "02-22", "05-14", "06-24", "03-19", "11-01": return .white
        default: break
        }
        if feastsOfOurLady.contains(feast.date) || n.contains("dedicatio") { return .white }
        if n.contains("angel") || n.contains("archang") { return .white }
        if n.contains("matronæ") { return .violet }
        if n.contains("abb.") || n.contains("abbatis") { return .green }
        if n.contains("defunct") { return .black }
        if n.contains("mart.") || n.contains("martyr") || n.contains("mm.") || n.contains("apost") || n.contains(" ap.") || n.contains("evang") { return .red }
        if feast.isSolemnityOfTheLord { return .white }
        if n.contains("virg") || n.contains("conf") || n.contains("episc") || n.contains("doct") || n.contains("sac") || n.contains("b. m. v.") { return .white }
        return nil
    }
}

/// The office a date keeps under the Ambrosian rite (`AmbrosianCalendar.office`).
public struct AmbrosianOffice: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case sunday, solemnity, feast, octaveDay, privilegedFeria, vigil, feria
    }
    public var kind: Kind
    /// The title block's name: the feast, or the day of the season.
    public var name: String
    /// The day of the season, whatever is kept.
    public var temporalName: String
    /// The *Kalendarium* feast kept, if any.
    public var feast: AmbrosianCalendarEntry?
    public var commemoration: String?
    /// The feast was moved here from the Sunday before, or out of Lent.
    public var transferred: Bool = false
}

extension AmbrosianCalendarEntry {
    /// *Solemnitas Domini* (§ 2).
    var isSolemnityOfTheLord: Bool { rank.contains("Dom.") }
    /// A day of an octave (*De Octava Epiph.*, *Octava Epiph.*), which never takes a Sunday.
    var isOctaveDay: Bool { feast.hasPrefix("De Octava") || feast.hasPrefix("Octava") }
    /// The order of the ranks: *Solemnitas Domini* (I and II class), *Solemne* (I and II
    /// class, *maius*, plain), *Proprium* (*Privil.*), then the simple feasts (§§ 1–3).
    var precedence: Int {
        let r = rank
        if r.contains("Dom.") { return r.contains("I cl.") && !r.contains("II cl.") ? 10 : r.contains("II cl.") ? 9 : 8 }
        if r.contains("II cl.") { return 6 }
        if r.contains("I cl.") { return 7 }
        if r.contains("maj") { return 5 }
        if r.hasPrefix("Sol") { return 4 }
        if r.hasPrefix("Priv") { return 3 }
        return 1
    }
}
