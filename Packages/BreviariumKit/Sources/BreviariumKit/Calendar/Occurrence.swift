import Foundation

/// The result of deciding whether the temporal or sanctoral cycle wins a given day.
public struct OccurrenceResult: Equatable, Sendable {
    public var sanctoralWins: Bool
    /// The winning office's path, e.g. `"Tempora/Adv1-0"` or `"Sancti/01-18r"`.
    public var winningPath: String
    public var winningRank: OfficeRank
    public var isSunday: Bool
}

/// Decides, for one calendar day, whether the sanctoral or temporal office is prayed —
/// a focused port of the **1960-specific** core of `occurrence()` (`horascommon.pl`),
/// covering the rules `docs/rubrics-1960-vespers.md` §1 documents and cites:
///
/// - No real sanctoral office, or (1960 rubrics) its rank is ≤ 1.1: temporal wins.
/// - Sanctoral numerically outranks temporal: sanctoral wins.
/// - On a Sunday, sanctoral can still win without numerically outranking it, but only
///   when it's rank ≥ 6 (I. classis), or rank ≥ 5 (II. classis) *and* a Festum Domini —
///   "II. cl. feasts of the Lord and all I. cl. feasts beat II. cl. Sundays"
///   (`horascommon.pl`, quoted in the rubrics doc) — or it's the Immaculate Conception
///   (RG 15's named exception).
/// - Otherwise temporal wins.
///
/// **Explicitly not covered by this pass** (flagged, not silently assumed away):
/// permanent/annual temporal transfers (e.g. a fixed feast displaced by Holy Week —
/// CLAUDE.md's named Annunciation/St Joseph transfer edge cases), Ember days, and
/// concurrence (which office gets *Vespers* specifically, when today's second Vespers
/// meets tomorrow's first — `docs/rubrics-1960-vespers.md` §3). Those need more of
/// `occurrence()`/`concurrence()` ported than this focused pass covers; this is the day-
/// level occurrence decision only, the foundation the rest builds on.
public struct Occurrence {
    public var corpus: OfficeCorpus
    public var context: ConditionalContext
    public var calendar: SanctoralCalendar

    public init(corpus: OfficeCorpus, context: ConditionalContext, calendar: SanctoralCalendar) {
        self.corpus = corpus
        self.context = context
        self.calendar = calendar
    }

    /// The temporal file path for a date — `weekName` plus `"-<day-of-week>"`, except
    /// `Nat` weeks, which are numbered by day-of-month and never take that suffix
    /// (`horascommon.pl`: `"$weekname" . (($weekname !~ /Nat/i) ? "-$dayofweek" : "")`).
    public static func temporalPath(day: Int, month: Int, year: Int) -> String {
        let week = TemporalCycle.weekName(day: day, month: month, year: year)
        if week.hasPrefix("Nat") { return "Tempora/\(week)" }
        let weekday = Computus.dayOfWeek(day: day, month: month, year: year)
        return "Tempora/\(week)-\(weekday)"
    }

    public func resolve(day: Int, month: Int, year: Int) -> OccurrenceResult? {
        let resolver = SectionResolver(corpus: corpus, context: context)
        let weekday = Computus.dayOfWeek(day: day, month: month, year: year)
        let isSunday = weekday == 0

        let temporalPath = Self.temporalPath(day: day, month: month, year: year)
        guard let temporalRank = OfficeRank(rankFieldValue: resolver.resolve(path: temporalPath, section: "Rank"))
        else { return nil }

        // The first sanctoral candidate with a real [Rank] is the one occurrence()
        // itself would load ($sfile = shift @commemoentries) -- later candidates in the
        // list are commemoration material, handled separately (not by this pass).
        var sanctoralPath: String?
        var sanctoralRank: OfficeRank?
        var sanctoralRule = ""

        for candidate in calendar.candidates(day: day, month: month, year: year) {
            let path = "Sancti/\(candidate)"
            guard let rank = OfficeRank(rankFieldValue: resolver.resolve(path: path, section: "Rank")) else { continue }
            sanctoralPath = path
            sanctoralRank = rank
            sanctoralRule = resolver.resolve(path: path, section: "Rule")
            break
        }

        let sanctoralWins = decideSanctoralWins(
            temporalRank: temporalRank,
            sanctoralRank: sanctoralRank,
            sanctoralRule: sanctoralRule,
            isSunday: isSunday
        )

        if sanctoralWins, let sanctoralPath, let sanctoralRank {
            return OccurrenceResult(sanctoralWins: true, winningPath: sanctoralPath, winningRank: sanctoralRank, isSunday: isSunday)
        }
        return OccurrenceResult(sanctoralWins: false, winningPath: temporalPath, winningRank: temporalRank, isSunday: isSunday)
    }

    private func decideSanctoralWins(
        temporalRank: OfficeRank,
        sanctoralRank: OfficeRank?,
        sanctoralRule: String,
        isSunday: Bool
    ) -> Bool {
        guard let sanctoralRank else { return false }
        if sanctoralRank.numericPrecedence <= 1.1 { return false }
        if sanctoralRank.numericPrecedence > temporalRank.numericPrecedence { return true }

        guard isSunday else { return false }

        let isFestumDomini = sanctoralRule.range(of: "Festum Domini", options: .caseInsensitive) != nil
        if sanctoralRank.numericPrecedence >= 6 { return true }
        if sanctoralRank.numericPrecedence >= 5 && isFestumDomini { return true }
        // RG 15: the Immaculate Conception is preferred in occurrence even without
        // outranking the Sunday numerically (but not in concurrence -- see the rubrics
        // doc; concurrence is out of scope for this pass regardless).
        if sanctoralRank.title.range(of: "Conceptione Immaculata", options: .caseInsensitive) != nil { return true }
        return false
    }
}
