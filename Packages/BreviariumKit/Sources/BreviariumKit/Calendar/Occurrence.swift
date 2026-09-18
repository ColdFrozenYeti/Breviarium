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
    ///
    /// **26-31 December is a further exception**: whichever of those six days is a
    /// Sunday that year (there is always exactly one) uses `Tempora/Nat1-0`
    /// ("Dominica Infra Octavam Nativitatis") instead of its own day-numbered file.
    /// DO reaches this through a "dominical letter" indirection — seven
    /// `Tabulae/Transfer/{a..g}.txt` tables, one per possible Sunday-year, each
    /// redirecting exactly one December date to `Nat1-0` for 1960 rubrics (26th under
    /// letter c, 27th under d, 28th under e, 29th under f *as `Nat1-0a`, which only
    /// adds a Tridentine-non-Altovadensis commemoration this project doesn't
    /// implement, so it's identical to `Nat1-0` here*, 30th under b/g, 31st under a).
    /// Computing the day-of-week directly gets the same result without porting the
    /// letter machinery — confirmed against the real oracle fixture for 2025-12-28
    /// (a Sunday under this rule): the rendered Vespers antiphon "Tecum princípium..."
    /// is exactly `Sancti/12-25`'s own `[Ant Vespera 3]`, reached via `Nat1-0`'s own
    /// `[Ant Vespera]` cross-reference, not any day-numbered file's own content.
    ///
    /// **Not covered by this fix**: `horascommon.pl:457`'s further 1960-specific rule
    /// that, once the Sunday claims `Nat1-0`, the *displaced* day-numbered office
    /// (e.g. `Nat29` for 29 December, including that day's own named saint where one
    /// exists) still competes as a commemoration candidate. Commemoration assembly
    /// isn't folded into `HourAssembler` yet at all (its own doc comment already flags
    /// this), so this is an extension of that existing, deliberate scope limit, not a
    /// new gap this fix introduces.
    public static func temporalPath(day: Int, month: Int, year: Int) -> String {
        let weekday = Computus.dayOfWeek(day: day, month: month, year: year)
        if month == 12, (26...31).contains(day), weekday == 0 {
            return "Tempora/Nat1-0"
        }
        let week = TemporalCycle.weekName(day: day, month: month, year: year)
        if week.hasPrefix("Nat") { return "Tempora/\(week)" }
        return "Tempora/\(week)-\(weekday)"
    }

    public func resolve(day: Int, month: Int, year: Int) -> OccurrenceResult? {
        let resolver = SectionResolver(corpus: corpus, context: context)
        let weekday = Computus.dayOfWeek(day: day, month: month, year: year)
        let isSunday = weekday == 0

        let temporalPath = Self.temporalPath(day: day, month: month, year: year)
        let temporalRank = OfficeRank(rankFieldValue: resolver.resolveRank(path: temporalPath))

        // The first sanctoral candidate with a real [Rank] is the one occurrence()
        // itself would load ($sfile = shift @commemoentries) -- later candidates in the
        // list are commemoration material, handled separately (not by this pass).
        var sanctoralPath: String?
        var sanctoralRank: OfficeRank?
        var sanctoralRule = ""

        for candidate in calendar.candidates(day: day, month: month, year: year) {
            let path = "Sancti/\(candidate)"
            guard let rank = OfficeRank(rankFieldValue: resolver.resolveRank(path: path)) else { continue }
            sanctoralPath = path
            sanctoralRank = rank
            sanctoralRule = resolver.resolve(path: path, section: "Rule")
            break
        }

        // 25 December and 6 January have no Tempora file at all -- confirmed against the
        // real checkout (no Nat25.txt/Nat06.txt on disk): both are always won by their
        // own I. classis Sancti office, so DO itself never needed a temporal filler for
        // either date. A missing temporal file means sanctoral wins outright if it
        // resolved; if neither resolved, there is genuinely no office for this date.
        guard let temporalRank else {
            guard let sanctoralPath, let sanctoralRank else { return nil }
            return OccurrenceResult(sanctoralWins: true, winningPath: sanctoralPath, winningRank: sanctoralRank, isSunday: isSunday)
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
