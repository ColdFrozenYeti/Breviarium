import Foundation

/// Assembles the full Vespers `Hour` for one evening: decides which office is prayed
/// (`Concurrence`), resolves `Ordinarium/Vespera`'s skeleton (`SectionResolver` +
/// `ScriptMacros`), and fills in each section's real content from the winning office —
/// falling back to its Commune where the office doesn't define a section itself, the
/// same way DO's own real office files do (a Commune-only feast like `Sancti/01-18r`
/// defines only `[Officium]`/`[Rank]`/`[Rule]`/`[Oratio]`/its lessons, nothing else).
///
/// **Scope limits, flagged rather than silently assumed solved**
/// (`docs/rubrics-1960-vespers.md`'s "Content assembly" section has the full reasoning):
/// - `#Preces Feriales` isn't resolved at all yet — `horasscripts.pl`'s `preces()`
///   gating wasn't traced this session.
/// - The Commune fallback (`communeFallbackPath`) is a simplified heuristic (strip a
///   `"vide "`/`"ex "` prefix, treat a `"CN[-M]"` token as `Commune/CN[-M]`, anything
///   containing `"/"` as a direct path) — DO's own commune resolution has more
///   machinery (numbered sub-commons, per-section overrides) this doesn't reproduce.
/// - A ferial day with no proper `[Ant Vespera]` gets its psalms from the weekday
///   schedule but **without antiphons** — the ferial Psalter's own antiphon source
///   wasn't located this session; documented as a real gap, not silently dropped.
/// - `[Ant Vespera 3]` (the Magnificat antiphon) can list more than one candidate line
///   (rank/version-dependent choice, per real Commune files) — only the first is used;
///   the selection rule among them wasn't traced.
/// - Commemorations (`Commemorations.swift`) aren't folded into `#Oratio` yet — only
///   the winning office's own collect is included.
public struct HourAssembler {
    public var corpus: OfficeCorpus
    public var context: ConditionalContext
    public var calendar: SanctoralCalendar

    public init(corpus: OfficeCorpus, context: ConditionalContext, calendar: SanctoralCalendar) {
        self.corpus = corpus
        self.context = context
        self.calendar = calendar
    }

    public func assembleVespers(day: Int, month: Int, year: Int, priest: Bool) -> Hour? {
        let concurrence = Concurrence(corpus: corpus, context: context, calendar: calendar)
        guard let result = concurrence.resolve(day: day, month: month, year: year) else { return nil }
        let winner = result.vespersOffice

        let weekName: String
        if result.isFirstVespersOfTomorrow {
            let tomorrow = Computus.addDays(1, day: day, month: month, year: year)
            weekName = TemporalCycle.weekName(day: tomorrow.day, month: tomorrow.month, year: tomorrow.year)
        } else {
            weekName = TemporalCycle.weekName(day: day, month: month, year: year)
        }

        let winningRule = SectionResolver(corpus: corpus, context: context).resolve(path: winner.winningPath, section: "Rule")
        let macroContext = MacroContext(
            weekName: weekName, dayOfWeek: Computus.dayOfWeek(day: day, month: month, year: year), priest: priest,
            winningRank: winner.winningRank, winningRule: winningRule, isFirstVespers: result.isFirstVespersOfTomorrow
        )
        let resolver = SectionResolver(corpus: corpus, context: context, macroContext: macroContext)

        let skeletonText = resolver.resolve(path: "Ordinarium/Vespera", section: RawSectionParser.wholeFileSectionName)
        let skeletonLines = skeletonText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let groups = Self.groupSkeletonLines(skeletonLines)

        var sections: [Section] = []
        for group in groups {
            switch group.name {
            case "Incipit":
                sections.append(Section(kind: .introductio, units: Self.unitsFromLines(group.lines)))
            case "Psalmi":
                sections.append(assemblePsalmodia(office: winner.winningPath, resolver: resolver, macroContext: macroContext, dayOfWeek: macroContext.dayOfWeek))
            case "Canticum: Magnificat":
                sections.append(assembleMagnificat(office: winner.winningPath, resolver: resolver, macroContext: macroContext))
            case "Oratio":
                if let collect = resolveWithCommuneFallback(
                    office: winner.winningPath, communeReference: winner.winningRank.communeReference, section: "Oratio", resolver: resolver
                ) {
                    sections.append(Section(kind: .oratio, units: [.prose(collect)]))
                }
            case "Conclusio":
                sections.append(Section(kind: .conclusio, units: Self.unitsFromLines(group.lines)))
            case "Capitulum Hymnus Versus":
                sections.append(
                    contentsOf: assembleCapitulumHymnusVersus(office: winner.winningPath, resolver: resolver, macroContext: macroContext)
                )
            default:
                continue    // "#Preces Feriales" -- not yet resolved; see the type doc's scope limits.
            }
        }
        return Hour(sections: sections)
    }

    // MARK: - Skeleton grouping

    struct SkeletonGroup {
        var name: String
        var lines: [String]
    }

    /// Splits the skeleton's resolved lines at each `#Name` marker
    /// (`RawSectionParser`'s doc comment on `Ordinarium` files explains why these
    /// survive as literal content rather than being a parse-time header syntax).
    static func groupSkeletonLines(_ lines: [String]) -> [SkeletonGroup] {
        var groups: [SkeletonGroup] = []
        for line in lines {
            if line.hasPrefix("#") {
                groups.append(SkeletonGroup(name: String(line.dropFirst()), lines: []))
            } else if !groups.isEmpty {
                groups[groups.count - 1].lines.append(line)
            }
        }
        return groups
    }

    /// Converts a flat list of already-macro-resolved lines into `Unit`s: pairs
    /// consecutive `V.`/`R.` lines into `.versicleResponse`, splits a `*`-containing
    /// line into `.verse` halves (covers the `&Gloria`/`&Deus_in_adjutorium` doxology,
    /// which uses the identical convention), and treats everything else as `.prose`
    /// after stripping DO's own presentational line labels.
    static func unitsFromLines(_ lines: [String]) -> [Unit] {
        let nonBlank = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var units: [Unit] = []
        var i = 0
        while i < nonBlank.count {
            let line = nonBlank[i]
            if DOMarkers.isRubricLine(line) {
                units.append(.rubric(DOMarkers.stripRubricMarkers(line)))
                i += 1
            } else if line.hasPrefix("V.") && i + 1 < nonBlank.count && nonBlank[i + 1].hasPrefix("R.") {
                units.append(
                    .versicleResponse(versicle: DOMarkers.stripLineLabel(line), response: DOMarkers.stripLineLabel(nonBlank[i + 1]))
                )
                i += 2
            } else if line.contains(" * ") {
                let (first, second) = Psalm.splitHalves(DOMarkers.stripLineLabel(line))
                units.append(.verse(reference: "", firstHalf: first, secondHalf: second))
                i += 1
            } else {
                units.append(.prose(DOMarkers.stripLineLabel(line)))
                i += 1
            }
        }
        return units
    }

    // MARK: - Commune fallback

    /// A section this office doesn't define at all, falling back to its Commune.
    private func resolveWithCommuneFallback(office: String, communeReference: String, section: String, resolver: SectionResolver) -> String? {
        if resolver.sectionExists(path: office, section: section) {
            return resolver.resolve(path: office, section: section)
        }
        guard let fallbackPath = Self.communeFallbackPath(communeReference), resolver.sectionExists(path: fallbackPath, section: section)
        else { return nil }
        return resolver.resolve(path: fallbackPath, section: section)
    }

    static func communeFallbackPath(_ reference: String) -> String? {
        var ref = reference
        for prefix in ["vide ", "ex "] where ref.hasPrefix(prefix) {
            ref.removeFirst(prefix.count)
            break
        }
        guard !ref.isEmpty else { return nil }
        return ref.contains("/") ? ref : "Commune/\(ref)"
    }

    // MARK: - Psalmodia

    /// `"text;;psalmNumber"` lines (`[Ant Vespera]`/`[Ant Vespera 3]`'s format).
    private static func parseAntiphonPsalmPairs(_ text: String) -> [(antiphon: String, psalmNumber: String)] {
        text.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            let parts = line.components(separatedBy: ";;")
            guard parts.count >= 2, !parts[0].isEmpty else { return nil }
            return (parts[0], parts[1])
        }
    }

    private func assemblePsalmodia(office: String, resolver: SectionResolver, macroContext: MacroContext, dayOfWeek: Int) -> Section {
        let proper = resolveWithCommuneFallback(
            office: office, communeReference: macroContext.winningRank.communeReference, section: "Ant Vespera", resolver: resolver
        )
        let pairs: [(antiphon: String, psalmNumber: String)]
        if let proper, !proper.isEmpty {
            pairs = Self.parseAntiphonPsalmPairs(proper)
        } else {
            pairs = weekdayPsalmNumbers(dayOfWeek: dayOfWeek, resolver: resolver).map { (antiphon: "", psalmNumber: $0) }
        }

        var units: [Unit] = []
        for pair in pairs {
            if !pair.antiphon.isEmpty { units.append(.antiphon(pair.antiphon)) }
            units.append(contentsOf: psalmUnits(number: pair.psalmNumber, resolver: resolver, macroContext: macroContext))
            if !pair.antiphon.isEmpty { units.append(.antiphon(pair.antiphon)) }
        }
        return Section(kind: .psalmodia, units: units)
    }

    /// The ferial weekday psalm schedule (`Psalterium/Psalmi/Psalmi major.txt`'s
    /// `[DayN Vespera]`) — the fallback when the office defines no proper `[Ant
    /// Vespera]` of its own.
    private func weekdayPsalmNumbers(dayOfWeek: Int, resolver: SectionResolver) -> [String] {
        let text = resolver.resolve(path: "Psalterium/Psalmi/Psalmi major", section: "Day\(dayOfWeek) Vespera")
        return text.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            let parts = line.components(separatedBy: ";;")
            return parts.count >= 2 ? parts[1] : nil
        }
    }

    private func psalmUnits(number: String, resolver: SectionResolver, macroContext: MacroContext) -> [Unit] {
        let text = resolver.resolve(path: "Psalterium/Psalmorum/Psalm\(number)", section: RawSectionParser.wholeFileSectionName)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var units: [Unit] = Psalm.parseVerses(lines).map { .verse(reference: $0.reference, firstHalf: $0.firstHalf, secondHalf: $0.secondHalf) }
        units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext))
        return units
    }

    /// `&Gloria`'s two lines, each itself `*`-split like a psalm verse.
    private func gloriaUnits(resolver: SectionResolver, macroContext: MacroContext) -> [Unit] {
        let text = ScriptMacros.resolve("Gloria", context: macroContext, resolver: resolver) ?? ""
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let (first, second) = Psalm.splitHalves(DOMarkers.stripLineLabel(String(line)))
            return .verse(reference: "", firstHalf: first, secondHalf: second)
        }
    }

    // MARK: - Canticum: Magnificat

    private func assembleMagnificat(office: String, resolver: SectionResolver, macroContext: MacroContext) -> Section {
        var units: [Unit] = []
        if let proper = resolveWithCommuneFallback(
            office: office, communeReference: macroContext.winningRank.communeReference, section: "Ant Vespera 3", resolver: resolver
        ), let firstLine = proper.split(separator: "\n", omittingEmptySubsequences: false).first {
            let antiphon = String(firstLine).components(separatedBy: ";;").first ?? String(firstLine)
            if !antiphon.isEmpty {
                units.append(.antiphon(antiphon))
                units.append(contentsOf: magnificatVerses(resolver: resolver))
                units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext))
                units.append(.antiphon(antiphon))
                return Section(kind: .canticum, units: units)
            }
        }
        units.append(contentsOf: magnificatVerses(resolver: resolver))
        units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext))
        return Section(kind: .canticum, units: units)
    }

    /// The Magnificat canticle text lives alongside the psalms proper, in
    /// `Psalterium/Psalmorum/`, under the pseudo-psalm number `232`.
    private func magnificatVerses(resolver: SectionResolver) -> [Unit] {
        let text = resolver.resolve(path: "Psalterium/Psalmorum/Psalm232", section: RawSectionParser.wholeFileSectionName)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return Psalm.parseVerses(lines).map { .verse(reference: $0.reference, firstHalf: $0.firstHalf, secondHalf: $0.secondHalf) }
    }

    // MARK: - Capitulum / Hymnus / Versus

    /// Best-effort direct lookups (`[Capitulum Vespera]`, `[Hymnus Vespera]`, `[Versum
    /// 1]`, each independently, with the same Commune fallback as everything else) —
    /// unlike Psalmi/Magnificat, this wasn't traced closely enough to be confident the
    /// exact section names are right in every case (see the type doc's scope limits).
    /// A section that resolves nowhere (office or Commune) is simply omitted rather
    /// than emitted empty.
    private func assembleCapitulumHymnusVersus(office: String, resolver: SectionResolver, macroContext: MacroContext) -> [Section] {
        let communeReference = macroContext.winningRank.communeReference
        func lookup(_ section: String) -> String? {
            resolveWithCommuneFallback(office: office, communeReference: communeReference, section: section, resolver: resolver)
        }

        var sections: [Section] = []
        if let capitulum = lookup("Capitulum Vespera") {
            sections.append(Section(kind: .capitulum, units: [.prose(capitulum)]))
        }
        if let hymnus = lookup("Hymnus Vespera") {
            sections.append(Section(kind: .hymnus, units: [.prose(hymnus)]))
        }
        if let versus = lookup("Versum 1") {
            sections.append(Section(kind: .versus, units: Self.unitsFromLines(versus.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))))
        }
        return sections
    }
}
