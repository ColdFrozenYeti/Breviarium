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
        guard let tomorrow = occurrenceEngine.resolve(day: tomorrowDate.day, month: tomorrowDate.month, year: tomorrowDate.year)
        else {
            return ConcurrenceResult(isFirstVespersOfTomorrow: false, vespersOffice: today)
        }

        let resolver = SectionResolver(corpus: corpus, context: context)
        let tomorrowRule = resolver.resolve(path: tomorrow.winningPath, section: "Rule")

        if hasNoPrimaVespera(tomorrowRule) || isExcludedByTitle(tomorrow.winningRank.title) {
            return ConcurrenceResult(isFirstVespersOfTomorrow: false, vespersOffice: today)
        }

        let todayIsSaturday = Computus.dayOfWeek(day: day, month: month, year: year) == 6
        let tomorrowIsFestumDomini = tomorrowRule.range(of: "Festum Domini", options: .caseInsensitive) != nil
        let threshold: Double = (tomorrow.isSunday || (todayIsSaturday && tomorrowIsFestumDomini)) ? 5 : 6

        let firstVespers = tomorrow.winningRank.numericPrecedence >= threshold
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
