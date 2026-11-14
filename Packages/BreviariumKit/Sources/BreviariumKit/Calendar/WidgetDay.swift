import Foundation

/// What a widget shows for one hour of one day (1.5, `docs/1.5_plan.md`): the date line,
/// the day's title block and colour, the hour, and its antiphon. Every field comes from
/// the engine the app's own pages use, called as `OfficeDataStore.content(for:…)` calls
/// it, so a widget always agrees with the page a tap on it opens.
public struct WidgetDay: Equatable, Sendable {
    public var day: Int
    public var month: Int
    public var year: Int
    /// The hour shown: the one asked for, or the nearest earlier one the office has
    /// (`Officium.availableHour(for:)`); Compline under *Ambrosianus*.
    public var hour: CanonicalHour
    /// `"Ad Vesperas"` (`CanonicalHour.title`).
    public var hourTitle: String
    /// `"Dies 14 novembris 2026"` (`LatinDateLine`).
    public var dateLine: String
    /// The title block the hour's page shows: at Vespers and Compline that can be the
    /// next day's office (first Vespers), as on the page.
    public var titleBlock: TitleBlock
    /// The class as a Roman numeral, as the Kalendarium gives it (`"II"`); `nil` for a feria.
    public var classis: String?
    /// The colour of the office the title block names.
    public var color: CalendarColor?
    /// The hour's antiphon, Latin, as the page prints it (`antiphon(of:hour:)`); `nil`
    /// when the hour has none (the little hours of the Triduum).
    public var antiphon: String?

    /// The text a widget shows under the hour's title: the antiphon, or, when the hour
    /// has none, the day's Latin title, the name line of its title block (decided
    /// 2026-11-14; *Feria Sexta in Passione et Morte Domini* at the little hours of Good Friday).
    public var hourText: String { antiphon ?? titleBlock.nameLine }

    /// Whether `hourText` is the antiphon (set as an antiphon) or the day's title (set
    /// as the title is).
    public var hourTextIsAntiphon: Bool { antiphon != nil }

    public init(
        day: Int, month: Int, year: Int, hour: CanonicalHour, dateLine: String, titleBlock: TitleBlock, color: CalendarColor?, antiphon: String?
    ) {
        self.day = day
        self.month = month
        self.year = year
        self.hour = hour
        hourTitle = hour.title
        self.dateLine = dateLine
        self.titleBlock = titleBlock
        classis = Kalendarium.classis(of: titleBlock.classisLine)
        self.color = color
        self.antiphon = antiphon
    }

    /// The antiphon a widget shows for an assembled hour (decided 2026-11-14):
    /// - at Lauds, Vespers and Compline, the Gospel canticle's antiphon (*Benedictus*,
    ///   *Magnificat*, *Nunc dimittis*), as said after the canticle: the last antiphon of
    ///   the `canticum` section. That is the whole antiphon in every rite, where the text
    ///   before the canticle can be an intonation alone (Ambrosian Compline's *Salva nos.*);
    /// - at Matins, the first antiphon of the first nocturn (not the invitatory);
    /// - at the other hours, the first antiphon of the psalmody.
    /// `nil` when that section has no antiphon; the widget then shows the day's title
    /// (`hourText`), never another antiphon.
    public static func antiphon(of assembled: Hour, hour: CanonicalHour) -> String? {
        func antiphons(_ kinds: [Section.Kind]) -> [String] {
            guard let section = assembled.sections.first(where: { kinds.contains($0.kind) }) else { return [] }
            return section.units.compactMap { unit in
                if case .antiphon(let text, _) = unit { text } else { nil }
            }
        }
        switch hour {
        case .laudes, .vesperae, .completorium: return antiphons([.canticum]).last
        case .matutinum: return antiphons([.nocturnusI, .adNocturnum]).first
        case .prima, .tertia, .sexta, .nona: return antiphons([.psalmodia]).first
        }
    }
}

/// Builds `WidgetDay`s from the widget's data file (`PackedBundle`).
public struct WidgetOffice: Sendable {
    private let pack: PackedBundle
    private let ambrosian: AmbrosianCompline?

    public init(pack: PackedBundle) {
        self.pack = pack
        ambrosian = pack.ambrosianCompline
    }

    /// One hour of a day under a rite, office and psalter. The psalter is the widget's
    /// own *Psalterium* option (decided 2026-11-14): the psalmody's antiphons follow it.
    public func day(
        _ requested: CanonicalHour, day: Int, month: Int, year: Int, rite: Rite = .romanus, officium: Officium = .diei, psalter: Psalter = .vulgate
    ) -> WidgetDay? {
        let dateLine = LatinDateLine.format(day: day, month: month, year: year)
        guard rite.usesDivinumOfficium else {
            guard let ambrosian else { return nil }
            let assembled = ambrosian.assemble(day: day, month: month, year: year, priest: false)
            return WidgetDay(
                day: day, month: month, year: year, hour: .completorium, dateLine: dateLine,
                titleBlock: ambrosian.titleBlock(day: day, month: month, year: year),
                color: ambrosian.calendar.color(day: day, month: month, year: year),
                antiphon: WidgetDay.antiphon(of: assembled, hour: .completorium)
            )
        }
        let hour = officium.availableHour(for: requested)
        let corpus = pack.makeLatinCorpus(psalter: psalter)
        let sanctoralCalendar = pack.makeSanctoralCalendar(rite: rite)
        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year, ad: hour.doName, rubrica: rite.doVersion, corpus: corpus, sanctoralCalendar: sanctoralCalendar
        )
        guard let assembled = HourAssembler(corpus: corpus, context: context, calendar: sanctoralCalendar, englishCorpus: nil)
            .assemble(hour, day: day, month: month, year: year, priest: false, officium: officium),
            let liturgicalDay = LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: sanctoralCalendar)
            .day(for: hour, day: day, month: month, year: year, officium: officium)
        else { return nil }
        return WidgetDay(
            day: day, month: month, year: year, hour: hour, dateLine: dateLine, titleBlock: liturgicalDay.titleBlock,
            color: CalendarColor(color: liturgicalDay.color, officePath: liturgicalDay.occurrence.winningPath),
            antiphon: WidgetDay.antiphon(of: assembled, hour: hour)
        )
    }

    /// A day's widget timeline: one entry from each clock hour in
    /// `CanonicalHour.timeOfDayBoundaries` (midnight, 05:00, 09:00 …), showing the hour
    /// `CanonicalHour.forTimeOfDay` gives then. Consecutive entries showing the same
    /// hour (the Office of the Dead's Lauds from 05:00 to 17:00; Ambrosian Compline all
    /// day) are merged into the first.
    public func timeline(
        day: Int, month: Int, year: Int, rite: Rite = .romanus, officium: Officium = .diei, psalter: Psalter = .vulgate
    ) -> [(clockHour: Int, entry: WidgetDay)] {
        var result: [(clockHour: Int, entry: WidgetDay)] = []
        for clockHour in CanonicalHour.timeOfDayBoundaries {
            let requested = CanonicalHour.forTimeOfDay(clockHour: clockHour)
            let shown = rite.usesDivinumOfficium ? officium.availableHour(for: requested) : .completorium
            if result.last?.entry.hour == shown { continue }
            guard let entry = self.day(requested, day: day, month: month, year: year, rite: rite, officium: officium, psalter: psalter)
            else { continue }
            result.append((clockHour, entry))
        }
        return result
    }
}
