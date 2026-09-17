import Foundation

/// Assembles the full Vespers `Hour` for one evening: decides which office is prayed
/// (`Concurrence`), resolves `Ordinarium/Vespera`'s skeleton (`SectionResolver` +
/// `ScriptMacros`), and fills in each section's real content from the winning office —
/// falling back to its Commune where the office doesn't define a section itself, the
/// same way DO's own real office files do (a Commune-only feast like `Sancti/01-18r`
/// defines only `[Officium]`/`[Rank]`/`[Rule]`/`[Oratio]`/its lessons, nothing else).
///
/// **Scope limits, flagged rather than silently assumed solved** (`docs/PLAN.md`'s M4
/// status has the full discovery-by-discovery reasoning for each):
/// - `#Preces Feriales` isn't resolved at all yet — `horasscripts.pl`'s `preces()`
///   gating wasn't traced.
/// - The Commune fallback (`communeFallbackPath`) is a simplified heuristic (strip a
///   `"vide "`/`"ex "` prefix, treat a `"CN[-M]"` token as `Commune/CN[-M]`, anything
///   containing `"/"` as a direct path) — confirmed right for a suffixed reference like
///   `"vide C6-1"` (a genuinely separate file, `Commune/C6-1.txt`), but a Commune can
///   *also* define numbered section variants within the *same* file (`[Oratio 3]`
///   alongside plain `[Oratio]`, confirmed real example: `Commune/C3.txt`, where two
///   specifically-named martyrs get `[Oratio 3]`/`[Ant 3]`/`[Ant Vespera 3]`/`[Versum
///   3]` instead of the unsuffixed forms) by a selection rule not yet identified — this
///   always resolves the unsuffixed form.
/// - Two further antiphon-source rules aren't handled: a later weekday reusing an
///   octave's shared temporal file (`Tempora/Nat1-0` covers every day of the Octave, not
///   just its first) incorrectly keeps that file's own proper antiphons instead of
///   falling back to the plain weekday's; Paschaltide replaces every psalm antiphon with
///   a plain "Allelúia," which this pass doesn't produce.
/// - `[Ant Vespera 3]` is *not* the Magnificat antiphon's fallback source (a wrong
///   assumption corrected after the numbered-sub-common discovery above — it's more
///   likely the antecapitulum text `Concurrence`'s "a capitulo" branch needs for a
///   *different* scenario entirely, concurrence, not plain Magnificat antiphon
///   selection); `assembleMagnificat` still tries it second, behind `[Ant 3]`, purely as
///   a harmless fallback, not because it's confirmed correct for any real case.
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
                    let named = substituteName(in: collect, office: winner.winningPath, resolver: resolver)
                    sections.append(Section(kind: .oratio, units: Self.unitsFromResolvedText(named)))
                }
            case "Conclusio":
                sections.append(Section(kind: .conclusio, units: Self.unitsFromLines(group.lines)))
            case "Capitulum Hymnus Versus":
                sections.append(
                    contentsOf: assembleCapitulumHymnusVersus(office: winner.winningPath, resolver: resolver, macroContext: macroContext)
                )
            case "Preces Feriales":
                if let section = assemblePrecesFeriales(winner: winner, month: month, resolver: resolver, macroContext: macroContext) {
                    sections.append(section)
                }
            default:
                continue
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

    /// Substitutes a `"N."`/`"N. et N."` placeholder in a generic Commune collect with
    /// the winning office's own saint name — DO's `replaceNdot()` (`specials.pl:778-817`),
    /// confirmed against the real oracle fixture for 5 February 2026 (`Sancti/02-05`,
    /// falling back to `Commune/C6`'s `"...beátæ N. Vírginis..."`, real rendered result
    /// `"...beátæ Agathæ Vírginis..."`). No-ops when `text` has no `"N."` at all (a
    /// proper collect that already names the saint directly, the common case) or the
    /// office defines no `[Name]` of its own.
    ///
    /// **Not ported:** the `"Oratio="`/`"Ant="`/`"Invit="`-tagged variant selection for
    /// names needing a different grammatical case depending on where they're
    /// substituted (real example found: `Sancti/02-05`'s own `[Name]` carries a
    /// `"Postcommunio=Agatha"` tag alongside the plain `"Agathæ"` — for a Mass proper,
    /// not our Office concern, but confirms the tagging convention is real and in use).
    /// Untagged names, the common case confirmed above, are unaffected by this gap.
    private func substituteName(in text: String, office: String, resolver: SectionResolver) -> String {
        guard text.contains("N."), resolver.sectionExists(path: office, section: "Name") else { return text }
        guard let name = resolver.resolve(path: office, section: "Name")
            .split(separator: "\n", omittingEmptySubsequences: false).first, !name.isEmpty
        else { return text }

        var result = text
        if let range = result.range(of: #"N\. .*? N\."#, options: .regularExpression) {
            result.replaceSubrange(range, with: name)
        }
        return result.replacingOccurrences(of: "N.", with: String(name))
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

    /// Confirmed against two real oracle fixtures (`docs/PLAN.md`'s M4 status has the
    /// full story): a `[Ant Vespera]` section can carry antiphons with **no**
    /// `;;psalmNumber` suffix at all, and that alone doesn't say whether the psalms are
    /// ferial or festal — two real communes both do it, for opposite reasons:
    ///
    /// - `Commune/C3.txt` (Several Martyrs): no numbers, and no `Psalm5 Vespera(3)=`
    ///   `[Rule]` entry either — genuinely "ferial," these antiphons replace whichever
    ///   psalms the weekday already assigns (`Sancti/09-16`, Ss. Cornelii et Cypriani).
    /// - `Commune/C6.txt` (Virgins) and `Sancti/02-05` (S. Agatha) itself: no numbers,
    ///   but a `Psalm5 Vespera3=147` `[Rule]` entry — the classic festal convention
    ///   where Vespers' first four psalms are always the Sunday set (109-112) and only
    ///   the fifth is proper, given by that `[Rule]` entry. Confirmed exactly against
    ///   the real fixture for 5 February 2026: psalms 109, 110, 111, 112, **147** (not
    ///   the plain `Psalm5 Vespera=116` entry the same `[Rule]` also carries — `"…
    ///   Vespera3="` is what applies when today's own second Vespers wins, matching
    ///   `Concurrence`'s `isFirstVespersOfTomorrow == false`; the unsuffixed `"…
    ///   Vespera="` presumably covers first Vespers instead, not independently
    ///   confirmed).
    ///
    /// Only when *neither* signal is present (no numbers and no `Psalm5` rule) does this
    /// fall through to the ferial weekday schedule, same as no `[Ant Vespera]` at all. A
    /// `[Ant Vespera]` whose lines *do* carry `;;number` directly (real example:
    /// `Commune/C6.txt` for higher ranks, presumably — not independently confirmed) is
    /// still treated as fully proper and skips both of the above.
    private func assemblePsalmodia(office: String, resolver: SectionResolver, macroContext: MacroContext, dayOfWeek: Int) -> Section {
        let communeReference = macroContext.winningRank.communeReference
        let proper = resolveWithCommuneFallback(office: office, communeReference: communeReference, section: "Ant Vespera", resolver: resolver)
        var pairs = proper.map(Self.parseAntiphonPsalmPairs) ?? []

        if pairs.isEmpty, let antiphonText = proper,
            let fifthPsalm = festalFifthPsalmNumber(
                office: office, communeReference: communeReference, resolver: resolver, isFirstVespers: macroContext.isFirstVespers
            )
        {
            let antiphons = antiphonText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).filter { !$0.isEmpty }
            let festalNumbers = ["109", "110", "111", "112", fifthPsalm]
            pairs = zip(antiphons, festalNumbers).map { ($0, $1) }
        }

        var usedWeekdaySchedule = false
        if pairs.isEmpty {
            usedWeekdaySchedule = true
            let weekdayText = resolver.resolve(path: "Psalterium/Psalmi/Psalmi major", section: "Day\(dayOfWeek) Vespera")
            pairs = Self.parseAntiphonPsalmPairs(weekdayText)
        }

        // Ports `psalmi.pl:627-644`'s Paschaltide-Alleluia replacement for the case
        // it's confirmed correct for: no office/Commune `[Ant Vespera]` exists at all
        // (`usedWeekdaySchedule`, our equivalent of `!exists($winner{"Ant $hora"})`'s
        // primary clause -- with nothing found, `$communetype !~ /ex/i` is vacuously
        // true too, so this case needs no further gating). Confirmed against the real
        // oracle fixture for 20 April 2026 (a plain Paschaltide ferial Monday, IV.
        // classis, no Sancti office): the rendered antiphon before *and* after all
        // five psalms is exactly `alleluia_ant()`'s "Allelúia, * allelúia, allelúia."
        // (open) / "Allelúia, allelúia, allelúia." (close, no asterisk) -- this project
        // already stores one antiphon string for both ends (confirmed harmless by the
        // Agatha oracle test's own five *distinct* antiphons, each of which also drops
        // the asterisk on DO's real closing repeat), so the asterisk form is kept for
        // both here rather than modelling DO's open/close distinction separately.
        //
        // **Not covered**: `psalmi.pl`'s other OR-branch, `$commune =~ /C10/` -- a
        // Sunday within Paschaltide using the Common-of-Sundays still gets replaced
        // even when that commune *does* supply generic antiphons (so `pairs` wouldn't
        // be empty and this check wouldn't fire). No real fixture for that exact case
        // has been checked yet; flagged rather than guessed at.
        if usedWeekdaySchedule, macroContext.weekName.range(of: "Pasc", options: .caseInsensitive) != nil {
            let alleluia = alleluiaAntiphon(resolver: resolver)
            pairs = pairs.map { (antiphon: alleluia, psalmNumber: $0.psalmNumber) }
        }

        var units: [Unit] = []
        for pair in pairs {
            units.append(.antiphon(pair.antiphon))
            units.append(contentsOf: psalmUnits(number: pair.psalmNumber, resolver: resolver, macroContext: macroContext))
            units.append(.antiphon(pair.antiphon))
        }
        return Section(kind: .psalmodia, units: units)
    }

    /// Ports `alleluia_ant()`'s plain (non-GABC) form (`"$u, * $l, $l."`,
    /// `LanguageTextTools.pm:120-129`), reusing `alleluia()`'s own bare-word extraction
    /// (`"v. Allelúia."` → `"Allelúia"`, stripping the `v.` label and trailing period)
    /// rather than `ScriptMacros`'s `&Alleluia` macro, which returns the Incipit's full
    /// versicle/response pair (or the Lenten `"Laus tibi"` swap), not the bare word.
    private func alleluiaAntiphon(resolver: SectionResolver) -> String {
        let text = resolver.resolve(path: SectionResolver.prayersPath, section: "Alleluia")
        let firstLine = text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        var word = DOMarkers.stripLineLabel(firstLine)
        if word.hasSuffix(".") { word.removeLast() }
        let lower = word.lowercased()
        return "\(word), * \(lower), \(lower)."
    }

    /// The `[Rule]` field's `"Psalm5 Vespera3=NNN"` (today's own second Vespers,
    /// preferred) or `"Psalm5 Vespera=NNN"` (fallback, presumably first Vespers) entry —
    /// see `assemblePsalmodia`'s doc comment for the confirmed real example.
    private func festalFifthPsalmNumber(
        office: String, communeReference: String, resolver: SectionResolver, isFirstVespers: Bool
    ) -> String? {
        guard let ruleText = resolveWithCommuneFallback(
            office: office, communeReference: communeReference, section: "Rule", resolver: resolver
        ) else { return nil }
        let preferredKey = isFirstVespers ? "Psalm5 Vespera=" : "Psalm5 Vespera3="
        let fallbackKey = isFirstVespers ? "Psalm5 Vespera3=" : "Psalm5 Vespera="
        return Self.value(forRuleKey: preferredKey, in: ruleText) ?? Self.value(forRuleKey: fallbackKey, in: ruleText)
    }

    private static func value(forRuleKey key: String, in ruleText: String) -> String? {
        for line in ruleText.split(separator: "\n") where line.hasPrefix(key) {
            return String(line.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
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

    // MARK: - Preces Feriales

    /// Ports `preces()`'s condition (`specials/preces.pl:7-71`) for the branches 1960
    /// Vespers actually reaches — dropping the Cistercian/monastic (`C12`) and
    /// pre-1955-vigil branches, and the separate "Dominicales" case (`preces()`'s second
    /// half), which is a Completorium concern, not Vespers.
    ///
    /// Confirmed against two real oracle fixtures: 16 September 2026 (a Wednesday, but
    /// a *Sancti* office wins — `"Preces Feriales{omittitur}"` in the real output,
    /// matching the `!winner.winningPath.hasPrefix("Sancti/")` guard below) and 18
    /// February 2026 (Ash Wednesday, temporal Feria wins — real preces text present,
    /// including the literal, un-filled `"Papa nostro N."` DO itself never resolves,
    /// confirming there's no dynamic "who is the reigning Pope" data source to miss).
    ///
    /// The rank guard ports `$duplex` itself (`horascommon.pl:1818`: `$vrank[1] !~
    /// /duplex/i ? 1 : $vrank[1] =~ /semiduplex/i ? 2 : 3`), which classifies by the
    /// **title text**, not `numericPrecedence` — Ash Wednesday's own `[Rank]` is
    /// `;;Feria privilegiata;;7` (a privileged feria deliberately given a *high* numeric
    /// precedence so it resists being superseded in occurrence, confirmed against the
    /// real `Tempora/Quadp3-3.txt`), so a precedence-based tier cutoff wrongly excluded
    /// it. Only a title genuinely containing "duplex" (and not "semiduplex") is excluded.
    private func shouldShowPrecesFeriales(winner: OccurrenceResult, weekName: String, dayOfWeek: Int, month: Int, rule: String) -> Bool {
        guard !winner.winningPath.hasPrefix("Sancti/") else { return false }
        guard rule.range(of: "Omit.*? Preces", options: [.regularExpression, .caseInsensitive]) == nil else { return false }
        guard weekName.range(of: "Pasc[67]", options: [.regularExpression, .caseInsensitive]) == nil else { return false }

        let title = winner.winningRank.title
        let isDuplexOrHigher = title.range(of: "duplex", options: .caseInsensitive) != nil
            && title.range(of: "semiduplex", options: .caseInsensitive) == nil
        guard !isDuplexOrHigher else { return false }
        guard dayOfWeek != 0, dayOfWeek != 6 else { return false }    // Not Sunday, not Saturday (first Vespers of Sunday).

        let ember = isEmberDay(weekName: weekName, dayOfWeek: dayOfWeek, month: month, winningRankTitle: winner.winningRank.title)
        let seasonal = rule.range(of: "Preces", options: .caseInsensitive) != nil
            || weekName.range(of: "Adv|Quad(?!p)", options: .regularExpression) != nil
            || ember
        guard seasonal else { return false }

        // 1960: restricted to Wednesdays, Fridays, and Ember days even within a
        // qualifying season.
        return dayOfWeek == 3 || dayOfWeek == 5 || ember
    }

    /// Ports `emberday()` (`horascommon.pl:1527-1542`).
    private func isEmberDay(weekName: String, dayOfWeek: Int, month: Int, winningRankTitle: String) -> Bool {
        guard dayOfWeek == 3 || dayOfWeek == 5 || dayOfWeek == 6 else { return false }
        if weekName.range(of: "Adv3|Quad1|Pasc7", options: [.regularExpression, .caseInsensitive]) != nil { return true }
        guard month == 9 else { return false }
        return winningRankTitle.range(of: "Quat[t]*uor", options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Resolves `Psalterium/Special/Major Special.txt`'s own `[Preces feriales
    /// Vespera]` wrapper (`$Kyrie` / `$Pater noster Et` / `$Preces feriales Vespera` /
    /// `$Domine exaudi`) through the same `SectionResolver` every other section uses —
    /// the `$Preces ` sigil dispatch (`SectionResolver.sigilPaths`) is what makes the
    /// wrapper's middle line resolve to `Preces.txt`'s real verse text instead of
    /// recursing on its own section name.
    private func assemblePrecesFeriales(winner: OccurrenceResult, month: Int, resolver: SectionResolver, macroContext: MacroContext) -> Section? {
        guard shouldShowPrecesFeriales(
            winner: winner, weekName: macroContext.weekName, dayOfWeek: macroContext.dayOfWeek, month: month, rule: macroContext.winningRule
        ) else { return nil }

        let text = resolver.resolve(path: "Psalterium/Special/Major Special", section: "Preces feriales Vespera")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return Section(kind: .precesFeriales, units: Self.unitsFromPrecesLines(lines))
    }

    /// Like `unitsFromLines`, plus two conventions confirmed real against the
    /// Pope/Bishop versicles (`Psalterium/Special/Preces.txt`):
    ///
    /// - `/:...:/ ` wraps DO's own small-font footnote text (`horas.pl:190`:
    ///   `$line =~ s{/:(.*?):/}{setfont($smallfont, $1)}eg` — found this time by
    ///   actually searching `horas.pl` itself, not just `specials.pl`/
    ///   `SetupString.pl` as an earlier pass claimed). Rendered here as `.rubric`,
    ///   matching DO's own "smaller, set apart" treatment, not an arbitrary choice.
    /// - A line ending in `~` is merged into the *next* line with a single space
    ///   (`horas.pl:117`, `$merge_with_next = ($line =~ s/~$//)`, confirmed by
    ///   `horas.pl:195-200`'s own merge-and-finalise logic) — real example: "Orémus pro
    ///   beatíssimo Papa nostro~" + "r. N." is one versicle, "Orémus pro beatíssimo
    ///   Papa nostro N.", not two separate lines. The lowercase `r.` here is DO's
    ///   drop-cap-style marker for the merged fragment's first letter
    ///   (`horas.pl:178`), not a real response — `DOMarkers.stripLineLabel` already
    ///   strips it like any other label.
    private static func unitsFromPrecesLines(_ lines: [String]) -> [Unit] {
        let nonBlank = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        var merged: [String] = []
        var pending: String?
        for line in nonBlank {
            if line.hasSuffix("~") {
                let base = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
                pending = pending.map { "\($0) \(base)" } ?? base
            } else if let accumulated = pending {
                merged.append("\(accumulated) \(DOMarkers.stripLineLabel(line))")
                pending = nil
            } else {
                merged.append(line)
            }
        }
        if let leftover = pending { merged.append(leftover) }

        var units: [Unit] = []
        var i = 0
        while i < merged.count {
            let line = merged[i]
            if line.hasPrefix("/:"), line.hasSuffix(":/") {
                units.append(.rubric(String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)))
                i += 1
            } else if line.hasPrefix("V.") && i + 1 < merged.count && merged[i + 1].hasPrefix("R.") {
                units.append(
                    .versicleResponse(versicle: DOMarkers.stripLineLabel(line), response: DOMarkers.stripLineLabel(merged[i + 1]))
                )
                i += 2
            } else {
                units.append(.prose(DOMarkers.stripLineLabel(line)))
                i += 1
            }
        }
        return units
    }
}
