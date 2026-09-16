import Foundation

/// One office carried as a commemoration alongside the Vespers actually prayed.
public struct Commemoration: Equatable, Sendable {
    public var path: String
    public var rank: OfficeRank
}

/// Decides which offices are commemorated at the Vespers `Concurrence` says is actually
/// prayed on a given evening -- a port of the closing two blocks of `concurrence()`
/// (`horascommon.pl:1336-1462`), filtered to the branches `"Rubrics 1960 - 1960"` takes.
/// `docs/rubrics-1960-vespers.md` §2 is the full citation-by-citation reading this
/// implements; read that first if any of the four cases below looks surprising.
///
/// The four cases, matched to the doc's §2a/§2b:
/// - Today's own second Vespers wins: tomorrow's office is **never** commemorated (a
///   real 1960 simplification, not an omission -- see `resolve(day:month:year:)`).
///   Today's own runners-up (a losing Feria, or a lower-priority saint) still are,
///   filtered by `ownVespersRanklimit`/`ownVespersCommemorations`.
/// - Tomorrow's first Vespers pre-empts today's: the *displaced* office (today's own
///   occurrence winner) is commemorated per `displacedRanklimit`, and the winner's own
///   other runners-up per `winnerRanklimitAndSundayOnly` -- which reduces, for 1960, to
///   "only if that runner-up is itself a Sunday" (the doc explains why).
public struct Commemorations {
    public var corpus: OfficeCorpus
    public var context: ConditionalContext
    public var calendar: SanctoralCalendar

    /// Rank values `horascommon.pl` exempts from every rank-threshold check in this
    /// function ("Feria privilegiata" and similar always-survive fine-grained ranks).
    private static let privilegedRanks: Set<Double> = [1.15, 2.1, 2.99, 3.9]

    public init(corpus: OfficeCorpus, context: ConditionalContext, calendar: SanctoralCalendar) {
        self.corpus = corpus
        self.context = context
        self.calendar = calendar
    }

    /// The commemorations for the Vespers actually prayed on the evening of `day`, as
    /// decided by `Concurrence.resolve(day:month:year:)`.
    public func resolve(day: Int, month: Int, year: Int) -> [Commemoration] {
        let concurrence = Concurrence(corpus: corpus, context: context, calendar: calendar)
        guard let result = concurrence.resolve(day: day, month: month, year: year) else { return [] }

        guard result.isFirstVespersOfTomorrow else {
            // §2a: tomorrow is never commemorated here in 1960 -- only today's own
            // runners-up survive.
            let candidates = runnersUp(day: day, month: month, year: year, winnerPath: result.vespersOffice.winningPath)
            return ownVespersCommemorations(candidates: candidates, winnerRank: result.vespersOffice.winningRank)
        }

        let occurrenceEngine = Occurrence(corpus: corpus, context: context, calendar: calendar)
        guard let today = occurrenceEngine.resolve(day: day, month: month, year: year) else { return [] }
        let tomorrowDate = Computus.addDays(1, day: day, month: month, year: year)

        // The displaced office's own commemoration candidate pool is headlined by today's
        // own occurrence winner itself -- the office that would have had Vespers tonight
        // (`$commemoratio = $winner` in the Perl, ahead of the closing `@commemoentries`
        // filter) -- plus any of its own runners-up, both subject to the same threshold.
        let displacedCandidates =
            [Commemoration(path: today.winningPath, rank: today.winningRank)]
            + runnersUp(day: day, month: month, year: year, winnerPath: today.winningPath)
        let displaced = displacedVespersCommemorations(
            candidates: displacedCandidates, displacedRank: today.winningRank, winnerRank: result.vespersOffice.winningRank
        )

        let winnerCandidates = runnersUp(
            day: tomorrowDate.day, month: tomorrowDate.month, year: tomorrowDate.year,
            winnerPath: result.vespersOffice.winningPath
        )
        let winnerRunnersUp = winnerRunnersUpCommemorations(candidates: winnerCandidates, winnerRank: result.vespersOffice.winningRank)

        return displaced + winnerRunnersUp
    }

    // MARK: - Candidate pools

    /// The occurrence-side candidate pool for one date: the temporal office plus every
    /// sanctoral candidate, minus whichever one actually won -- the runners-up
    /// `@commemoentries` holds after `occurrence()`'s own winner selection
    /// (`Occurrence.swift` ports that selection itself; this reconstructs the losing
    /// side from the same two sources it reads).
    private func runnersUp(day: Int, month: Int, year: Int, winnerPath: String) -> [Commemoration] {
        let resolver = SectionResolver(corpus: corpus, context: context)
        var results: [Commemoration] = []

        let temporalPath = Occurrence.temporalPath(day: day, month: month, year: year)
        if temporalPath != winnerPath,
            let rank = OfficeRank(rankFieldValue: resolver.resolveRank(path: temporalPath))
        {
            results.append(Commemoration(path: temporalPath, rank: rank))
        }

        for candidate in calendar.candidates(day: day, month: month, year: year) {
            let path = "Sancti/\(candidate)"
            guard path != winnerPath,
                let rank = OfficeRank(rankFieldValue: resolver.resolveRank(path: path))
            else { continue }
            results.append(Commemoration(path: path, rank: rank))
        }
        return results
    }

    // MARK: - §2a: today's own second Vespers wins

    /// `horascommon.pl:1373-1394`.
    private func ownVespersCommemorations(candidates: [Commemoration], winnerRank: OfficeRank) -> [Commemoration] {
        let resolver = SectionResolver(corpus: corpus, context: context)
        let winnerIsOrdinary = matches(winnerRank.title, "Dominica|feria|in.*octava")
        let ranklimit: Double =
            winnerIsOrdinary ? 2 : winnerRank.numericPrecedence >= 6 ? 4.2 : winnerRank.numericPrecedence >= 5 ? 2.1 : 2

        return candidates.filter { candidate in
            let isTemporal = candidate.path.hasPrefix("Tempora/")
            if isTemporal, candidate.rank.numericPrecedence < 2, candidate.rank.numericPrecedence != 1.15 {
                return false    // Feria minor has no Vespers once superseded.
            }
            if isTemporal, matches(candidate.rank.title, "Rogatio|Quattuor.*Sept") {
                return false    // Rogation days / September Ember days likewise.
            }

            let rule = resolver.resolve(path: candidate.path, section: "Rule")
            if matches(rule, "No secunda vespera") { return false }
            if candidate.rank.numericPrecedence < ranklimit, !Self.privilegedRanks.contains(candidate.rank.numericPrecedence) {
                return false
            }
            return true
        }
    }

    // MARK: - §2b: tomorrow's first Vespers pre-empts today's

    /// The displaced office (today's own occurrence winner), commemorated at the
    /// pre-empting Vespers -- `horascommon.pl:1401-1424`.
    private func displacedVespersCommemorations(
        candidates: [Commemoration], displacedRank: OfficeRank, winnerRank: OfficeRank
    ) -> [Commemoration] {
        let resolver = SectionResolver(corpus: corpus, context: context)
        let displacedIsOrdinary = matches(displacedRank.title, "Dominica|feria|in.*octava")
        let ranklimit: Double =
            (displacedRank.numericPrecedence >= 6 && !displacedIsOrdinary) ? 4.2
            : (displacedRank.numericPrecedence >= 5 && !displacedIsOrdinary) ? 2.99
            : 2

        return candidates.filter { candidate in
            let isTemporal = candidate.path.hasPrefix("Tempora/")
            if isTemporal, candidate.rank.numericPrecedence != 1.15 {
                if candidate.rank.numericPrecedence < 2 { return false }    // Feria minor / vigils.
                if matches(candidate.rank.title, "Rogatio|Quattuor.*Sept") { return false }
                if let sameOctave = octaveName(candidate.rank.title, prefix: "infra Octavam"),
                    let winnerOctave = octaveName(winnerRank.title, prefix: "in Octava"),
                    sameOctave.caseInsensitiveCompare(winnerOctave) == .orderedSame
                {
                    return false    // Absorbed into the octave day that follows it.
                }
            }

            let rule = resolver.resolve(path: candidate.path, section: "Rule")
            if matches(rule, "No secunda vespera") { return false }
            if matches(candidate.rank.title, "De VII di|Die VII infra") { return false }
            if candidate.rank.numericPrecedence < ranklimit, !Self.privilegedRanks.contains(candidate.rank.numericPrecedence) {
                return false
            }
            return true
        }
    }

    /// The winner's own other runners-up -- `horascommon.pl:1440-1462`. In 1960 this
    /// reduces to "only when the runner-up is itself a Sunday" (`docs/rubrics-1960-
    /// vespers.md` §2b spells out why: the version-gated `unless` clause that would
    /// otherwise admit a non-Sunday candidate is unconditionally false for any 196x
    /// version string).
    private func winnerRunnersUpCommemorations(candidates: [Commemoration], winnerRank: OfficeRank) -> [Commemoration] {
        let resolver = SectionResolver(corpus: corpus, context: context)
        let winnerIsOrdinary = matches(winnerRank.title, "Dominica|feria|in.*octava")
        let ranklimit: Double =
            winnerIsOrdinary ? 1.1 : winnerRank.numericPrecedence >= 6 ? 4.2 : winnerRank.numericPrecedence >= 5 ? 2.2 : 1.1

        return candidates.filter { candidate in
            let isTemporal = candidate.path.hasPrefix("Tempora/")
            let isSunday = matches(candidate.rank.title, "Dominica")
            if (isTemporal || matches(candidate.rank.title, "infra octavam")), !isSunday { return false }
            guard isSunday else { return false }    // The 1960-specific reduction, above.

            let rule = resolver.resolve(path: candidate.path, section: "Rule")
            if matches(rule, "No prima vespera") { return false }
            let isFeriaLike = matches(candidate.rank.title, "Feria|Sabbato|Vigilia|Quat[t]*uor Temp")
            let isOverride = matches(candidate.rank.title, "in Vigilia Epi|in octava|Dominica")
            if isFeriaLike, !isOverride { return false }
            if candidate.rank.numericPrecedence < ranklimit, !Self.privilegedRanks.contains(candidate.rank.numericPrecedence) {
                return false
            }
            return true
        }
    }

    // MARK: - Helpers

    private func matches(_ text: String, _ pattern: String) -> Bool {
        guard let regex = try? Regex("(?i)\(pattern)") else { return false }
        return (try? regex.firstMatch(in: text)) != nil
    }

    /// Captures the octave name following `prefix` (e.g. `"infra Octavam Nativitatis"`
    /// with `prefix == "infra Octavam"` gives `"Nativitatis"`), for comparing whether two
    /// titles name the same octave.
    private func octaveName(_ text: String, prefix: String) -> String? {
        guard let regex = try? Regex("(?i)\(prefix) (.+)") else { return nil }
        guard let match = try? regex.firstMatch(in: text) else { return nil }
        guard match.count > 1, let range = match[1].range else { return nil }
        return String(text[range])
    }
}
