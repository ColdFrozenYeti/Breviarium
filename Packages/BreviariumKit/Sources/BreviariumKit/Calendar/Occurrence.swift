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
    /// **`horascommon.pl:457`'s further 1960-specific rule** -- once the Sunday claims
    /// `Nat1-0`, the *displaced* day-numbered office (e.g. `Nat29` for 29 December,
    /// including that day's own named saint where one exists) still competes as a
    /// commemoration candidate -- was investigated and confirmed **inert for every
    /// Vespers this project's alpha scope actually renders**, not implemented:
    /// `horascommon.pl:457` itself only fires for `$day > 28` (29/30/31; 26-28 already
    /// have real, separately-Kalendaria-listed saints that don't need this hijack), and
    /// checking every real year 2025-2040 where one of those three dates is the Sunday
    /// (2028/31, 2029/30, 2030/29, 2034/31, 2035/30, 2040/30) against the real oracle
    /// fixtures shows the displaced saint never actually produces a visible
    /// commemoration at Vespers: 29 December's St Thomas of Canterbury is rank 1.1 under
    /// 1960 (`Occurrence.decideSanctoralWins`'s own `<= 1.1` cutoff already excludes it
    /// as a candidate at all, hijack or not); 30 December has no Sancti file whatsoever;
    /// 31 December's own second Vespers is superseded by 1 January's first Vespers
    /// (ordinary concurrence, confirmed against the real 2028 fixture) before this
    /// mechanism could matter. Flagged as investigated-and-closed rather than silently
    /// dropped a second time.
    public static func temporalPath(day: Int, month: Int, year: Int) -> String {
        let weekday = Computus.dayOfWeek(day: day, month: month, year: year)
        if month == 12, (26...31).contains(day), weekday == 0 {
            return "Tempora/Nat1-0"
        }
        let week = TemporalCycle.weekName(day: day, month: month, year: year)
        if week.hasPrefix("Nat") { return "Tempora/\(week)" }
        return "Tempora/\(week)-\(weekday)"
    }

    /// The same computation, but consulting `calendar`'s own annual transfer table
    /// first — the January analogue of the December 26-31 case above, and (unlike that
    /// one) not something this project's own week-name arithmetic can reconstruct by
    /// pattern alone, since it's genuinely a per-year *dominical-letter* lookup, not a
    /// fixed rule. Real, confirmed example (a debug trace against the real pinned DO
    /// engine in Docker, not guessed): `Tabulae/Transfer/e.txt`'s own `01-05=Tempora/
    /// Nat2-0` (2025's own dominical letter) means 5 January 2025's real winning
    /// temporal file is `Tempora/Nat2-0.txt`, not the plain day-numbered `Tempora/
    /// Nat05` this project's own week-name computation would otherwise return —
    /// confirmed by patching `capitulis.pl` in the pinned container to print `$winner`
    /// directly. Found via a full 2025-2040 content audit: this single gap alone
    /// accounted for a large share of the thousands of wrong Hymnus/Capitulum/Versus/
    /// Oratio/Psalmodia days that audit found across the whole range, since every date
    /// within reach of a January transfer target (the target Sunday itself, its own
    /// first Vespers the evening before, and any commemoration runner-up lookup for
    /// nearby days) was computing its temporal file from the wrong path.
    public static func temporalPath(day: Int, month: Int, year: Int, calendar: SanctoralCalendar) -> String {
        let path = calendar.transferredTemporalPath(day: day, month: month, year: year) ?? temporalPath(day: day, month: month, year: year)
        return calendar.redirectedTemporalPath(path)
    }

    /// Ember Wednesday/Friday/Saturday's own further exception: DO's `monthday()` merge
    /// (`SetupString.pl:723-780`, ported to `Computus.monthday`) overwrites the ordinary
    /// week-based file's own `[Officium]`/`[Rank]` whenever the monthday file defines
    /// them itself — true for exactly three files in the whole corpus (confirmed by a
    /// full-corpus grep for `[Officium]` across every `08N-D`/`09N-D`/`10N-D`/`11N-D`
    /// monthday file): the September Ember days (`093-3`/`093-5`/`093-6`), each with its
    /// own named title and a `Feria major` rank (4.9 under 1960) well above the
    /// ordinary low-rank feria the plain week-based path alone would find. Every other
    /// monthday file only ever supplies `[Ant 1]`/lessons — `HourAssembler`'s own
    /// `monthdayLocation` already merges those in separately, for the Magnificat
    /// antiphon specifically — and grepping the whole corpus confirms none of the 140
    /// monthday files ever define `[Ant Vespera]`/`[Capitulum Vespera]`/
    /// `[Hymnus Vespera]`, so this override never needs to touch anything beyond
    /// occurrence's own winner decision: Capitulum/Hymnus/Versus/Ant Vespera correctly
    /// keep falling through to the ordinary temporal path's own Commune/Major Special
    /// fallback exactly as they already do for any other low-rank feria.
    ///
    /// Found via a full 2025-2040 content audit: without this, a September Ember day's
    /// own (low, rank-1) ordinary week-based rank let even a Semiduplex
    /// commemoration-grade saint (rank 2.2) numerically outrank it, wrongly winning the
    /// whole day outright. Confirmed real for 23 September 2026 (Ember Wednesday): the
    /// real fixture's own title is "Feria Quarta Quattuor Temporum Septembris ~ II.
    /// classis", not "S. Lini Papæ et Martyris" — this project's engine wrongly let St
    /// Linus (rank 2.2) win, since the plain week-based path's own unmerged rank is
    /// only 1 (an ordinary feria), which 2.2 numerically outranks.
    public static func temporalPath(
        day: Int, month: Int, year: Int, calendar: SanctoralCalendar, corpus: OfficeCorpus, context: ConditionalContext
    ) -> String {
        let ordinary = temporalPath(day: day, month: month, year: year, calendar: calendar)
        guard let monthdayKey = Computus.monthday(day: day, month: month, year: year, tomorrow: false) else { return ordinary }
        let monthdayPath = "Tempora/\(monthdayKey)"
        let resolver = SectionResolver(corpus: corpus, context: context)
        return resolver.sectionExists(path: monthdayPath, section: "Officium") ? monthdayPath : ordinary
    }

    public func resolve(day: Int, month: Int, year: Int) -> OccurrenceResult? {
        let resolver = SectionResolver(corpus: corpus, context: context)
        let weekday = Computus.dayOfWeek(day: day, month: month, year: year)
        let isSunday = weekday == 0

        let temporalPath = Self.temporalPath(day: day, month: month, year: year, calendar: calendar, corpus: corpus, context: context)
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
            if Self.isAllSoulsSuppressedOnSaturday(title: rank.title, month: month, weekday: weekday) { continue }
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

    /// `horascommon.pl`'s own "Office of All Souls' day ends after None" exclusion
    /// (within `occurrence()`'s `$hora =~ /Vespera|Completorium/` branch): the real
    /// condition is `($version !~ /196/ || $dayofweek == 6) && $month == 11 && $srank
    /// =~ /Omnium Fidelium defunctorum/i && !$caller` — for this project's 1960-only,
    /// non-chained scope (`$caller` marks a *nested* lookup this project never makes),
    /// that collapses to exactly: Saturday, November, this specific title. When it
    /// fires, All Souls is removed from sanctoral candidacy entirely for that day's own
    /// Vespers — not merely outranked, genuinely absent — letting the ordinary next
    /// day's Sunday take over completely via the normal first-Vespers mechanism, with
    /// no trace of All Souls at all (no commemoration, no Special Conclusio).
    ///
    /// Confirmed real for 2 November 2030 (a Saturday): the real fixture's own Vespers
    /// is plain "Dominica XXI Post Pentecosten... Vespera de sequenti" with an ordinary
    /// ferial Conclusio ending — not All Souls' own "Conclusio specialis" this
    /// project's engine rendered instead, having kept All Souls as the day's winning
    /// sanctoral office regardless of the Saturday date.
    private static func isAllSoulsSuppressedOnSaturday(title: String, month: Int, weekday: Int) -> Bool {
        guard month == 11, weekday == 6 else { return false }
        return title.range(of: "Omnium Fidelium Defunctorum", options: .caseInsensitive) != nil
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

        // RG 15: the Immaculate Conception is preferred in occurrence even without
        // outranking the Sunday numerically (but not in concurrence -- see the rubrics
        // doc; concurrence is out of scope for this pass regardless) -- a genuinely
        // separate exception in the real Perl (`horascommon.pl:494`'s own `elsif`, at
        // the same level as the `$trank[2] <= 5` branch below, not nested inside it), so
        // this is the one Sunday-exception case that applies regardless of how
        // privileged the Sunday itself is.
        if sanctoralRank.title.range(of: "Conceptione Immaculata", options: .caseInsensitive) != nil { return true }

        // "With the 1960 rubrics, II. cl. feasts of the Lord and all I. cl. feasts beat
        // II. cl. Sundays" (`horascommon.pl:491`, `docs/rubrics-1960-vespers.md` §1) --
        // real, confirmed real-data values: `Tempora/Epi2-0`'s actual rank (an ordinary
        // Sunday after Epiphany) is 5, while `Tempora/Adv1-0`/`Quad6-0`/`Pasc0-0`
        // (Advent, Palm, Easter Sunday) are deliberately elevated to 6.9/6.91/7 by
        // `horascommon.pl:464-468`'s own "Major Sunday" rank-capping precisely so an
        // ordinary I. classis feast does *not* automatically win there — the
        // `$trank[2] <= 5` guard here (missing until a real oracle-fixture check against
        // the Annunciation's own natural date in 2029/2035 caught it) is what actually
        // distinguishes "II. cl. Sunday" from a Major Sunday, not the sanctoral side.
        guard temporalRank.numericPrecedence <= 5 else { return false }

        let isFestumDomini = sanctoralRule.range(of: "Festum Domini", options: .caseInsensitive) != nil
        if sanctoralRank.numericPrecedence >= 6 { return true }
        if sanctoralRank.numericPrecedence >= 5 && isFestumDomini { return true }
        return false
    }
}
