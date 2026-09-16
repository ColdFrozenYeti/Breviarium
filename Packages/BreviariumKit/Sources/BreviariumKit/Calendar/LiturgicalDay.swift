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
    /// A commemoration line, when one applies. **Always `nil` in this pass** —
    /// `Occurrence` doesn't build the commemoration list yet (see its doc comment);
    /// this field exists so the shape is right for when that lands, rather than bolting
    /// it on as a breaking change later.
    public var commemorationLine: String?
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

    public func day(day: Int, month: Int, year: Int) -> LiturgicalDay? {
        let occurrenceEngine = Occurrence(corpus: corpus, context: context, calendar: sanctoralCalendar)
        guard let occurrence = occurrenceEngine.resolve(day: day, month: month, year: year) else { return nil }

        let resolver = SectionResolver(corpus: corpus, context: context)
        let title = resolver.resolve(path: occurrence.winningPath, section: "Officium")
        let rankDisplayName = RankDisplayName1960.name(for: occurrence.winningRank.numericPrecedence)
        let color = LiturgicalColorClassifier.classify(title: title)

        let titleBlock = TitleBlock(
            classisLine: rankDisplayName == "Feria" ? nil : rankDisplayName,
            nameLine: title,
            commemorationLine: nil
        )

        return LiturgicalDay(
            day: day, month: month, year: year,
            occurrence: occurrence, rankDisplayName: rankDisplayName, color: color, titleBlock: titleBlock
        )
    }
}
