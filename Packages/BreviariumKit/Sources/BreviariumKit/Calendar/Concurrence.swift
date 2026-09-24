import Foundation

/// Which Vespers is actually prayed on a given evening: today's own office, or
/// tomorrow's first Vespers pre-empting it — `docs/rubrics-1960-vespers.md` §3, the
/// practical consequence `CLAUDE.md` names directly ("Selecting a date and opening
/// Vespers gives what is prayed on that evening, including first Vespers of the next
/// day where the 1960 rubrics require it").
public struct ConcurrenceResult: Sendable {
    public var isFirstVespersOfTomorrow: Bool
    /// Whichever office's Vespers is actually prayed — tomorrow's if
    /// `isFirstVespersOfTomorrow`, otherwise today's.
    public var vespersOffice: OccurrenceResult
}

/// Decides first-vs-second Vespers by running `Occurrence` for both today and tomorrow.
/// Ports the **1960-specific** threshold rule from `horascommon.pl` (quoted in the
/// rubrics doc): first Vespers is suppressed unless tomorrow's rank clears a threshold
/// that's 5 (II. classis) when tomorrow is a Sunday, or today is a Saturday and
/// tomorrow's a *Festum Domini* — 6 (I. classis) otherwise. Also ports two further,
/// version-independent exclusions from the same `horascommon.pl` condition: an explicit
/// `"No prima vespera"` flag some office files' `[Rule]` sets directly, and the
/// Feria/Sabbato/Vigilia/Quatuor title-text exclusion (with its own override
/// exceptions for days within an octave, the Epiphany vigil, and Sundays).
///
/// **Explicitly not covered** (the same `horascommon.pl` condition has several more
/// branches this pass doesn't port): the 1955-specific and Barroux-specific thresholds
/// (irrelevant — this project only ever renders "Rubrics 1960 - 1960"), the
/// infra-octavam/Paschaltide/1-January/C10 exclusions. Flagged rather than silently
/// assumed handled; a real gap here should surface as an oracle diff once M4's fixture
/// generation exists to check against.
public struct Concurrence {
    public var corpus: OfficeCorpus
    public var context: ConditionalContext
    public var calendar: SanctoralCalendar

    public init(corpus: OfficeCorpus, context: ConditionalContext, calendar: SanctoralCalendar) {
        self.corpus = corpus
        self.context = context
        self.calendar = calendar
    }

    public func resolve(day: Int, month: Int, year: Int) -> ConcurrenceResult? {
        let occurrenceEngine = Occurrence(corpus: corpus, context: context, calendar: calendar)
        guard let today = occurrenceEngine.resolve(day: day, month: month, year: year) else { return nil }

        let tomorrowDate = Computus.addDays(1, day: day, month: month, year: year)
        guard var tomorrow = occurrenceEngine.resolve(day: tomorrowDate.day, month: tomorrowDate.month, year: tomorrowDate.year)
        else {
            return ConcurrenceResult(isFirstVespersOfTomorrow: false, vespersOffice: today)
        }

        let resolver = SectionResolver(corpus: corpus, context: context)

        // `horascommon.pl:314-315`'s own named, narrow special case, inside
        // `occurrence()`'s own "$tomorrow" branch (evaluating what *tomorrow's* own
        // winner would be, from today's own date): "ensure the Dominica IV adventus
        // win in case it has a '1st Vespers' on Dec 23" -- `$month == 12 && $day ==
        // 23` (today's own date, at the point this branch runs) zeroes tomorrow's own
        // sanctoral candidate entirely (`$srank = ''`), forcing tomorrow's occurrence
        // to resolve to its temporal winner instead. In most years 24 December is
        // simply "Vigilia Nativitatis" and this never matters (the Vigil naturally
        // loses occurrence to Advent's own Sunday most years anyway) -- but confirmed
        // real for 23-24 December 2028, the rare year the 4th Sunday of Advent falls
        // on Christmas Eve itself: the Vigil's own rank (6.9, `Sancti/12-24s`) would
        // otherwise numerically outrank Advent IV (6, `Tempora/Adv4-0`) at the ordinary
        // occurrence level, but the real fixture's own title is "Dominica IV Adventus
        // ~ I. classis", not the Vigil. This project's `Occurrence.resolve` has no
        // knowledge of "which date is being asked about as *tomorrow*" (it just
        // resolves whichever date it's given), so this narrow exclusion is applied
        // here in `Concurrence` instead, re-deriving tomorrow's own occurrence from
        // its temporal path alone -- gated tightly enough (one specific trigger date
        // per year) that it can't affect any other date's own occurrence, including a
        // direct query of 24 December itself as "today" rather than reached via this
        // specific Dec-23 pre-emption check.
        if day == 23, month == 12, tomorrow.winningPath.hasPrefix("Sancti/") {
            let temporalPath = Occurrence.temporalPath(
                day: tomorrowDate.day, month: tomorrowDate.month, year: tomorrowDate.year, calendar: calendar, corpus: corpus, context: context
            )
            if let temporalRank = OfficeRank(rankFieldValue: resolver.resolveRank(path: temporalPath)) {
                tomorrow = OccurrenceResult(sanctoralWins: false, winningPath: temporalPath, winningRank: temporalRank, isSunday: tomorrow.isSunday)
            }
        }

        let tomorrowRule = resolver.resolve(path: tomorrow.winningPath, section: "Rule")

        if hasNoPrimaVespera(tomorrowRule) || isExcludedByTitle(tomorrow.winningRank.title) {
            return ConcurrenceResult(isFirstVespersOfTomorrow: false, vespersOffice: today)
        }

        // `horascommon.pl:1072-1076`'s own "two concurrent Tempora" branch includes an
        // unconditional trigger: when *neither* today's nor tomorrow's winning office is
        // sanctoral (and tomorrow isn't the BVM-in-Sabbato Commune, `C10`, a separate
        // special case), today's own Rule saying `"No secunda vespera"` forces tomorrow's
        // first Vespers to win outright, regardless of rank. Only this one, narrow
        // trigger is ported here -- the branch's *other* disjunct (`$crank >= $rank`,
        // a non-strict rank comparison) sits inside a much larger real if/elsif cascade
        // (`horascommon.pl:965-1072`) this project doesn't otherwise port, and two
        // existing synthetic (non-fixture) unit tests assume the ordinary
        // Sunday/Festum-Domini threshold cascade below still applies to an ordinary
        // temporal-vs-temporal rank comparison -- unconfirmed either way against a real
        // fixture, so left alone rather than guessed at. Confirmed real for 26 April
        // 2025 (Sabbato in Albis, within the Easter Octave): its own
        // `Tempora/Pasc0-6.txt` `[Rule]` includes exactly "No secunda Vespera", forcing
        // Low Sunday's first Vespers to win outright even though Low Sunday's own
        // 1960-conditioned rank (6) is numerically *lower* than today's own (6.9) --
        // the generic threshold cascade below (which requires tomorrow to strictly
        // *outrank* today) would otherwise wrongly keep today's own second Vespers.
        if !today.winningPath.hasPrefix("Sancti/"), !tomorrow.winningPath.hasPrefix("Sancti/"), !tomorrow.winningPath.contains("C10") {
            let todayRule = resolver.resolve(path: today.winningPath, section: "Rule")
            if todayRule.range(of: "No secunda vespera", options: .caseInsensitive) != nil {
                return ConcurrenceResult(isFirstVespersOfTomorrow: true, vespersOffice: tomorrow)
            }
        }

        let todayIsSaturday = Computus.dayOfWeek(day: day, month: month, year: year) == 6
        let tomorrowIsFestumDomini = tomorrowRule.range(of: "Festum Domini", options: .caseInsensitive) != nil
        // `horascommon.pl:976-977` keys the lower threshold off tomorrow's *title*
        // (`$cwrank[0] =~ /Dominica/i`), not its weekday. The two differ when Christmas
        // falls on a Sunday: "Dominica Infra Octavam Nativitatis" is then kept on Friday
        // 30 December (`Tabulae/Transfer/b.txt`/`g.txt`, `12-30=Tempora/Nat1-0`), and
        // its rank of 5.4 clears only the Sunday threshold. Confirmed real for 29
        // December 2033 and 2039: "Dominica Infra Octavam Nativitatis ~ II. classis
        // Vespera de sequenti.", where this project kept 29 December's own Vespers.
        let tomorrowIsDominica = tomorrow.winningRank.title.range(of: "Dominica", options: .caseInsensitive) != nil
        let threshold: Double = (tomorrowIsDominica || (todayIsSaturday && tomorrowIsFestumDomini)) ? 5 : 6

        // "In 1960, in concurrence of days of equal rank, the preceding takes
        // precedence" (`horascommon.pl:1241-1242`'s own comment, `$rank >= $crank`,
        // where by that point in the real cascade `$rank`/`$crank` are today's/
        // tomorrow's) -- clearing the ordinary threshold above isn't enough on its own
        // when today's own rank is just as high (real case: the Annunciation and
        // St Joseph, both transferred by `SanctoralCalendar`'s transfer-table lookup
        // onto consecutive days in 2035, both I. classis). Not the full real cascade
        // (`horascommon.pl:1130-1332` has many more specific exclusions this pass
        // doesn't attempt), just this one confirmed, named case.
        let firstVespers = tomorrow.winningRank.numericPrecedence >= threshold
            && tomorrow.winningRank.numericPrecedence > today.winningRank.numericPrecedence
        return ConcurrenceResult(
            isFirstVespersOfTomorrow: firstVespers,
            vespersOffice: firstVespers ? tomorrow : today
        )
    }

    private func hasNoPrimaVespera(_ rule: String) -> Bool {
        rule.range(of: "No prima vespera", options: .caseInsensitive) != nil
    }

    private func isExcludedByTitle(_ title: String) -> Bool {
        let excludedPattern = "Feria|Sabbato|Vigilia|Quat[t]*uor"
        let overridePattern = "in Vigilia Epi|in octava|infra octavam|Dominica"
        guard let excluded = try? Regex("(?i)\(excludedPattern)"), (try? excluded.firstMatch(in: title)) != nil
        else { return false }
        guard let override = try? Regex("(?i)\(overridePattern)") else { return true }
        return (try? override.firstMatch(in: title)) == nil
    }
}
