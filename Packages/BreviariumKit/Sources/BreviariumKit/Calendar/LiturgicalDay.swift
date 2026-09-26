/// The day title block `CLAUDE.md`'s visual spec describes (§ "Day title block"):
/// an optional classis line above the name, the name itself, and an optional
/// commemoration line below it.
public struct TitleBlock: Equatable, Sendable {
    /// e.g. `"III. classis"` — `nil` for a plain feria, which has no separate rank line
    /// of its own (per `design/reference/Format.png`'s ferial example, which shows only
    /// the name line, "Feria IV hebdomadæ XXIV per annum", with nothing above it).
    public var classisLine: String?
    /// The feast or feria name, e.g. `"Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum"`.
    public var nameLine: String
    /// The line below the name (Beta 3): a commemoration, the season's Scripture, or a
    /// transferred feast, as DO prints it for the hour (`LiturgicalCalendarEngine.headLine`);
    /// `nil` at Vespers and Compline and when there is none.
    public var commemorationLine: String?

    public init(classisLine: String?, nameLine: String, commemorationLine: String?) {
        self.classisLine = classisLine
        self.nameLine = nameLine
        self.commemorationLine = commemorationLine
    }
}

/// The fully-resolved result for one calendar day: which office wins (`Occurrence`),
/// its rank and 1960 display name, its liturgical colour, and the title block text.
public struct LiturgicalDay: Sendable {
    public var day: Int
    public var month: Int
    public var year: Int
    public var occurrence: OccurrenceResult
    public var rankDisplayName: String
    public var color: LiturgicalColor
    public var titleBlock: TitleBlock
}

/// Assembles a `LiturgicalDay` for a given date: runs `Occurrence`, then reads the
/// winning office's `[Officium]` title (`SectionResolver`) to derive the display name,
/// rank label, and liturgical colour.
public struct LiturgicalCalendarEngine {
    public var corpus: OfficeCorpus
    public var context: ConditionalContext
    public var sanctoralCalendar: SanctoralCalendar

    public init(corpus: OfficeCorpus, context: ConditionalContext, sanctoralCalendar: SanctoralCalendar) {
        self.corpus = corpus
        self.context = context
        self.sanctoralCalendar = sanctoralCalendar
    }

    /// The day as Vespers shows it: the office whose Vespers is prayed that evening
    /// (`Concurrence`, tomorrow's on first Vespers), titled as DO titles the page -- its
    /// name with the monthday suffix ("… III. Augusti", `HourAssembler.monthdayTitleSuffix`)
    /// and its own rank. `CLAUDE.md`: "Match Divinum Officium's behaviour, including the
    /// title block it shows in those cases". Checked on every date by
    /// `vespersFullRangeTitleAudit`.
    public func vespersDay(day: Int, month: Int, year: Int) -> LiturgicalDay? {
        let concurrence = Concurrence(corpus: corpus, context: context, calendar: sanctoralCalendar)
        guard let result = concurrence.resolve(day: day, month: month, year: year) else { return nil }
        let office = result.vespersOffice
        let suffix = HourAssembler.monthdayTitleSuffix(
            office: office.winningPath, day: day, month: month, year: year, tomorrow: result.isFirstVespersOfTomorrow
        )
        return Self.liturgicalDay(day: day, month: month, year: year, occurrence: office, titleSuffix: suffix)
    }

    /// The day as a given hour shows it (Beta 2): Vespers and Compline follow
    /// `vespersDay`; the other hours the day's own office, with its monthday suffix.
    public func day(for hour: CanonicalHour, day: Int, month: Int, year: Int, officium: Officium) -> LiturgicalDay? {
        guard officium != .diei else { return self.day(for: hour, day: day, month: month, year: year) }
        // A votive office (Beta 4) is titled by its own Commune, with no line under it.
        // At Vespers and Compline the form follows concurrence (`HourAssembler.assembleUnmarked`).
        let concurrence = hour.followsConcurrence
            ? Concurrence(corpus: corpus, context: context, calendar: sanctoralCalendar).resolve(day: day, month: month, year: year) : nil
        let seasonDate = concurrence?.isFirstVespersOfTomorrow == true
            ? Computus.addDays(1, day: day, month: month, year: year) : (day: day, month: month, year: year)
        guard let dayOffice = concurrence?.vespersOffice
                ?? Occurrence(corpus: corpus, context: context, calendar: sanctoralCalendar).resolve(day: day, month: month, year: year),
            let path = officium.votivePath(
                hour: hour, day: day, month: month, year: year,
                weekName: TemporalCycle.weekName(day: seasonDate.day, month: seasonDate.month, year: seasonDate.year), dayWinnerPath: dayOffice.winningPath
            ),
            let rank = Officium.votiveRank(path: path, resolver: SectionResolver(corpus: corpus, context: context), dayRank: nil)
        else { return nil }
        let votive = OccurrenceResult(sanctoralWins: false, winningPath: path, winningRank: rank, isSunday: dayOffice.isSunday)
        return Self.liturgicalDay(day: day, month: month, year: year, occurrence: votive, titleSuffix: "")
    }

    public func day(for hour: CanonicalHour, day: Int, month: Int, year: Int) -> LiturgicalDay? {
        if hour.followsConcurrence { return vespersDay(day: day, month: month, year: year) }
        let occurrenceEngine = Occurrence(corpus: corpus, context: context, calendar: sanctoralCalendar)
        guard let occurrence = occurrenceEngine.resolve(day: day, month: month, year: year) else { return nil }
        let suffix = HourAssembler.monthdayTitleSuffix(office: occurrence.winningPath, day: day, month: month, year: year, tomorrow: false)
        var result = Self.liturgicalDay(day: day, month: month, year: year, occurrence: occurrence, titleSuffix: suffix)
        result.titleBlock.commemorationLine = headLine(for: hour, day: day, month: month, year: year)
        return result
    }

    public func day(day: Int, month: Int, year: Int) -> LiturgicalDay? {
        let occurrenceEngine = Occurrence(corpus: corpus, context: context, calendar: sanctoralCalendar)
        guard let occurrence = occurrenceEngine.resolve(day: day, month: month, year: year) else { return nil }

        // `winningRank.title` (not an independent `resolve(path:, section: "Officium")`
        // call): `SectionResolver.resolveRank` already handles both cases -- a file
        // with its own `[Officium]` gets that substituted in as the Rank's own leading
        // field, but a file with NO separate `[Officium]` section at all (real example:
        // `Sancti/08-14.txt`, In Vigilia Assumptionis B.M.V., whose own title is only
        // ever written directly into `[Rank]`'s leading field) skips the substitution
        // and returns the Rank text as-is, title already included. Calling `resolve`
        // for "Officium" independently, as this used to, returns the "is missing!"
        // placeholder text for exactly that second case, which then rendered as the
        // literal day-title-block text -- a real bug, found via a full walkthrough for
        // 14 August 2028.
        return Self.liturgicalDay(day: day, month: month, year: year, occurrence: occurrence, titleSuffix: "")
    }

    private static func liturgicalDay(day: Int, month: Int, year: Int, occurrence: OccurrenceResult, titleSuffix: String) -> LiturgicalDay {
        let title = occurrence.winningRank.title
        let rankDisplayName = RankDisplayName1960.name(for: occurrence.winningRank.numericPrecedence)
        let color = LiturgicalColorClassifier.classify(title: title)

        let titleBlock = TitleBlock(
            classisLine: rankDisplayName == "Feria" ? nil : rankDisplayName,
            nameLine: title + titleSuffix,
            commemorationLine: nil
        )

        return LiturgicalDay(
            day: day, month: month, year: year,
            occurrence: occurrence, rankDisplayName: rankDisplayName, color: color, titleBlock: titleBlock
        )
    }
}
