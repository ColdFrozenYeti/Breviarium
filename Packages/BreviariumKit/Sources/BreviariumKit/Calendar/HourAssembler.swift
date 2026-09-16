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
                    sections.append(Section(kind: .oratio, units: Self.unitsFromResolvedText(collect)))
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

    /// Cleans a resolved multi-line prose block (a collect, e.g.) into one `.prose` unit
    /// per non-blank line, each with its own DO presentational label stripped. The
    /// `$Per Dominum` ending embeds a decorative lowercase `r.` continuation and a real
    /// `R.` response as separate lines within the *same* collect — DO's own rendering
    /// puts its `℟.` glyph directly between the collect's own end and "Amen." with no
    /// separating punctuation (confirmed against the real oracle fixture for 16
    /// September 2026), so keeping each source line as its own unit (rather than joining
    /// them into one string) is what keeps "Amen." independently findable there. Not
    /// `unitsFromLines`' full treatment (versicle/response pairing, `*`-verse
    /// splitting) — right for the skeleton, overkill for what's always plain prose here.
    static func unitsFromResolvedText(_ text: String) -> [Unit] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { DOMarkers.stripLineLabel(String($0)) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { .prose($0) }
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

    /// Confirmed against the real oracle fixture for 16 September 2026 (`docs/PLAN.md`'s
    /// M4 status has the full story): a `[Ant Vespera]` section can carry antiphons with
    /// **no** `;;psalmNumber` suffix at all (real example: `Commune/C3.txt`, the Common
    /// of Several Martyrs) — meaning "these replace the antiphons for whichever psalms
    /// the weekday already assigns," not "these come with their own proper psalms."
    /// Only a `[Ant Vespera]` whose lines *do* carry `;;number` (real example:
    /// `Commune/C6.txt`, giving genuinely different psalms) is treated as proper;
    /// anything else — including a section that exists but parses to zero pairs — falls
    /// through to the ferial weekday schedule, same as no section at all.
    private func assemblePsalmodia(office: String, resolver: SectionResolver, macroContext: MacroContext, dayOfWeek: Int) -> Section {
        let proper = resolveWithCommuneFallback(
            office: office, communeReference: macroContext.winningRank.communeReference, section: "Ant Vespera", resolver: resolver
        )
        var pairs = proper.map(Self.parseAntiphonPsalmPairs) ?? []
        if pairs.isEmpty {
            let weekdayText = resolver.resolve(path: "Psalterium/Psalmi/Psalmi major", section: "Day\(dayOfWeek) Vespera")
            pairs = Self.parseAntiphonPsalmPairs(weekdayText)
        }

        var units: [Unit] = []
        for pair in pairs {
            units.append(.antiphon(pair.antiphon))
            units.append(contentsOf: psalmUnits(number: pair.psalmNumber, resolver: resolver, macroContext: macroContext))
            units.append(.antiphon(pair.antiphon))
        }
        return Section(kind: .psalmodia, units: units)
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

    /// The Magnificat antiphon's actual source, confirmed against the real oracle
    /// fixture for 16 September 2026: for this rank (Semiduplex), it's `[Ant 3]` (a
    /// plain, unnumbered antiphon — real example: `Commune/C3.txt`'s own `[Ant 3]`,
    /// "Gaudent in cælis..."), **not** `[Ant Vespera 3]` (whose candidates all carry a
    /// `;;psalmNumber`-style tag — real example, the same file's `[Ant Vespera 3]`,
    /// "Isti sunt Sancti...;;109"), which this code tried first before that fixture
    /// caught it choosing the wrong one. `[Ant 3]` is tried first here, mirroring
    /// `assemblePsalmodia`'s confirmed pattern that an unnumbered antiphon is the
    /// general-purpose one and a numbered one is reserved for specific higher ranks --
    /// **not independently confirmed for this section** (only that `[Ant 3]` is right
    /// for *this* rank), so a higher-ranked feast that should actually get one of `[Ant
    /// Vespera 3]`'s numbered candidates is a known open question, not a closed one.
    private func assembleMagnificat(office: String, resolver: SectionResolver, macroContext: MacroContext) -> Section {
        var units: [Unit] = []
        let plain = resolveWithCommuneFallback(
            office: office, communeReference: macroContext.winningRank.communeReference, section: "Ant 3", resolver: resolver
        )
        let numbered = resolveWithCommuneFallback(
            office: office, communeReference: macroContext.winningRank.communeReference, section: "Ant Vespera 3", resolver: resolver
        )
        if let antiphon = (plain ?? numbered)?.split(separator: "\n", omittingEmptySubsequences: false).first
            .map({ String($0).components(separatedBy: ";;").first ?? String($0) }), !antiphon.isEmpty
        {
            units.append(.antiphon(antiphon))
            units.append(contentsOf: magnificatVerses(resolver: resolver))
            units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext))
            units.append(.antiphon(antiphon))
            return Section(kind: .canticum, units: units)
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
