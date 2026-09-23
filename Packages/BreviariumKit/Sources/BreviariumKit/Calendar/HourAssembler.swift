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
/// - The Commune fallback (`communeFallbackPath`) is a simplified heuristic (strip a
///   `"vide "`/`"ex "` prefix, treat a `"CN[-M]"` token as `Commune/CN[-M]`, anything
///   containing `"/"` as a direct path) — confirmed right for a suffixed reference like
///   `"vide C6-1"` (a genuinely separate file, `Commune/C6-1.txt`).
///   **A Commune's own numbered section variants** (`[Oratio 3]`/`[Ant 3]`/`[Ant
///   Vespera 3]`/`[Versum 3]` alongside the unsuffixed forms, real example:
///   `Commune/C3.txt`) are now resolved as `orationes.pl`/`psalmi.pl`'s own
///   first/second-Vespers index, not a count of named saints (both `[Oratio]` and
///   `[Oratio 3]` there carry the same "N. et N."). But the two aren't quite the same
///   rule: `[Oratio $ind]` falls back to the Commune unconditionally (confirmed real,
///   Ss. Cornelii et Cypriani's collect genuinely is `Commune/C3.txt`'s own `[Oratio
///   3]`), while `[Ant Vespera $ind]`'s Commune fallback is gated to `"ex"`-type
///   commune references only — the *same* office's real psalm antiphons are plain
///   ferial (`"vide C3"`, so the `3`-index never reaches the Commune at all), a
///   distinction only found after a first attempt applied the Oratio rule to
///   antiphons too and broke that fixture. `assembleMagnificat`'s `[Ant $ind]` lookup
///   turned out to follow the *unconditional* (Oratio-like) rule — also confirmed
///   real on the same office/fixture — superseding the earlier, never-confirmed
///   "antecapitulum"/concurrence guess for what `[Ant Vespera 3]` might be for.
///   See `assemblePsalmodia`'s own doc comment for the full citations.
/// - Commemorations (`Commemorations.swift` decides *which* offices; `assembleCommemorations`
///   below renders them) are folded into `#Oratio` for the single-commemoration case
///   confirmed against a real fixture (24 February 2026: a Lenten feria commemorated at
///   Vespers, `Ant.`/versicle-response/`Oratio` all appended after the winning office's
///   own collect). **Not ported**: `orationes.pl:662-669`'s second-class-or-higher,
///   second-Vespers-specific exclusion (a candidate whose own title doesn't name a major
///   season is dropped when the winner is high-ranked and this is second Vespers) —
///   no real fixture has been checked that would exercise it, so it's left unimplemented
///   and flagged here rather than guessed at; and the real priority-key sort
///   `orationes.pl:591-594`'s "1960: at most one commemoration on a high-ranked day" rule
///   uses to pick *which* survivor — `assembleCommemorations` keeps simply the first
///   candidate `Commemorations.resolve` returns, an approximation only confirmed
///   correct for the single-candidate case.
public struct HourAssembler {
    public var corpus: OfficeCorpus
    public var context: ConditionalContext
    public var calendar: SanctoralCalendar
    /// DO's own English tree (`DataBundle.english`/`makeEnglishCorpus()`) — `nil` means
    /// English wasn't supplied (e.g. the toggle is off, or a caller that only cares
    /// about Latin), in which case every `Unit`'s English field stays `nil` throughout.
    public var englishCorpus: OfficeCorpus?

    public init(corpus: OfficeCorpus, context: ConditionalContext, calendar: SanctoralCalendar, englishCorpus: OfficeCorpus? = nil) {
        self.corpus = corpus
        self.context = context
        self.calendar = calendar
        self.englishCorpus = englishCorpus
    }

    public func assembleVespers(day: Int, month: Int, year: Int, priest: Bool) -> Hour? {
        let concurrence = Concurrence(corpus: corpus, context: context, calendar: calendar)
        guard let result = concurrence.resolve(day: day, month: month, year: year) else { return nil }
        let winner = result.vespersOffice

        // On "Vespera de sequenti" (first Vespers of tomorrow's office wins), DO's own
        // whole rendering pass re-derives every date-dependent global -- `$dayname[0]`,
        // `$day`, `$month` -- from *tomorrow's* date, not the queried one; `get_tempus_id()`
        // (`tempusID`, ` tempore`'s own source) is one of them. `weekName` already made
        // this swap; `contentContext` mirrors it for `tempore`/`mense` so `(sed tempore
        // ...)` conditionals inside the winning office's own content -- not just the
        // season-fallback lookups `weekName` alone already drives -- see the season the
        // *winning* office is actually in, not the queried date's own season. Confirmed
        // real for 5 April 2025 (Saturday before Passion Sunday, "Vespera de sequenti"):
        // the real fixture's Vexilla Regis hymn shows its Passiontide-specific final
        // verse ("Hoc Passiónis témpore"), which only a `tempore` of `"Passionis"` (from
        // 6 April, Passion Sunday) rather than `"Quadragesimæ"` (from 5 April, still
        // Lent's 4th week) selects via the hymn's own `(sed tempore Passionis)` line.
        let weekName: String
        var contentContext = context
        if result.isFirstVespersOfTomorrow {
            let tomorrow = Computus.addDays(1, day: day, month: month, year: year)
            weekName = TemporalCycle.weekName(day: tomorrow.day, month: tomorrow.month, year: tomorrow.year)
            contentContext.mense = tomorrow.month
            contentContext.tempore = TemporalCycle.tempusID(
                weekName: weekName, rubrica: context.rubrica, month: tomorrow.month, day: tomorrow.day,
                dayOfWeek: Computus.dayOfWeek(day: tomorrow.day, month: tomorrow.month, year: tomorrow.year),
                isVespersOrCompline: true
            )
        } else {
            weekName = TemporalCycle.weekName(day: day, month: month, year: year)
        }

        let winningRule = SectionResolver(corpus: corpus, context: contentContext).resolve(path: winner.winningPath, section: "Rule")
        let macroContext = MacroContext(
            weekName: weekName, dayOfWeek: Computus.dayOfWeek(day: day, month: month, year: year), priest: priest,
            winningRank: winner.winningRank, winningRule: winningRule, isFirstVespers: result.isFirstVespersOfTomorrow
        )
        let resolver = SectionResolver(corpus: corpus, context: contentContext, macroContext: macroContext)

        let skeletonText = resolver.resolve(path: "Ordinarium/Vespera", section: RawSectionParser.wholeFileSectionName)
        let skeletonLines = skeletonText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let groups = Self.groupSkeletonLines(skeletonLines)

        // `Ordinarium/Vespera` is language-neutral scaffolding (shared, not duplicated
        // per language — see `BreviariumDataPipeline`'s own doc comment), so resolving
        // it again against an English-backed resolver walks the *same* `#Name`-grouped
        // structure, just with `&`/`$` macros bottoming out in English text instead.
        let englishResolver = englishCorpus.map { SectionResolver(corpus: $0, context: contentContext, macroContext: macroContext, isEnglish: true) }
        let englishGroups: [String: SkeletonGroup] = englishResolver.map { resolver in
            let text = resolver.resolve(path: "Ordinarium/Vespera", section: RawSectionParser.wholeFileSectionName)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            return Dictionary(Self.groupSkeletonLines(lines).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        } ?? [:]

        var sections: [Section] = []
        for group in groups {
            switch group.name {
            case "Incipit":
                guard !Self.ruleOmits(rule: macroContext.winningRule, keyword: "Incipit") else { continue }
                sections.append(Section(kind: .introductio, units: Self.unitsFromLines(group.lines, english: englishGroups[group.name]?.lines)))
            case "Psalmi":
                sections.append(assemblePsalmodia(
                    office: winner.winningPath, resolver: resolver, macroContext: macroContext, dayOfWeek: macroContext.dayOfWeek,
                    englishResolver: englishResolver
                ))
            case "Canticum: Magnificat":
                sections.append(assembleMagnificat(
                    office: winner.winningPath, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver,
                    day: day, month: month, year: year
                ))
            case "Oratio":
                // Ports orationes.pl:34,63-82's `$ind = $hora eq 'Vespera' ? $vespera : 2`
                // priority via `oratioLocation` -- see its own doc comment for the exact
                // office-then-Commune order (not a simple indexed-then-plain fallback).
                let ind = macroContext.isFirstVespers ? 1 : 3
                let oratioOffice = oratioDominicaOffice(rule: macroContext.winningRule, weekName: macroContext.weekName) ?? winner.winningPath
                let oratioLocation = oratioLocation(
                    office: oratioOffice, communeReference: winner.winningRank.communeReference, ind: ind, resolver: resolver,
                    weekName: macroContext.weekName
                )
                if let oratioLocation {
                    let collect = resolver.resolve(path: oratioLocation.path, section: oratioLocation.section)
                    var named = substituteName(in: collect, office: winner.winningPath, resolver: resolver)
                    // English only if it has this *exact* section too -- never a
                    // different (mismatched) one, per this case's own doc comment on
                    // `resolvedLocation`.
                    var englishCollect: String? = englishResolver.flatMap { eng in
                        guard eng.sectionExists(path: oratioLocation.path, section: oratioLocation.section) else { return nil }
                        let text = eng.resolve(path: oratioLocation.path, section: oratioLocation.section)
                        return substituteName(in: text, office: winner.winningPath, resolver: eng)
                    }
                    // `orationes.pl:216-222`'s own "Sub unica conclusione" handling: when
                    // several collects are said in series under one shared conclusion (the
                    // office's own `[Rule]` says so directly), 1960 drops the main
                    // collect's own closing doxology macro entirely (`$w =~ s/\$(Per|Qui)
                    // .*?\n//`) rather than moving it — whatever chained commemoration text
                    // follows within the *same* raw `[Oratio]` section (real example:
                    // `Sancti/02-22.txt`'s own `[Oratio]` chains the main collect, a `_`
                    // block-break, and a `!Commemoratio S. Pauli Apostoli`-headed second
                    // collect all in one section) supplies the one and only "...Amen." at
                    // its own end instead. Confirmed real for 22 February 2025 (In Cathedra
                    // S. Petri, `Rule`: "ex C4; ... Sub unica concl..."): the real fixture
                    // goes straight from the main collect's own "...néxibus liberémur:" to
                    // "Commemoratio S. Pauli Apostoli" with no "Qui vivis...Amen." at all in
                    // between. Applied unconditionally on the flag, not gated on whether
                    // `assembleCommemorations`'s own separate rank-based mechanism finds
                    // anything -- that's an unrelated system; the chained content here is
                    // already embedded in this same section's own raw text either way.
                    if macroContext.winningRule.range(of: "Sub unica conc", options: .caseInsensitive) != nil {
                        named = Self.strippingTrailingDoxologyMacro(named)
                        englishCollect = englishCollect.map(Self.strippingTrailingDoxologyMacro)
                    }
                    var oratioUnits = Self.unitsFromResolvedText(named, english: englishCollect)
                    if !Self.ruleOmits(rule: macroContext.winningRule, keyword: "Commemoratio") {
                        oratioUnits.append(contentsOf: assembleCommemorations(
                            day: day, month: month, year: year, winningRank: winner.winningRank, resolver: resolver, macroContext: macroContext
                        ))
                    }
                    sections.append(Section(kind: .oratio, units: oratioUnits))
                }
            case "Conclusio":
                guard !Self.ruleOmits(rule: macroContext.winningRule, keyword: "Conclusio") else { continue }
                sections.append(Section(kind: .conclusio, units: Self.unitsFromLines(group.lines, english: englishGroups[group.name]?.lines)))
            case "Capitulum Hymnus Versus":
                // `specials.pl:60-81`'s own "Capitulum Versum 2" replacement takes
                // priority over "Omit" when it fires: the whole Capitulum/Hymnus/Versus
                // group is replaced by a single `Versus (In loco Capituli)` section
                // built from the office's own `[Versum 2]` (falling back to Commune's),
                // whose content is itself an antiphon-formatted line, not a genuine
                // versicle/response pair. Confirmed real for 20 April 2025 (Easter
                // Sunday, whose own `Tempora/Pasc0-0.txt` `[Rule]` has a plain,
                // unqualified "Capitulum Versum 2;" -- contradicting an earlier
                // assumption here that no Vespers-relevant date has one unqualified;
                // that assumption held only for Holy Saturday's own "ad Laudes tantum"-
                // qualified rule, not the whole Easter Octave, which chain-extends
                // Pasc0-0's Rule via `Rule: ex Pasc0-0` and so shares it for all eight
                // days): the real fixture's own `[Versum 2]`, "Ant. Hæc dies * quam
                // fecit Dóminus: exsultémus et lætémur in ea.", replaces the normal
                // triad entirely.
                if let cv2Qualifier = Self.capitulumVersum2Qualifier(rule: macroContext.winningRule),
                    cv2Qualifier.range(of: "ad Laudes tantum", options: .caseInsensitive) == nil
                {
                    if let versus2 = resolvedLocation(
                        office: winner.winningPath, communeReference: winner.winningRank.communeReference, section: "Versum 2", resolver: resolver,
                        weekName: macroContext.weekName
                    ) {
                        let text = DOMarkers.stripLineLabel(resolver.resolve(path: versus2.path, section: versus2.section))
                        let english: String? = englishResolver.flatMap { eng in
                            eng.sectionExists(path: versus2.path, section: versus2.section)
                                ? DOMarkers.stripLineLabel(eng.resolve(path: versus2.path, section: versus2.section)) : nil
                        }
                        sections.append(Section(kind: .versus, units: [.antiphon(text, english: english)]))
                    }
                    continue
                }
                guard !Self.ruleOmits(rule: macroContext.winningRule, keyword: "Capitulum") else { continue }
                sections.append(contentsOf: assembleCapitulumHymnusVersus(
                    office: winner.winningPath, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver,
                    dayOfWeek: macroContext.dayOfWeek
                ))
            case "Preces Feriales":
                if let section = assemblePrecesFeriales(
                    winner: winner, month: month, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver
                ) {
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
    ///
    /// `englishLines` is the *same skeleton*, resolved against an English-backed
    /// `SectionResolver` instead — the Introductio/Conclusio prayers are fixed text
    /// (`Deus in adiutorium`, `Dominus vobiscum`, etc.), so the skeleton structure
    /// (line count, blank-line positions, which lines are `V.`/`R.` pairs) is identical
    /// regardless of language, and each non-blank Latin line pairs positionally with
    /// the English line at the same index. If the non-blank counts don't match (a
    /// signal something about that assumption broke for this particular date), English
    /// is dropped entirely for this call rather than risk pairing the wrong lines.
    static func unitsFromLines(_ lines: [String], english englishLines: [String]? = nil) -> [Unit] {
        let nonBlank = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let englishNonBlank = englishLines?.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let english = (englishNonBlank?.count == nonBlank.count) ? englishNonBlank : nil

        var units: [Unit] = []
        var i = 0
        while i < nonBlank.count {
            let line = nonBlank[i]
            let englishLine = english?[i]
            if DOMarkers.isRubricLine(line) {
                units.append(.rubric(DOMarkers.stripRubricMarkers(line), english: englishLine.map(DOMarkers.stripRubricMarkers)))
                i += 1
            } else if line.hasPrefix("V.") && i + 1 < nonBlank.count && nonBlank[i + 1].hasPrefix("R.") {
                units.append(.versicleResponse(
                    versicle: DOMarkers.stripLineLabel(line), response: DOMarkers.stripLineLabel(nonBlank[i + 1]),
                    versicleEnglish: englishLine.map(DOMarkers.stripLineLabel),
                    responseEnglish: english.map { DOMarkers.stripLineLabel($0[i + 1]) }
                ))
                i += 2
            } else if line.contains(" * ") {
                let (first, second) = Psalm.splitHalves(DOMarkers.stripLineLabel(line))
                let englishSplit = englishLine.map { Psalm.splitHalves(DOMarkers.stripLineLabel($0)) }
                units.append(.verse(
                    reference: "", firstHalf: first, secondHalf: second,
                    firstHalfEnglish: englishSplit?.first, secondHalfEnglish: englishSplit?.second
                ))
                i += 1
            } else {
                units.append(.prose(DOMarkers.stripLineLabel(line), english: englishLine.map(DOMarkers.stripLineLabel)))
                i += 1
            }
        }
        return units
    }

    /// Strips a resolved collect's own closing-doxology macro expansion (the `"Qui
    /// vivis..."`/`"Per Dóminum..."` line, plus its own following `"Amen."` response) --
    /// used only for `orationes.pl:216-222`'s own "Sub unica conclusione" case, where
    /// 1960 drops the *main* collect's own closing macro reference entirely before it's
    /// ever resolved (`$w =~ s/\$(Per|Qui) .*?\n//`, operating on the raw, unresolved
    /// text -- the substitution only ever touches the literal macro-reference line
    /// itself, never anything chained after it) rather than moving it, letting the
    /// chain's own final commemoration supply the one and only conclusion at its own
    /// end instead. Operating on the *resolved* text here (this project's
    /// `SectionResolver` has no public "raw, before macro expansion" fetch): finds the
    /// *first* line starting `"Qui "` or `"Per "` (matching the real regex's own
    /// alternation, after stripping its own leading `r. `/`v. ` drop-cap label --
    /// confirmed real: `Sancti/02-22.txt`'s own resolved `[Oratio]` reads `"r. Qui vivis
    /// et regnas..."`, not a bare `"Qui "` line) and removes only that line and its own
    /// immediately-following `"Amen."` response — *not* `lastIndex`, which would
    /// instead find and strip the *chain's own final* doxology (real example: this
    /// office's own chained `Commemoratio S. Pauli` collect ends the *same* way,
    /// "...r. Per Dóminum...R. Amen.", so a last-match search removes exactly the wrong
    /// one).
    private static func strippingTrailingDoxologyMacro(_ text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let index = lines.firstIndex(where: { line in
            let stripped = DOMarkers.stripLineLabel(line)
            return stripped.hasPrefix("Qui ") || stripped.hasPrefix("Per ")
        }) else { return text }
        var removeCount = 1
        if index + 1 < lines.count, DOMarkers.stripLineLabel(lines[index + 1]).hasPrefix("Amen") {
            removeCount += 1
        }
        lines.removeSubrange(index..<min(index + removeCount, lines.count))
        return lines.joined(separator: "\n")
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
    /// `english`: the same collect resolved against an English-backed resolver — paired
    /// line-for-line with the Latin lines when the (post-filtering) line counts match,
    /// matching `CLAUDE.md`'s "everything else by whole unit" alignment rule for prose
    /// (a collect's `$Per Dominum` ending is its own separate line/unit on both sides,
    /// per `HourAssembler`'s own doc comment on why this doesn't join into one string).
    static func unitsFromResolvedText(_ text: String, english: String? = nil) -> [Unit] {
        // A bare `_`-only line is DO's own general block-break marker (the same
        // convention `hymnStanzas` already treats as a stanza boundary, dropped rather
        // than shown) -- real example, `Sancti/02-22`'s own `[Oratio]`: a lone `_` line
        // sits between the main collect's own `$Qui vivis` ending and the `@...
        // :Commemoratio4` cross-reference that follows it, purely to separate the two
        // blocks. Previously rendered as a literal `"_"` line of its own, since this
        // function's own blank-line filter only ever checked for *empty* lines.
        func isBlockBreak(_ line: String) -> Bool { line.trimmingCharacters(in: .whitespaces) == "_" }
        let latinLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { DOMarkers.stripLineLabel(String($0)) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !isBlockBreak($0) }
        let englishLines = english?.split(separator: "\n", omittingEmptySubsequences: false)
            .map { DOMarkers.stripLineLabel(String($0)) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !isBlockBreak($0) }
        let paired = (englishLines?.count == latinLines.count) ? englishLines : nil

        // A collect can carry its own inline `!text` rubric note (`do-format.md`'s
        // `!text` -> red rubric line convention) -- real example, `Quad6-6r`'s own
        // `[Oratio Matutinum]`: "!Et sub silentio concluditur" between Holy Saturday
        // Vespers' own collect and its "Per eúndem..." ending. Previously rendered as
        // plain prose with the leading "!" shown literally, since this function (unlike
        // `unitsFromLines`) never checked `DOMarkers.isRubricLine`.
        return latinLines.enumerated().map { index, line in
            if DOMarkers.isRubricLine(line) {
                return .rubric(DOMarkers.stripRubricMarkers(line), english: (paired?[index]).map(DOMarkers.stripRubricMarkers))
            }
            return .prose(line, english: paired?[index])
        }
    }

    // MARK: - Commune fallback

    /// The `(path, section)` that actually satisfies a Commune-fallback lookup for
    /// Latin — office first, then Commune — so a caller needing the *same* content in
    /// another language can query that exact location instead of re-running its own
    /// fallback chain. Confirmed necessary against the real bilingual fixture for 16
    /// September 2026: `Commune/C3.txt`'s English tree has no `[Oratio 3]` at all (only
    /// the plain `[Oratio]`), and DO's own real behaviour when a language lacks a
    /// specific section entirely is to leave that piece in Latin — not substitute a
    /// *different*, wrong section (the plain English `[Oratio]`, an unrelated collect)
    /// in the requested language. Re-deriving English's own independent fallback chain
    /// (indexed, then plain) did exactly that; querying English at Latin's own winning
    /// `(path, section)` and returning `nil` when it's absent there instead matches DO.
    /// Follows `office`'s own content first, then its Commune reference — daisy-chaining
    /// through as many further `;;ex|vide ...`-tagged "Pseudo-Commune" hops as needed,
    /// capped at 5 total like `getproprium`'s own `$loopcounter < 5`
    /// (`specials.pl:474-508`: "if Pseudo-Commune ex Sancti, ensure daisy-chained
    /// references work"). Real, confirmed example: `Tempora/Nat02` ("Die Secunda
    /// Ianuarii") has no `[Hymnus Vespera]` of its own, and its own `[Rank]` names
    /// `"vide Sancti/01-01"` — but `Sancti/01-01` (In Circumcisione Domini) *also* has
    /// none of its own, and its own 1960-rubric `[Rank]` names a further
    /// `"ex Sancti/12-25"` (Christmas Day) — which finally has the real hymn ("Iesu,
    /// Redémptor ómnium..."). A single-hop version stopped at `Sancti/01-01`, found
    /// nothing, and gave up. Found via a full 2025-2040 sweep: this single-hop gap left
    /// ~3,900 days' worth of Hymnus (and, through the same shared lookup, a large share
    /// of Capitulum/Versus/Oratio/Magnificat-antiphon) content wrong across every date
    /// whose commune chain needed more than one hop.
    private func resolvedLocation(
        office: String, communeReference: String, section: String, resolver: SectionResolver, weekName: String
    ) -> (path: String, section: String)? {
        if resolver.sectionExists(path: office, section: section) { return (office, section) }
        return Self.communeChainLocation(communeReference: communeReference, section: section, resolver: resolver, weekName: weekName)
    }

    /// The Commune-daisy-chain half of `resolvedLocation`, factored out so
    /// `oratioLocation` can reuse the exact same chain-walking without re-checking the
    /// office's own content first (its own real priority order needs the office check
    /// done differently — see its own doc comment).
    private static func communeChainLocation(
        communeReference: String, section: String, resolver: SectionResolver, weekName: String
    ) -> (path: String, section: String)? {
        var reference = communeReference
        var hops = 0
        while hops < 5 {
            guard let candidatePath = Self.paschalCommuneFallbackPath(reference, weekName: weekName, resolver: resolver) else { return nil }
            if resolver.sectionExists(path: candidatePath, section: section) { return (candidatePath, section) }

            guard let nextReference = OfficeRank(rankFieldValue: resolver.resolveRank(path: candidatePath))?.communeReference,
                !nextReference.isEmpty, nextReference != reference
            else { return nil }
            reference = nextReference
            hops += 1
        }
        return nil
    }

    /// Ports `orationes.pl:63-82`'s own real priority order for the main Oratio — subtly
    /// different from `resolvedLocation`'s "one section, office-then-commune" shape, and
    /// wrong to model as a simple `resolvedLocation(section: indexed) ??
    /// resolvedLocation(section: plain)` fallback (this project's own earlier code did
    /// exactly that): the *office's own* indexed `[Oratio N]` only overrides the
    /// *office's own* plain `[Oratio]` (`$w = $w{Oratio}; ... elsif (!$w ||
    /// exists($winner{"Oratio $ind"})) { $w = $w{"Oratio $ind"}; }` — both read from
    /// `%winner`, never the Commune, at this stage) — the Commune is only ever consulted
    /// afterwards, and only if the office has *neither* (`if (!$w) { ... look in commune
    /// ... }`), trying the Commune's own indexed Oratio first, then the *opposite*
    /// Vespers/Laudes index (`$i = 4 - $i`), then finally the Commune's own plain one.
    ///
    /// The earlier, wrong ordering let a Commune's own generic indexed Oratio (e.g.
    /// `Commune/C2`'s own `[Oratio 3]`, a "Common of Several Martyrs" collect with no
    /// name substituted in) win over the *office's own* plain `[Oratio]` even when that
    /// office's own file had a perfectly good one — confirmed real for 20 January 2025
    /// (Ss. Fabian and Sebastian): `Sancti/01-20`'s own plain `[Oratio]` is `@Commune/
    /// C2::s/beáti N\. Mártyris tui atque Pontíficis/beatórum Mártyrum tuórum Fabiáni et
    /// Sebastiáni/` (a same-file-resolvable, name-substituted collect this project's own
    /// resolver already handles correctly *when actually reached*), but the previous
    /// priority order found `Commune/C3`'s own generic `[Oratio 3]` first instead (Ss.
    /// Fabian and Sebastian's own `[Rank]` names `"vide C3"`), rendering the wrong,
    /// unsubstituted "N. et N." text. Found via a full 2025-2040 content audit as the
    /// single largest share of the ~1,176 remaining Oratio mismatches at the time.
    private func oratioLocation(
        office: String, communeReference: String, ind: Int, resolver: SectionResolver, weekName: String
    ) -> (path: String, section: String)? {
        if resolver.sectionExists(path: office, section: "Oratio \(ind)") { return (office, "Oratio \(ind)") }
        if resolver.sectionExists(path: office, section: "Oratio") { return (office, "Oratio") }

        for section in ["Oratio \(ind)", "Oratio \(4 - ind)", "Oratio"] {
            if let location = Self.communeChainLocation(communeReference: communeReference, section: section, resolver: resolver, weekName: weekName) {
                return location
            }
        }

        // `orationes.pl:115-120`'s own final catch-all — general, not gated on any
        // `[Rule]` text (unlike `oratioDominicaOffice`'s own literal `"Oratio
        // Dominica"` trigger, a *different*, narrower real mechanism near the top of
        // the same real function): whenever the winning office is a `Tempora/` path
        // and nothing above found an Oratio at all (office's own, Commune's own), DO
        // falls back to that same week's own Sunday file's plain `[Oratio]`, or
        // failing that, its `[Oratio 2]` — never `[Oratio $ind]`/`[Oratio (4-$ind)]`,
        // just these two fixed keys. Confirmed real for 8 June 2026 (Monday, "Feria II
        // infra Hebdomadam II post Octavam Pentecostes", an ordinary low-rank feria
        // whose own winning `[Rank]` variant under 1960 has *no* Commune reference at
        // all — `;;Feria;;1`, no fourth field — and no `[Oratio]` of its own):
        // `Tempora/Pent02-0.txt`'s own `[Oratio]` ("Sancti nóminis tui, Dómine...") is
        // exactly the real fixture's own text. Found via a full 2025-2040 content
        // audit: this gap alone left 24 real dates with *no* Oratio rendered at all
        // (a silently empty section, not a wrong one).
        if office.hasPrefix("Tempora/") {
            let sundayPath = "Tempora/\(weekName)-0"
            if resolver.sectionExists(path: sundayPath, section: "Oratio") { return (sundayPath, "Oratio") }
            if resolver.sectionExists(path: sundayPath, section: "Oratio 2") { return (sundayPath, "Oratio 2") }
        }
        return nil
    }

    // MARK: - Commemorations

    /// The `Ant.`/versicle-response/`Oratio` block(s) appended after the winning
    /// office's own collect for whichever office(s) `Commemorations.resolve` says are
    /// commemorated tonight — `orationes.pl`'s own `getcommemoratio()` (specials/
    /// orationes.pl:645-822), confirmed against the real fixture for 24 February 2026
    /// (a Lenten feria commemorated at the Vespers of whatever won that day): right
    /// after the main Oratio's own "...Amen.", the real page reads "Commemoratio Feria
    /// Tertia infra Hebdomadam I in Quadragesima / Ant. Scriptum est enim... / ℣.
    /// Ángelis suis Deus mandávit de te. / ℟. Ut custódiant te in ómnibus viis tuis. /
    /// Orémus. Ascéndant ad te, Dómine, preces nostræ...".
    ///
    /// English is deliberately not threaded through here (`SettingsView`'s own "Coming
    /// in beta" note) -- every `Unit` this emits carries `english: nil`.
    private func assembleCommemorations(
        day: Int, month: Int, year: Int, winningRank: OfficeRank, resolver: SectionResolver, macroContext: MacroContext
    ) -> [Unit] {
        let commemorations = Commemorations(corpus: corpus, context: context, calendar: calendar).resolve(day: day, month: month, year: year)
        guard !commemorations.isEmpty else { return [] }

        // orationes.pl:585-594: "Under the 1960 rubrics, on II. cl and higher days,
        // allow at most one commemoration." Real DO picks the survivor via a numeric
        // priority key (Sunday/octave/etc.) this doesn't reconstruct -- keeping the
        // first candidate is an approximation, confirmed only for the single-candidate
        // case (24 February 2026 above never exercises this reduction at all, since it
        // has just one commemoration to begin with).
        let winnerIsFeriaLike = winningRank.title.range(of: "Feria|Sabbato|Vigilia", options: [.regularExpression, .caseInsensitive]) != nil
        let mustReduceToOne = winningRank.numericPrecedence >= 5 || (winnerIsFeriaLike && winningRank.numericPrecedence >= 4)
        let toRender = mustReduceToOne ? Array(commemorations.prefix(1)) : commemorations

        return toRender.flatMap { commemorationUnits(for: $0, ind: $0.ind, weekName: macroContext.weekName, resolver: resolver) ?? [] }
    }

    /// One commemorated office's own `Ant $ind`/`Versum $ind`/`Oratio $ind` (each
    /// falling back to its own `4 - ind` form, then its Commune, exactly like the
    /// winning office's own `Oratio` and `assembleMagnificat`'s `Ant $ind` already do --
    /// `orationes.pl:756-769` for the antiphon, `:791-803` for the versicle, `:719-732`
    /// for the collect). `nil` when any of the three can't be resolved at all, rather
    /// than rendering a partial block.
    private func commemorationUnits(for commemoration: Commemoration, ind: Int, weekName: String, resolver: SectionResolver) -> [Unit]? {
        let communeReference = commemoration.rank.communeReference

        func location(_ section: String) -> (path: String, section: String)? {
            resolvedLocation(office: commemoration.path, communeReference: communeReference, section: section, resolver: resolver, weekName: weekName)
        }

        guard let antiphonLocation = location("Ant \(ind)") ?? location("Ant \(4 - ind)") else { return nil }
        let rawAntiphonText = resolver.resolve(path: antiphonLocation.path, section: antiphonLocation.section)
            .split(separator: "\n", omittingEmptySubsequences: false).first
            .map { String($0).components(separatedBy: ";;").first ?? String($0) }
        guard var antiphonText = rawAntiphonText, !antiphonText.isEmpty else { return nil }
        // orationes.pl:818: "$a =~ s/\s*\*\s*/ / unless ($version =~ /Monastic/i);" --
        // unlike a psalm/canticle antiphon (which keeps its own "*" on screen, confirmed
        // real: "Ecce quam bonum * et quam iucúndum..."), a commemoration's antiphon has
        // its half-verse asterisk collapsed to a plain space. Confirmed against the same
        // 24 February 2026 fixture: the real rendered text is "Scriptum est enim, quia
        // domus mea..." with no "*" at all, even though the source file itself
        // (Tempora/Quad1-2.txt's own [Ant 3]) writes it with one.
        antiphonText = antiphonText.replacingOccurrences(of: #"\s*\*\s*"#, with: " ", options: .regularExpression)

        // A plain ferial temporal office often has no `[Versum N]` of its own at all,
        // and no Commune to fall back to either -- `orationes.pl:798-803`'s own final
        // fallback, `getfrompsalterium('Versum', $ind, ...)`, reaches a season-wide
        // generic versicle instead. Confirmed real: 24 February 2026's commemorated
        // Lenten feria (`Tempora/Quad1-2.txt`) defines no `[Versum N]`, and the real
        // fixture's versicle ("Ángelis suis Deus mandávit de te.") is exactly
        // `Major Special.txt`'s own `[Quad Versum 3]` -- `Quad1` being this week's own
        // `TemporalCycle.weekName`, with the trailing week number stripped.
        guard let versumLocation = location("Versum \(ind)") ?? location("Versum \(4 - ind)")
            ?? Self.seasonalVersumLocation(weekName: weekName, ind: ind, resolver: resolver)
        else { return nil }
        let versumLines = resolver.resolve(path: versumLocation.path, section: versumLocation.section)
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let versicleResponseUnits = Self.unitsFromLines(versumLines)
        guard case .versicleResponse = versicleResponseUnits.first else { return nil }

        guard let oratioLocation = location("Oratio \(ind)") ?? location("Oratio") else { return nil }
        let collect = resolver.resolve(path: oratioLocation.path, section: oratioLocation.section)
        let named = substituteName(in: collect, office: commemoration.path, resolver: resolver)

        var units: [Unit] = [.rubric("Commemoratio \(commemoration.rank.title)"), .antiphon(antiphonText)]
        units.append(contentsOf: versicleResponseUnits)
        units.append(contentsOf: Self.unitsFromResolvedText(named))
        return units
    }

    /// `Major Special.txt`'s own season-prefixed generic versicle (`[Quad Versum 3]`,
    /// `[Adv Versum 2]`, etc.) -- `weekName` minus its trailing week number gives the
    /// prefix (`"Quad1"` -> `"Quad"`), matching `TemporalCycle.weekName`'s own naming.
    private static func seasonalVersumLocation(weekName: String, ind: Int, resolver: SectionResolver) -> (path: String, section: String)? {
        let prefix = String(weekName.reversed().drop(while: \.isNumber).reversed())
        guard !prefix.isEmpty else { return nil }
        let path = "Psalterium/Special/Major Special"
        for candidateInd in [ind, 4 - ind] {
            let section = "\(prefix) Versum \(candidateInd)"
            if resolver.sectionExists(path: path, section: section) { return (path, section) }
        }
        return nil
    }

    /// Substitutes a `"N."`/`"N. et N."` placeholder in a generic Commune collect (or,
    /// with `isAntiphon: true`, an antiphon) with the winning office's own saint name —
    /// DO's `replaceNdot()` (`specials.pl:778-817`), confirmed against the real oracle
    /// fixture for 5 February 2026 (`Sancti/02-05`, falling back to `Commune/C6`'s
    /// `"...beátæ N. Vírginis..."`, real rendered result `"...beátæ Agathæ
    /// Vírginis..."`). No-ops when `text` has no `"N."` at all (a proper collect that
    /// already names the saint directly, the common case) or the office defines no
    /// `[Name]` of its own.
    ///
    /// **The `"Ant="`-tagged variant selection is ported** (`specials.pl:797-800`'s own
    /// "Doctor Antiphone: Casus vocativus"): when `isAntiphon` is true *and* the text
    /// itself starts with `"O"`/`"Ó"` (optionally followed by a comma) and whitespace —
    /// or is literally the Common of Doctors' own `"O Doctor óptime"` — the `[Name]`
    /// section's own `"Ant="`-tagged line wins over the plain/default one, if present.
    /// Confirmed real for 14 January 2025 (St Hilary, a Doctor): `Sancti/01-14`'s own
    /// `[Name]` is `"Hilárium\n(sed rubrica 1570 aut rubrica 1617)\nHilárii\nAnt=Hilári"`
    /// — the Oratio gets the plain `"Hilárium"`, but `Commune/C4a`'s own Magnificat
    /// antiphon `"O Doctor óptime, * ... beáte N., ..."` needs the vocative `"Hilári"`
    /// instead, which this project's engine was never substituting into the antiphon at
    /// all before (it wasn't calling this function there), rendering the literal `"N."`.
    ///
    /// **Not ported:** the `"Invit="`-tagged variant (a Matins-only Invitatory case, out
    /// of this project's Vespers-only scope) and the `"Oratio="` tag itself (real
    /// example found: `Sancti/02-05`'s own `[Name]` carries a `"Postcommunio=Agatha"`
    /// tag for a *Mass* proper, not an Office one — confirms the tagging convention is
    /// real, but no real `[Name]` this project's own oracle sweep has found carries an
    /// `"Oratio="` tag specifically, so the default/untagged line already serves that
    /// role correctly without it).
    private func substituteName(in text: String, office: String, resolver: SectionResolver, isAntiphon: Bool = false) -> String {
        guard text.contains("N."), resolver.sectionExists(path: office, section: "Name") else { return text }
        let lines = resolver.resolve(path: office, section: "Name")
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return text }

        let isVocativeEligible = isAntiphon
            && (text.range(of: #"^[OÓ],?\s"#, options: .regularExpression) != nil || text.hasPrefix("O Doctor óptime"))
        var candidates = lines
        if isVocativeEligible, lines.contains(where: { $0.hasPrefix("Ant=") }) {
            candidates = lines.filter { $0.hasPrefix("Ant=") }
        }
        guard var name = candidates.first, !name.isEmpty else { return text }
        if let equals = name.firstIndex(of: "=") {
            name = String(name[name.index(after: equals)...])
        }
        guard !name.isEmpty else { return text }

        var result = text
        if let range = result.range(of: #"N\. .*? N\."#, options: .regularExpression) {
            result.replaceSubrange(range, with: name)
        }
        return result.replacingOccurrences(of: "N.", with: name)
    }

    /// `orationes.pl:55-61`'s "Oratio Dominica" rule-flag redirect: a ferial file whose
    /// own `[Rule]` names this (real example: `Tempora/Epi4-1`, "Feria Secunda infra
    /// Hebdomadam IV post Epiphaniam") defines no collect of its own at all — the real
    /// Oratio comes from *that same week's own Sunday* file instead (`"$weekName-0"`,
    /// e.g. `Tempora/Epi4-0`), not the feria's own file or its (usually nonexistent)
    /// Commune. `Epi1`/`Nat` weeks are a further named exception in the real Perl,
    /// always redirecting to `Tempora/Epi1-0a` specifically regardless of which of the
    /// two matched — confirmed real (`Tempora/Epi1-0a.txt` exists as its own distinct
    /// file). Found via a full 2025-2040 sweep: ~895 of 5,844 days (~15%) were silently
    /// rendering with no Oratio section at all before this, every one an ordinary
    /// Feria/Sabbato whose own file carries exactly this rule.
    private func oratioDominicaOffice(rule: String, weekName: String) -> String? {
        guard rule.range(of: "Oratio Dominica", options: .caseInsensitive) != nil else { return nil }
        if weekName.range(of: "Epi1|Nat", options: [.regularExpression, .caseInsensitive]) != nil {
            return "Tempora/Epi1-0a"
        }
        return "Tempora/\(weekName)-0"
    }

    /// Ports `extract_common()`'s own three-way dispatch (`horascommon.pl:1475-1519`)
    /// for a bare (no `/`) reference — this project's own earlier version always
    /// assumed `"Commune/$ref"`, which is only actually branch 1 there
    /// (`^(ex|vide)\s*C[0-9]+[a-z]*-*[123]*`, a genuine Commune *code*, e.g. `"C4a"`,
    /// `"C6-1"`). The real catch-all branch (`horascommon.pl:1513-1514`) defaults a
    /// bare reference that *doesn't* match that Commune-code shape to `"Tempora/"`
    /// instead — confirmed real and necessary: `Tempora/Pasc7-1`'s own `[Rank]` names
    /// `"ex Pasc7-0"` (Pentecost Sunday's own file, for the ferias within its octave),
    /// and the old `"Commune/Pasc7-0"` guess resolved to a file that doesn't exist,
    /// silently losing that whole chain — found via a full 2025-2040 content audit
    /// once the new season-prefix fallback (above) stopped silently absorbing the
    /// resulting gap with generic ordinary-time content.
    private nonisolated(unsafe) static let communeCodeRegex: Regex<AnyRegexOutput> =
        // swiftlint:disable:next force_try
        try! Regex(#"^C[0-9]+[a-z]*-*[123]*$"#)

    static func communeFallbackPath(_ reference: String) -> String? {
        var ref = reference
        for prefix in ["vide ", "ex "] where ref.hasPrefix(prefix) {
            ref.removeFirst(prefix.count)
            break
        }
        guard !ref.isEmpty else { return nil }
        if ref.contains("/") { return ref }
        if (try? communeCodeRegex.firstMatch(in: ref)) != nil { return "Commune/\(ref)" }
        return "Tempora/\(ref)"
    }

    /// `extract_common()`'s own Paschaltide branch (`horascommon.pl:1501-1509`), not
    /// previously ported: for a genuine Commune-code reference, during Paschaltide, if a
    /// `"p"`-suffixed variant of that Commune file actually exists (real DO checks with
    /// `-e $paschal_fname`; this project has no "does a file exist" primitive, so
    /// `sectionExists(section: "Officium")` stands in for it — every real Commune file's
    /// own chain eventually reaches an `[Officium]` title, so this is equivalent in
    /// practice), that variant is used instead, unconditionally, for *every* section
    /// looked up against that Commune -- not just the ones the plain variant would have
    /// missed. Confirmed real for 29 April 2025 (S. Petri Martyris, `"vide C2a-1"`, in
    /// the weeks following the Easter Octave): the real fixture's own Magnificat
    /// antiphon, "Sancti et iusti * in Dómino gaudéte, allelúia...", comes from
    /// `Commune/C2a-1p.txt`'s own chain (→ `C2ap` → `C2p` → `C1p`), not the ordinary
    /// `C2a-1` chain this project's engine used to follow instead.
    private static func paschalCommuneFallbackPath(_ reference: String, weekName: String, resolver: SectionResolver) -> String? {
        guard let path = communeFallbackPath(reference) else { return nil }
        guard weekName.range(of: "Pasc", options: .caseInsensitive) != nil, path.hasPrefix("Commune/") else { return path }
        let paschalPath = "\(path)p"
        return resolver.sectionExists(path: paschalPath, section: "Officium") ? paschalPath : path
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
    /// `Sancti/02-05` itself, S. Agatha's own office file — **not** a Commune fallback
    /// as an earlier pass believed; her `[Ant Vespera]` and `"Psalm5 Vespera3=147"` are
    /// both defined directly on `Sancti/02-05.txt`, never touching `Commune/C6` at
    /// all) is still treated as fully proper and skips both of the above.
    ///
    /// Ports `psalmi.pl:446-461`'s `Ant Vespera 3`/`Ant Vespera` priority for the
    /// **office's own file only**: for second Vespers (`$vespera == 3`, our
    /// `!macroContext.isFirstVespers` — the common, "today's own Vespers" case) DO
    /// tries the office's own numbered `[Ant Vespera 3]` first, falling back to its
    /// plain `[Ant Vespera]` (with the usual Commune fallback) if the office itself has
    /// no `3`-suffixed section; first Vespers never looks at the `3` form at all.
    ///
    /// **Neither the plain nor the `3`-indexed lookup extends to the Commune unless the
    /// rank's own commune reference says `"ex"`, not `"vide"`** (`psalmi.pl`'s
    /// `exists($w{'Ant Vespera 3'})`/`exists($w{'Ant Vespera'})` check only the office's
    /// own hash; every `getproprium('Ant Vespera...', ...)` call that *does* reach the
    /// Commune is gated by `$communetype =~ /ex/`). This was found the hard way twice:
    /// a first attempt let the `3`-index reach `Commune/C3.txt`'s own `[Ant Vespera 3]`
    /// unconditionally, which broke Ss. Cornelii et Cypriani (16 September 2026, `"vide
    /// C3"`) — the real fixture's Vespers antiphon is "Beáti omnes * qui timent Dóminum"
    /// (psalm 127, the plain Wednesday ferial antiphon), not anything from `Commune/C3`
    /// at all, numbered or not. A second attempt gated only the `3`-index and left the
    /// plain `Ant Vespera` lookup unconditional, which broke S. Elisabeth Viduæ
    /// (19 November 2026, `"vide C7a"`) the same way — real DO shows "Psalmi et
    /// antiphonæ ex Psalterio secundum diem" (the plain ferial schedule, Psalm 132
    /// "Ecce quam bonum" first), not `Commune/C7`'s own `[Ant Vespera]` — confirmed by
    /// checking the real site directly. `[Oratio 3]` genuinely *is* Commune/C3's own
    /// text for the 16 September office (confirmed against the same fixture, and
    /// unconditional per `orationes.pl`'s own commune fallback — no `ex`/`vide` gating
    /// there) — Oratio and psalm-antiphon Commune fallback are genuinely different rules
    /// in DO, not the same one applied twice.
    ///
    /// **A third, previously-missed guard on the `3`-indexed lookup's own Commune
    /// extension**: `psalmi.pl:450`'s `elsif (!exists($w{'Ant Vespera'}) && ...)` —
    /// the Commune is only consulted for `Ant Vespera 3` when the office's own file has
    /// *neither* the numbered form *nor the plain one*. Missing this let an office with
    /// its own real plain `[Ant Vespera]` (no `3`-suffixed form of its own) but an
    /// `"ex"`-type Commune that happens to define its *own* `[Ant Vespera 3]` reach that
    /// Commune content wrongly, instead of the office's own plain antiphons — found via
    /// a full 2025-2040 content audit and confirmed real: 1 January (`Sancti/01-01`,
    /// `"ex Sancti/12-25"`) has its own plain `[Ant Vespera]` ("O admirábile
    /// commércium..."), but `Sancti/12-25` also happens to define its own `[Ant Vespera
    /// 3]` ("Tecum princípium...") — the real fixture uses the former, this project's
    /// engine was wrongly reaching the latter. This single gap alone plausibly explains
    /// the large majority of that audit's ~3,600 mismatched Psalmodia days, since any
    /// office shaped this way (own plain antiphons, no numbered form, an `"ex"` Commune
    /// that separately happens to have one) hits it.
    private func assemblePsalmodia(
        office: String, resolver: SectionResolver, macroContext: MacroContext, dayOfWeek: Int, englishResolver: SectionResolver?
    ) -> Section {
        let communeReference = macroContext.winningRank.communeReference
        let communeReferenceIsEx = communeReference.range(of: "^ex\\s", options: [.regularExpression, .caseInsensitive]) != nil
        let ownHasPlainAntVespera = resolver.sectionExists(path: office, section: "Ant Vespera")

        func location(section: String, allowCommune: Bool) -> (path: String, section: String)? {
            if resolver.sectionExists(path: office, section: section) { return (office, section) }
            guard allowCommune, let fallbackPath = Self.communeFallbackPath(communeReference), resolver.sectionExists(path: fallbackPath, section: section)
            else { return nil }
            return (fallbackPath, section)
        }

        func candidatePairs(
            section: String, allowCommune: Bool
        ) -> (pairs: [(antiphon: String, psalmNumber: String)], location: (path: String, section: String)?) {
            guard let loc = location(section: section, allowCommune: allowCommune) else { return ([], nil) }
            let text = resolver.resolve(path: loc.path, section: loc.section)
            var pairs = Self.parseAntiphonPsalmPairs(text)
            if pairs.isEmpty {
                // `psalmi.pl:606-609`: an antiphon with no `;;N` tag of its own always
                // pairs positionally with `@p` -- the office's own *default* five-psalm
                // set (`Day0 $h`'s "Psalmi Dominica" numbers, 109-113, for a Sunday or
                // feast's own proper antiphons) -- REGARDLESS of whether a `Psalm5`
                // rule exists to override the fifth. The previous version of this code
                // only attempted the zip when `festalFifthPsalmNumber` found an
                // override, so an ordinary Sunday/feast `[Ant Vespera]` with five
                // *unnumbered* antiphons and no `Psalm5` tag at all (the plain,
                // un-overridden case, not a rare one) fell through to the ferial
                // weekday schedule instead, losing its own proper antiphons entirely.
                // Confirmed real for 30 November 2025 (First Sunday of Advent):
                // `Tempora/Adv1-0`'s own `[Ant Vespera]` is `@:Ant Laudes` (a same-file
                // cross-reference, already resolved correctly), five plain antiphons
                // with no tags and no `Psalm5` rule -- the real fixture pairs them with
                // 109/110/111/112/113 exactly like an ordinary Sunday.
                let antiphons = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).filter { !$0.isEmpty }
                if antiphons.count == 5 {
                    let fifthPsalm = festalFifthPsalmNumber(
                        office: office, antiphonSourcePath: loc.path, resolver: resolver, isFirstVespers: macroContext.isFirstVespers
                    ) ?? "113"
                    let festalNumbers = ["109", "110", "111", "112", fifthPsalm]
                    pairs = zip(antiphons, festalNumbers).map { ($0, $1) }
                }
            }
            return (pairs, pairs.isEmpty ? nil : loc)
        }

        var pairs: [(antiphon: String, psalmNumber: String)] = []
        var winningLocation: (path: String, section: String)?
        if !macroContext.isFirstVespers {
            (pairs, winningLocation) = candidatePairs(section: "Ant Vespera 3", allowCommune: communeReferenceIsEx && !ownHasPlainAntVespera)
        }
        if pairs.isEmpty {
            (pairs, winningLocation) = candidatePairs(section: "Ant Vespera", allowCommune: communeReferenceIsEx)
        }

        var usedWeekdaySchedule = false
        let weekdaySection = "Day\(dayOfWeek) Vespera"
        if pairs.isEmpty {
            usedWeekdaySchedule = true
            let weekdayText = resolver.resolve(path: "Psalterium/Psalmi/Psalmi major", section: weekdaySection)
            pairs = Self.parseAntiphonPsalmPairs(weekdayText)
        }

        // English antiphon *text* only (never the psalm numbers, which are Latin's own
        // parsed values regardless of language) -- queried at the exact same location
        // Latin resolved to, per `resolvedLocation`'s own reasoning: never substitute a
        // different, mismatched section just because it happens to exist in English.
        var englishAntiphons: [String?] = Array(repeating: nil, count: pairs.count)
        if let englishResolver {
            let englishRawText: String?
            if usedWeekdaySchedule {
                englishRawText = englishResolver.sectionExists(path: "Psalterium/Psalmi/Psalmi major", section: weekdaySection)
                    ? englishResolver.resolve(path: "Psalterium/Psalmi/Psalmi major", section: weekdaySection) : nil
            } else if let winningLocation {
                englishRawText = englishResolver.sectionExists(path: winningLocation.path, section: winningLocation.section)
                    ? englishResolver.resolve(path: winningLocation.path, section: winningLocation.section) : nil
            } else {
                englishRawText = nil
            }
            if let englishRawText {
                let englishPairs = Self.parseAntiphonPsalmPairs(englishRawText)
                if !englishPairs.isEmpty, englishPairs.count == pairs.count {
                    englishAntiphons = englishPairs.map { $0.antiphon }
                } else if englishPairs.isEmpty {
                    // Unnumbered antiphons (the festal-fifth-psalm case): zip raw lines
                    // positionally, same as the Latin side does.
                    let englishLines = englishRawText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).filter { !$0.isEmpty }
                    if englishLines.count == pairs.count { englishAntiphons = englishLines }
                }
            }
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
        // `psalmi.pl:629`'s full OR-condition is `!exists($winner{"Ant $hora"}) ||
        // $commune =~ /C10/` -- the second branch (a Sunday within Paschaltide using the
        // Common-of-Sundays) still gets replaced even when that Commune *does* supply
        // generic antiphons (so `pairs` wouldn't be empty and `usedWeekdaySchedule`
        // wouldn't fire on its own). `$communetype !~ /ex/i` gates the *whole*
        // condition in the real Perl, not just this branch -- `communeReferenceIsEx`
        // being false is what actually lets a `"vide C10"` reference reach this
        // replacement at all (an `"ex C10"` office already has its own real antiphons
        // reaching this point via the Commune fallback above, so it correctly doesn't
        // get overwritten).
        //
        // **Not independently confirmed against a real fixture**: a full search of
        // every `Sancti/*.txt` file referencing `C10` found none whose calendar date
        // can ever fall within Paschaltide (all the real examples sit in
        // July-November) -- this branch may be effectively unreachable for the
        // Universal Calendar dates this project's alpha scope actually covers. Ported
        // for faithfulness to the real condition and because the oracle sweep across
        // 2025-2040 exercises it as a no-op either way, not because a specific date
        // proved it right.
        let communeIsC10 = communeReference.range(of: "C10") != nil
        if (usedWeekdaySchedule || (communeIsC10 && !communeReferenceIsEx)),
            macroContext.weekName.range(of: "Pasc", options: .caseInsensitive) != nil
        {
            let alleluia = alleluiaAntiphon(resolver: resolver)
            pairs = pairs.map { (antiphon: alleluia, psalmNumber: $0.psalmNumber) }
            if let englishResolver {
                let englishAlleluia = alleluiaAntiphon(resolver: englishResolver)
                englishAntiphons = Array(repeating: englishAlleluia, count: pairs.count)
            }
        }

        pairs = pairs.map {
            (
                antiphon: Self.applyingSeasonalAlleluia(
                    to: $0.antiphon, weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers
                ), psalmNumber: $0.psalmNumber
            )
        }
        englishAntiphons = englishAntiphons.map {
            $0.map { Self.applyingSeasonalAlleluia(to: $0, weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers) }
        }

        var units: [Unit] = []
        for (index, pair) in pairs.enumerated() {
            let english = index < englishAntiphons.count ? englishAntiphons[index] : nil
            var psalmContent = psalmUnits(number: pair.psalmNumber, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)

            // Direct feedback, comparing a real rendering against real DO output: DO's
            // own getantcross() (horas.pl:238-278) walks an antiphon's words against
            // its psalm's own first verse, word by word, and marks the point where
            // they stop matching with a "‡" dagger -- covering not just a whole-verse
            // quote (e.g. Psalm 132's antiphon "Ecce quam bonum..." verbatim repeats
            // 132:1) but any partial-prefix quote too (e.g. Psalm 109's antiphon
            // quoting only "Dixit Dominus Domino meo", confirmed against the real
            // fixture for 19 January 2025). `horasscripts.pl:619-621` is the sole call
            // site: if the result ends with the dagger (nothing left of verse 1 to
            // append -- the whole-verse case), the dagger moves to the very start of
            // verse 2 instead, and verse 1's own ordinary mid-verse `*` split is
            // dropped entirely (shown as one plain, unsplit line, confirmed against the
            // real fixture for 2 January 2025). Otherwise the dagger lands wherever the
            // match stopped, right after any punctuation immediately following it (most
            // often the verse's own natural `*`). The antiphon's own display text gets
            // a trailing "‡" whenever the match succeeds at all, not only on a whole
            // match -- confirmed empirically against both real fixtures above. Found via
            // a full 2025-2040 content audit, generalising an earlier whole-verse-only
            // special case that the same audit had already shown explained a large
            // share of the mismatched Psalmodia days -- a psalm quoted, in whole or in
            // part, by its own antiphon is a common pattern, not a rare one.
            let (taggedPsalmContent, antiphonMatched) = Self.applyingAntiphonDagger(antiphon: pair.antiphon, psalmContent: psalmContent)
            psalmContent = taggedPsalmContent
            let antiphonText = antiphonMatched ? "\(pair.antiphon) ‡" : pair.antiphon

            units.append(.antiphon(antiphonText, english: english))
            units.append(.psalmTitle("Psalmus \(Self.psalmTitleNumber(from: pair.psalmNumber)) [\(index + 1)]"))
            units.append(contentsOf: psalmContent)
            units.append(.antiphon(antiphonText, english: english))
        }
        return Section(kind: .psalmodia, units: units)
    }

    /// Strips a Bea half-verse-split annotation like `"135(1-9)"` down to the bare
    /// psalm number for display -- the range is an internal file-organisation detail
    /// (`Psalmi major.txt` splits a long psalm across two of the hour's five slots),
    /// not something recited or printed as part of the title.
    private static func psalmTitleNumber(from psalmNumber: String) -> String {
        guard let parenIndex = psalmNumber.firstIndex(of: "(") else { return psalmNumber }
        return String(psalmNumber[..<parenIndex])
    }

    /// Ports `depunct()` (`horas.pl:280-292`) for word comparison: strips the same
    /// punctuation, folds the same accented vowels, and normalises J/j to I/i (source
    /// text can carry either spelling before this project's own "I not J" orthography
    /// pass runs elsewhere).
    private static func depunctuatedWord(_ word: Substring) -> String? {
        var result = ""
        for scalar in word.unicodeScalars {
            switch scalar {
            case ".", ",", ":", "?", "!", "\"", "'", "*", "(", ")": continue
            case "á", "Á": result.append("a")
            case "é", "É": result.append("e")
            case "í", "Í": result.append("i")
            case "j": result.append("i")
            case "J": result.append("I")
            case "ó", "ö", "õ", "Ó", "Ö", "Ô": result.append("o")
            case "ú", "ü", "û", "Ú", "Ü", "Û": result.append("u")
            case "æ": result.append("ae")
            case "œ": result.append("oe")
            default: result.unicodeScalars.append(scalar)
            }
        }
        let lowered = result.lowercased()
        return lowered.isEmpty ? nil : lowered
    }

    /// Ports `getantcross()` (`horas.pl:238-278`): walks the psalm verse's own words and
    /// the antiphon's own words in lockstep (skipping either side's punctuation-only
    /// tokens via `depunctuatedWord`, exactly like the real `depunct()`-based
    /// comparison), and reports where the antiphon's words stop matching the verse's --
    /// the "‡" dagger point. Returns `nil` when there's no match at all, or when the
    /// antiphon runs longer than the verse (`horas.pl:250`'s own `return $psalmline if
    /// ($aind < @antline && $pind == @psalmline)` -- functionally "leave the verse
    /// untouched" here, since a no-op return is the same as never applying a dagger).
    ///
    /// A verse token skipped *during* the matching loop (either side's own mid-match
    /// punctuation, e.g. a "*" that happens to fall between two matched words) is
    /// dropped entirely from the output, never reappearing -- but a verse token skipped
    /// *after* the match ends (trailing punctuation immediately following the
    /// antiphon's last matched word, most often the verse's own natural "*" split
    /// point) is kept, appended literally right before the dagger. This asymmetry is
    /// exactly what makes a *whole* Psalm 132:1 quoted by its antiphon (dagger falls at
    /// the very end, past the verse's own trailing "." with no "*" ever met after the
    /// match) render differently from a *partial* Psalm 109:1 quote (dagger falls right
    /// after the verse's own mid-verse "*", hit only once the match had already ended)
    /// -- confirmed against both real fixtures (2 and 19 January 2025).
    private static func daggerTokens(verseTokens: [String], antiphonTokens: [String]) -> [String]? {
        var pind = 0
        var aind = 0
        var output: [String] = []
        var matchedAnyWord = false

        while aind < antiphonTokens.count, pind < verseTokens.count {
            let rawVerseToken = verseTokens[pind]
            pind += 1
            guard let verseWord = depunctuatedWord(Substring(rawVerseToken)) else { continue }

            let rawAntiphonToken = antiphonTokens[aind]
            aind += 1
            guard let antiphonWord = depunctuatedWord(Substring(rawAntiphonToken)) else {
                pind -= 1
                continue
            }

            guard verseWord.contains(antiphonWord) else { return nil }
            output.append(rawVerseToken)
            matchedAnyWord = true
        }

        guard matchedAnyWord, !(aind < antiphonTokens.count && pind == verseTokens.count) else { return nil }

        while pind < verseTokens.count, depunctuatedWord(Substring(verseTokens[pind])) == nil {
            output.append(verseTokens[pind])
            pind += 1
        }
        output.append("‡")
        output.append(contentsOf: verseTokens[pind...])
        return output
    }

    /// Reconstructs a `.verse` unit's original, space-tokenised source line from its
    /// already-split `firstHalf`/`secondHalf` display halves -- the "*" that display
    /// attaches directly to `firstHalf`'s last word becomes its own token again,
    /// matching how DO's own source line looks before `horasscripts.pl`'s display-time
    /// split runs.
    private static func sourceTokens(firstHalf: String, secondHalf: String) -> [String] {
        var tokens = firstHalf.split(separator: " ").map(String.init)
        guard !secondHalf.isEmpty else { return tokens }
        if let last = tokens.last, last.hasSuffix("*") {
            let withoutAsterisk = String(last.dropLast())
            if withoutAsterisk.isEmpty {
                tokens.removeLast()
            } else {
                tokens[tokens.count - 1] = withoutAsterisk
            }
        }
        tokens.append("*")
        tokens.append(contentsOf: secondHalf.split(separator: " ").map(String.init))
        return tokens
    }

    /// The inverse of `sourceTokens`: turns a dagger-annotated token stream back into
    /// display halves. A "*" still present splits the line exactly as before; the
    /// dagger (wherever it landed) simply travels with whichever half it ends up in.
    private static func displayHalves(from tokens: [String]) -> (first: String, second: String) {
        guard let starIndex = tokens.firstIndex(of: "*") else {
            return (tokens.joined(separator: " "), "")
        }
        let firstTokens = tokens[..<starIndex]
        let secondTokens = tokens[(starIndex + 1)...]
        let first = firstTokens.isEmpty ? "*" : "\(firstTokens.joined(separator: " "))*"
        return (first, secondTokens.joined(separator: " "))
    }

    private static func rejoinEnglishHalves(_ first: String, _ second: String?) -> String {
        guard let second, !second.isEmpty else { return first }
        return "\(first) \(second)"
    }

    /// Prepends "‡ " to the next `.verse` unit found after `index` (Gloria's own two
    /// lines count as `.verse` too, but the dagger rule only ever concerns a psalm's
    /// own verse 2, which always immediately follows verse 1).
    private static func addingLeadingDagger(toVerseAfter index: Int, in units: [Unit]) -> [Unit] {
        var units = units
        guard let nextVerseIndex = units[(index + 1)...].firstIndex(where: {
            if case .verse = $0 { return true } else { return false }
        }) else { return units }
        guard case .verse(let reference, let firstHalf, let secondHalf, let firstEnglish, let secondEnglish) = units[nextVerseIndex] else {
            return units
        }
        units[nextVerseIndex] = .verse(
            reference: reference, firstHalf: "‡ \(firstHalf)", secondHalf: secondHalf,
            firstHalfEnglish: firstEnglish, secondHalfEnglish: secondEnglish
        )
        return units
    }

    /// Applies the general `getantcross()` dagger port to a psalm's own first verse
    /// against the antiphon that precedes it. Returns the input unchanged, with
    /// `antiphonMatched == false`, when there's no match at all (the ordinary case:
    /// most antiphons don't quote their own psalm's opening words).
    private static func applyingAntiphonDagger(antiphon: String, psalmContent: [Unit]) -> (units: [Unit], antiphonMatched: Bool) {
        guard let firstVerseIndex = psalmContent.firstIndex(where: {
            if case .verse = $0 { return true } else { return false }
        }), case .verse(let reference, let firstHalf, let secondHalf, let firstEnglish, let secondEnglish) = psalmContent[firstVerseIndex]
        else { return (psalmContent, false) }

        let verseTokens = Self.sourceTokens(firstHalf: firstHalf, secondHalf: secondHalf)
        let antiphonTokens = antiphon.split(separator: " ").map(String.init)
        guard let taggedTokens = Self.daggerTokens(verseTokens: verseTokens, antiphonTokens: antiphonTokens) else {
            return (psalmContent, false)
        }

        var units = psalmContent
        if taggedTokens.last == "‡" {
            // Whole-verse match: verse 1 loses its own split entirely, and the dagger
            // moves to the start of verse 2 instead (`horasscripts.pl:619-621`'s own
            // "if $lines[0] ends with the dagger" branch).
            let unsplit = taggedTokens.dropLast().joined(separator: " ")
            units[firstVerseIndex] = .verse(
                reference: reference, firstHalf: unsplit, secondHalf: "",
                firstHalfEnglish: firstEnglish.map { Self.rejoinEnglishHalves($0, secondEnglish) }, secondHalfEnglish: nil
            )
            units = Self.addingLeadingDagger(toVerseAfter: firstVerseIndex, in: units)
        } else {
            let (newFirst, newSecond) = Self.displayHalves(from: taggedTokens)
            units[firstVerseIndex] = .verse(
                reference: reference, firstHalf: newFirst, secondHalf: newSecond,
                firstHalfEnglish: firstEnglish, secondHalfEnglish: secondEnglish
            )
        }
        return (units, true)
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
    ///
    /// Checks the office's own `[Rule]` first, unconditionally, then — separately —
    /// `antiphonSourcePath`'s own `[Rule]` (`psalmi.pl:577-580`'s own `$rule =~
    /// /Psalm5.../ || ($commune{Rule} =~ /Psalm5.../ && $c eq 4)`: the Commune's own
    /// tag is only consulted when the *antiphons themselves* came from that Commune,
    /// i.e. exactly when `antiphonSourcePath != office`). A single all-or-nothing
    /// office-then-Commune fallback (this function's own earlier version) missed this:
    /// the office's own `[Rule]` existing at all (even without a `Psalm5` tag of its
    /// own) short-circuited the Commune check entirely. Confirmed real for 13 January
    /// 2025 (`Sancti/01-13`, "Commemoratio Baptismatis Domini", `"ex Sancti/01-06"` —
    /// Epiphany): `Sancti/01-13`'s own `[Rule]` has no `Psalm5` tag at all, but its
    /// antiphons come from Epiphany's own `[Ant Laudes]` (via the Commune chain, no
    /// `;;psalmNumber` tags of their own), and Epiphany's own `[Rule]` has `"Psalm5
    /// Vespera3=113"` — the real fixture's own fifth psalm for that date's second
    /// Vespers is exactly Psalm 113.
    private func festalFifthPsalmNumber(
        office: String, antiphonSourcePath: String, resolver: SectionResolver, isFirstVespers: Bool
    ) -> String? {
        let preferredKey = isFirstVespers ? "Psalm5 Vespera=" : "Psalm5 Vespera3="
        let fallbackKey = isFirstVespers ? "Psalm5 Vespera3=" : "Psalm5 Vespera="

        func tag(at path: String) -> String? {
            guard resolver.sectionExists(path: path, section: "Rule") else { return nil }
            let ruleText = resolver.resolve(path: path, section: "Rule")
            return Self.value(forRuleKey: preferredKey, in: ruleText) ?? Self.value(forRuleKey: fallbackKey, in: ruleText)
        }

        if let ownTag = tag(at: office) { return ownTag }
        guard antiphonSourcePath != office else { return nil }
        return tag(at: antiphonSourcePath)
    }

    /// **Case-insensitive**, matching the real Perl's own extraction regex exactly
    /// (`psalmi.pl:577-580`'s `/Psalm5 (Vespera3?)=([0-9]+)/i`, every one of its four
    /// alternatives carrying the `/i` flag) — not a simplification. Confirmed real for
    /// Ascension (`Tempora/Pasc5-4.txt`'s own `[Rule]`, `"Psalm5 vespera=116"`,
    /// lowercase "vespera"): a case-sensitive `hasPrefix` match against the usual
    /// capitalised `"Psalm5 Vespera="` silently missed this one real file, falling back
    /// to the ordinary festal default (Psalm 113) instead of the real fifth psalm
    /// (116) — confirmed against the real fixture for 28 May 2025 (Ascension's own
    /// first Vespers), whose own fifth psalm is "116 — Hymnus laudis et gratiarum
    /// actionis", not "113 — In exitu Israël".
    private static func value(forRuleKey key: String, in ruleText: String) -> String? {
        for line in ruleText.split(separator: "\n") where line.range(of: key, options: [.anchored, .caseInsensitive]) != nil {
            return String(line.dropFirst(key.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// `number` can carry a Bea verse-range suffix (`Psalmi major.txt`'s own notation for
    /// a long psalm split across two of the hour's five Vespers slots, e.g. Friday's own
    /// `"138(1-13)"` / `"138(14-24)"`) -- `PsalmVerseRange.parse` splits that into the
    /// real file's bare number and the range to keep. Real, previously-undiscovered bug,
    /// found via a random-sample visual walkthrough: using `number` unstripped built a
    /// path like `Psalterium/Psalmorum/Psalm138(1-13)`, which doesn't exist --
    /// `resolvePsalmText` returned its usual `"...is missing!"` placeholder, but since
    /// that placeholder text doesn't start with a digit, `Psalm.parseVerses` silently
    /// filtered the whole line out as if it were a leading title comment, leaving the
    /// psalm with *zero* verses and no trace of the placeholder anywhere -- exactly the
    /// scenario this project's own full-range placeholder sweep can't catch, since it
    /// only scans text that actually ends up in a `Unit`.
    private func psalmUnits(number: String, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?) -> [Unit] {
        let parsed = PsalmVerseRange.parse(number)
        let baseNumber = parsed?.base ?? number
        let range = parsed?.range
        let path = "Psalterium/Psalmorum/Psalm\(baseNumber)"
        let text = resolver.resolvePsalmText(path: path, section: RawSectionParser.wholeFileSectionName)
        let latinVerses = Self.applying(range, to: Psalm.parseVerses(text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)))
        let englishVerses: [PsalmVerse]? = englishResolver.flatMap { eng in
            guard eng.sectionExists(path: path, section: RawSectionParser.wholeFileSectionName) else { return nil }
            let englishText = eng.resolvePsalmText(path: path, section: RawSectionParser.wholeFileSectionName)
            return Self.applying(range, to: Psalm.parseVerses(englishText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)))
        }
        var units = Self.pairedVerses(latin: latinVerses, english: englishVerses)
        units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
        return units
    }

    private static func applying(_ range: PsalmVerseRange?, to verses: [PsalmVerse]) -> [PsalmVerse] {
        guard let range else { return verses }
        return verses.filter { verse in
            guard let (number, letter) = PsalmVerseRange.verseNumberAndLetter(fromReference: verse.reference) else { return true }
            return range.contains(verse: number, letter: letter)
        }
    }

    /// Pairs Latin and English verses for the same psalm/canticle, but only when their
    /// reference sequences match **exactly** (same count, same reference string at
    /// each position) — confirmed necessary, not just cautious: DO's Pius XII (Bea)
    /// Latin psalter and the plain Vulgate/Douay-Rheims numbering English uses
    /// genuinely divide some psalms differently. Real example: Bea's own
    /// `Latin-Bea/Psalterium/Psalmorum/Psalm114.txt`/`Psalm115.txt` split the
    /// underlying material at a different point than English's own same-named files —
    /// English embeds an inline `"(4a) ..."`-style annotation marking a sub-clause of
    /// one line as truly belonging to a *different* verse, and elsewhere splits mid-line
    /// at DO's own flex-mark convention (`†`/`‡`) rather than at `"*"`. DO's own real
    /// rendering strips these annotations and the `a`/`b` letter suffix for display
    /// (confirmed against the real fixture for 19 January 2026 — no `"(15)"` survives,
    /// and a `"115:16a"`/`"115:16b"` pair both render as plain `"115:16"`) but doesn't
    /// attempt to *realign* the two languages' verse divisions at all; reconstructing a
    /// true per-half-verse alignment across that divergence would need to parse those
    /// inline annotations and `†`/`‡` as structural split points too, which
    /// `Psalm.swift`'s own doc comment already deliberately scopes `†`/`‡` out of for
    /// the Latin-only case — a real, not-yet-attempted follow-up, not this pass's job.
    /// Falling back to Latin-only when the sequences don't match exactly is
    /// deliberately conservative: no English for a handful of psalms beats a
    /// confidently-wrong pairing.
    private static func pairedVerses(latin: [PsalmVerse], english: [PsalmVerse]?) -> [Unit] {
        guard let english, english.count == latin.count, zip(latin, english).allSatisfy({ $0.reference == $1.reference })
        else {
            return latin.map { .verse(reference: $0.reference, firstHalf: $0.firstHalf, secondHalf: $0.secondHalf) }
        }
        return zip(latin, english).map {
            .verse(
                reference: $0.reference, firstHalf: $0.firstHalf, secondHalf: $0.secondHalf,
                firstHalfEnglish: $1.firstHalf, secondHalfEnglish: $1.secondHalf
            )
        }
    }

    /// `&Gloria`'s two lines, each itself `*`-split like a psalm verse. Always paired
    /// positionally (no verse-reference divergence risk: the doxology is fixed, 2
    /// lines, identical structure regardless of language).
    ///
    /// **Maundy Thursday through Holy Saturday's own second Vespers replace this
    /// entirely** with a single small-font rubric note (`horas.pl:303-311`: the `&Gloria`
    /// macro call itself is intercepted *before* resolving, returning `translate('Gloria
    /// omittitur', $lang)` instead of the real doxology text) — not merely omitted
    /// silently (`Gloria`'s own `ScriptFunc`, `horasscripts.pl:89-95`, returns `""` for
    /// the *macro's own* value, but the visible page substitutes the rubric note at the
    /// call site, not blank space). Confirmed real for 19 April 2025 (Holy Saturday):
    /// every one of the real fixture's five psalms and the Magnificat itself end "Gloria
    /// omittitur" with no doxology text at all.
    private func gloriaUnits(resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?) -> [Unit] {
        if Self.isTriduumGloriaOmitted(
            weekName: macroContext.weekName, dayOfWeek: macroContext.dayOfWeek, isFirstVespers: macroContext.isFirstVespers
        ) {
            // `Psalterium/Common/Translate.txt`'s own `[Gloria omittitur]` entry —
            // hardcoded here, matching this project's existing convention for DO's fixed
            // `translate()`-sourced UI labels (e.g. the "Psalmus" title prefix), rather
            // than adding a whole second lookup mechanism for one string.
            return [.rubric("Gloria omittitur", english: englishResolver != nil ? "omit Glory be" : nil)]
        }
        let text = ScriptMacros.resolve("Gloria", context: macroContext, resolver: resolver) ?? ""
        let latinHalves = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { Psalm.splitHalves(DOMarkers.stripLineLabel(String($0))) }
        let englishHalves: [(first: String, second: String)]? = englishResolver.flatMap { eng -> [(first: String, second: String)]? in
            guard let englishText = ScriptMacros.resolve("Gloria", context: macroContext, resolver: eng) else { return nil }
            let lines = englishText.split(separator: "\n", omittingEmptySubsequences: false)
                .map { Psalm.splitHalves(DOMarkers.stripLineLabel(String($0))) }
            return lines.count == latinHalves.count ? lines : nil
        }
        return latinHalves.enumerated().map { index, halves in
            let english = englishHalves?[index]
            return .verse(
                reference: "", firstHalf: halves.first, secondHalf: halves.second,
                firstHalfEnglish: english?.first, secondHalfEnglish: english?.second
            )
        }
    }

    // MARK: - Canticum: Magnificat

    /// The Magnificat antiphon's actual source, confirmed against the real oracle
    /// fixture for 16 September 2026: for this office (via `Commune/C3.txt`, second
    /// Vespers), it's `[Ant 3]` (a plain, unnumbered antiphon — "Gaudent in cælis..."),
    /// **not** `[Ant Vespera 3]` (whose candidates all carry a `;;psalmNumber`-style
    /// tag — the same file's `[Ant Vespera 3]`, "Isti sunt Sancti...;;109"), which this
    /// code tried first before that fixture caught it choosing the wrong one. `[Ant
    /// $ind]` is tried first here (`$ind` = 1 for first Vespers, 3 for second — see
    /// this function's own doc comment), mirroring `assemblePsalmodia`'s confirmed
    /// pattern that an unnumbered antiphon is the general-purpose one and a numbered
    /// one is reserved for specific higher ranks -- **not independently confirmed for
    /// this section** (only that `[Ant 3]` is right for *this* rank on second Vespers),
    /// so a higher-ranked feast that should actually get one of `[Ant Vespera $ind]`'s
    /// numbered candidates is a known open question, not a closed one.
    private func assembleMagnificat(
        office: String, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?,
        day: Int, month: Int, year: Int
    ) -> Section {
        // `"Ant 3"` is keyed by the same first/second-Vespers index as `assemblePsalmodia`'s
        // `Ant Vespera 3` and the Oratio case's `Oratio 3` (`orationes.pl:34`'s `$ind` --
        // 1 for first Vespers, 3 for second): `[Ant 1]`/`[Ant 3]` sit right after
        // `[Versum 1]`/`[Versum 3]` in a Commune file's own chronological layout (real
        // example: `Commune/C1.txt`/`C3.txt`), each hour's own Magnificat-slot antiphon,
        // not a fixed "3" regardless of which Vespers is being sung.
        let ind = macroContext.isFirstVespers ? 1 : 3
        let communeReference = macroContext.winningRank.communeReference
        var units: [Unit] = []
        // Found via a real device test: an ordinary "time after Pentecost" Sunday's own
        // temporal file (`Tempora/PentNN-0`) defines no `[Ant 1]` of its own, and has no
        // Commune fallback either (it's temporal), so first Vespers was silently
        // rendering with no antiphon at all. `officestring()`'s own "monthday" merge
        // (`monthdayLocation`) and, failing that, the `Psalterium/Special/Major
        // Special.txt` fallback (`majorSpecialAntLocation`) are DO's own two remaining
        // tiers, tried in the same order `getantvers`/`getproprium` try them -- confirmed
        // against two real fixtures: 19-20 September 2026 (the monthday merge supplies
        // `Tempora/093-0`'s own `[Ant 1]`, "Ne reminiscáris, Dómine..."), and 17-18
        // January 2026, where month < 7 so the monthday merge doesn't apply at all, and
        // the real antiphon ("Suscépit Deus Israël...") comes from Major Special's own
        // `[Feria7 Ant 3]` instead.
        let antSection = "Ant \(ind)"
        let oAntiphonLoc = Self.oAntiphonLocation(
            office: office, isFirstVespers: macroContext.isFirstVespers, day: day, month: month, year: year, resolver: resolver
        )
        let monthdayLoc = monthdayLocation(
            office: office, section: antSection, day: day, month: month, year: year, tomorrow: macroContext.isFirstVespers, resolver: resolver
        )
        let plainLocation = resolvedLocation(
            office: office, communeReference: communeReference, section: antSection, resolver: resolver, weekName: macroContext.weekName
        )
        let numberedLocation = resolvedLocation(
            office: office, communeReference: communeReference, section: "Ant Vespera \(ind)", resolver: resolver, weekName: macroContext.weekName
        )
        let majorSpecialLoc = majorSpecialAntLocation(ind: ind, dayOfWeek: macroContext.dayOfWeek, resolver: resolver)
        if let location = oAntiphonLoc ?? monthdayLoc ?? plainLocation ?? numberedLocation ?? majorSpecialLoc {
            let text = resolver.resolve(path: location.path, section: location.section)
            let antiphon = text.split(separator: "\n", omittingEmptySubsequences: false).first
                .map { String($0).components(separatedBy: ";;").first ?? String($0) }
                .map { Self.applyingSeasonalAlleluia(to: $0, weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers) }
                .map { substituteName(in: $0, office: office, resolver: resolver, isAntiphon: true) }
            if let antiphon, !antiphon.isEmpty {
                let english: String? = englishResolver.flatMap { eng in
                    guard eng.sectionExists(path: location.path, section: location.section) else { return nil }
                    let englishText = eng.resolve(path: location.path, section: location.section)
                    return englishText.split(separator: "\n", omittingEmptySubsequences: false).first
                        .map { String($0).components(separatedBy: ";;").first ?? String($0) }
                        .map { Self.applyingSeasonalAlleluia(to: $0, weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers) }
                        .map { substituteName(in: $0, office: office, resolver: eng, isAntiphon: true) }
                }
                units.append(.antiphon(antiphon, english: english))
                units.append(contentsOf: magnificatVerses(resolver: resolver, englishResolver: englishResolver))
                units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
                units.append(.antiphon(antiphon, english: english))
                return Section(kind: .canticum, units: units)
            }
        }
        units.append(contentsOf: magnificatVerses(resolver: resolver, englishResolver: englishResolver))
        units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
        return Section(kind: .canticum, units: units)
    }

    /// `officestring()`'s own "monthday" merge (`SetupString.pl:723-780`, ported to
    /// `Computus.monthday`), scoped to the one field this project's Vespers-only alpha
    /// needs from it: the first-Vespers Magnificat antiphon on an ordinary "time after
    /// Pentecost"/"after Epiphany" Sunday whose own temporal file doesn't define
    /// `[Ant 1]`. The real merge overwrites *any* key the monthday file defines onto
    /// the winner's own hash unconditionally (`SetupString.pl:772-778`), so this is
    /// checked *before* the office's own direct lookup, not as a fallback after it —
    /// though in practice a Pent/Epi file and its monthday counterpart never define the
    /// same `Ant` index, so the distinction is untested, not just unlikely.
    private func monthdayLocation(
        office: String, section: String, day: Int, month: Int, year: Int, tomorrow: Bool, resolver: SectionResolver
    ) -> (path: String, section: String)? {
        guard Self.participatesInMonthdayMerge(office: office) else { return nil }
        guard let key = Computus.monthday(day: day, month: month, year: year, tomorrow: tomorrow) else { return nil }
        let path = "Tempora/\(key)"
        return resolver.sectionExists(path: path, section: section) ? (path, section) : nil
    }

    /// The seven "O Antiphons" (17-23 December, `Psalterium/Special/Major Special.txt`'s
    /// own `[Adv Ant 17]`...`[Adv Ant 23]`) — ports `ant123_special` (`horas.pl:471-500`),
    /// called *unconditionally first*, ahead of every other antiphon lookup this
    /// function tries (`canticum()`'s own `($ant, $df) = ant123_special($lang); unless
    /// ($ant) { ($ant, $c) = getantvers(...) }`) — not a fallback tier at the bottom of
    /// the chain like `monthdayLocation`/`majorSpecialAntLocation`, but an override that
    /// wins outright whenever it applies, before the office's own `[Ant $ind]` is ever
    /// consulted. Scoped to the real condition exactly: `$month == 12 && $day > 16 &&
    /// $day < 24 && $winner =~ /tempora/i` — a *sanctoral* office winning Vespers within
    /// this window (rare, but not impossible: a votive/commemorated saint could still
    /// outrank an Ember day) keeps its own proper antiphon instead. Confirmed real for
    /// 17 December 2025 (Ember Wednesday in Advent, `Tempora/`-won): the real fixture's
    /// own Magnificat antiphon is exactly "O Sapiéntia, * quæ ex ore Altíssimi
    /// prodiísti...", not the office's own `[Ant 3]` (this project's engine fell
    /// through to whatever fallback tier found something first, before this override
    /// existed).
    private static func oAntiphonLocation(
        office: String, isFirstVespers: Bool, day: Int, month: Int, year: Int, resolver: SectionResolver
    ) -> (path: String, section: String)? {
        guard office.hasPrefix("Tempora/") else { return nil }
        let effective = isFirstVespers ? Computus.addDays(1, day: day, month: month, year: year) : (day: day, month: month, year: year)
        guard effective.month == 12, effective.day > 16, effective.day < 24 else { return nil }
        let path = "Psalterium/Special/Major Special"
        let section = "Adv Ant \(effective.day)"
        return resolver.sectionExists(path: path, section: section) ? (path, section) : nil
    }

    /// `officestring()`'s own gate for whether the monthday merge applies at all
    /// (`SetupString.pl:735-736`): ordinary "time after Pentecost"/"after Epiphany"
    /// temporal files, excluding `Pent01`-`Pent05` (the weeks nearest Trinity Sunday,
    /// which keep their own proper texts throughout and never reach into the
    /// month/week Scripture cycle).
    private static func participatesInMonthdayMerge(office: String) -> Bool {
        guard office.range(of: #"^Tempora[^/]*/(Pent|Epi)"#, options: .regularExpression) != nil else { return false }
        return office.range(of: #"^Tempora[^/]*/Pent0[1-5]"#, options: .regularExpression) == nil
    }

    /// `getfrompsalterium`'s own fallback order for a Magnificat antiphon miss
    /// (`ind`, then 1, then 3, then 2 -- `specials.pl:648-651`, the same order
    /// `majorSpecialLocation` already uses for `Versum`), confirmed real for 17-18
    /// January 2026 (`Tempora/Epi2-0`, month < 7 so the monthday merge above doesn't
    /// apply): the real antiphon is Major Special's own `[Feria Ant 3]` (`(feria 7)`
    /// cross-referencing `[Feria7 Ant 3]`, "Suscépit Deus Israël..."), not `[Feria
    /// Ant 1]`, which doesn't exist.
    ///
    /// **One real placeholder skipped**: Major Special's own `[Dominica Ant 2]`/`[Ant
    /// 3]` (reached only when *today itself*, not tomorrow, is a Sunday) resolve to
    /// `/:ut in Proprio de Tempore:/` -- DO's own small-font inline-comment convention
    /// (`horas.pl:190`), not real antiphon text; rendered as-is it would show that
    /// literal Latin phrase as if it were the antiphon, so a match starting with `/:`
    /// is treated as absent rather than DO's own real (but out of this project's
    /// rendering scope) small-font substitution.
    private func majorSpecialAntLocation(ind: Int, dayOfWeek: Int, resolver: SectionResolver) -> (path: String, section: String)? {
        let path = "Psalterium/Special/Major Special"
        let dominicaOrFeria = dayOfWeek == 0 ? "Dominica" : "Feria"
        for candidate in [String(ind), "1", "3", "2"] {
            let name = "\(dominicaOrFeria) Ant \(candidate)"
            guard resolver.sectionExists(path: path, section: name) else { continue }
            guard !resolver.resolve(path: path, section: name).hasPrefix("/:") else { continue }
            return (path, name)
        }
        return nil
    }

    /// The Magnificat canticle text lives alongside the psalms proper, in
    /// `Psalterium/Psalmorum/`, under the pseudo-psalm number `232`.
    private func magnificatVerses(resolver: SectionResolver, englishResolver: SectionResolver?) -> [Unit] {
        let path = "Psalterium/Psalmorum/Psalm232"
        let text = resolver.resolvePsalmText(path: path, section: RawSectionParser.wholeFileSectionName)
        let latinVerses = Psalm.parseVerses(text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        let englishVerses: [PsalmVerse]? = englishResolver.flatMap { eng in
            guard eng.sectionExists(path: path, section: RawSectionParser.wholeFileSectionName) else { return nil }
            let englishText = eng.resolvePsalmText(path: path, section: RawSectionParser.wholeFileSectionName)
            return Psalm.parseVerses(englishText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        }
        return Self.pairedVerses(latin: latinVerses, english: englishVerses)
    }

    // MARK: - Capitulum / Hymnus / Versus

    /// Best-effort direct lookups (`[Capitulum Vespera]`, `[Hymnus Vespera]`, each
    /// independently, with the same Commune fallback as everything else) — unlike
    /// Psalmi/Magnificat, this wasn't traced closely enough to be confident the exact
    /// section names are right in every case (see the type doc's scope limits). A
    /// section that resolves nowhere (office or Commune) is simply omitted rather than
    /// emitted empty.
    ///
    /// `[Versum $ind]` **is** keyed by the same first/second-Vespers index as
    /// `Oratio`/`Ant Vespera`/`Ant $ind` (not a fixed "1" — an earlier pass here hadn't
    /// caught this one yet). Confirmed real for 16 September 2026: the actual versicle
    /// is "Exsultábunt Sancti in glória. / Lætabúntur in cubílibus suis.", which is
    /// `Commune/C3.txt`'s `[Versum 2]` (reached via `[Versum 3]`'s own `@:Versum 2`
    /// cross-reference for second Vespers) — not `[Versum 1]`'s "Lætámini in Dómino...",
    /// which this code used to return unconditionally.
    ///
    /// Hymn stanzas are paired as one whole English block, not stanza-by-stanza
    /// (`CLAUDE.md`'s finer "hymns by stanza" alignment isn't attempted here yet).
    private func assembleCapitulumHymnusVersus(
        office: String, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?, dayOfWeek: Int
    ) -> [Section] {
        let communeReference = macroContext.winningRank.communeReference
        // `ownSection`/`majorSpecialSection` differ only for the checkmtv-revised
        // Confessor hymn (`"Hymnus1 Vespera"` vs plain `"Hymnus Vespera"`) — DO's own
        // `hymnusmajor` discards its checkmtv-computed name entirely once it falls
        // through to the Major Special tier (`specials/hymni.pl:106-107`'s own
        // `$name = gettempora('Hymnus major') . " $hora"` reassignment), so that
        // fallback always uses the plain, unrevised key regardless of checkmtv.
        func lookup(_ ownSection: String, majorSpecialSection: String? = nil) -> (latin: String, english: String?)? {
            guard let location = resolvedLocation(
                office: office, communeReference: communeReference, section: ownSection, resolver: resolver, weekName: macroContext.weekName
            )
                ?? majorSpecialLocation(
                    section: majorSpecialSection ?? ownSection, weekName: macroContext.weekName, dayOfWeek: dayOfWeek, resolver: resolver
                )
            else { return nil }
            let latin = resolver.resolve(path: location.path, section: location.section)
            let english = englishResolver.flatMap { eng in
                eng.sectionExists(path: location.path, section: location.section) ? eng.resolve(path: location.path, section: location.section) : nil
            }
            return (latin, english)
        }

        // `getantvers`'s own mirrored-index retry (`specials.pl:584-589`): a missing
        // `Versum $ind` on the office's own file/Commune retries the *other* Vespers'
        // index (`4-ind`) on that same office/Commune tier — before ever falling to
        // Major Special. Real example: Epiphany's own `Sancti/01-06.txt` defines only
        // `[Versum 1]` (no `3`); its own second Vespers (6 January itself) still uses
        // that same `[Versum 1]` content ("Reges Tharsis..."), not the generic ferial
        // Major Special fallback this project's engine fell straight to before this fix.
        func ownOrCommune(_ section: String) -> (latin: String, english: String?)? {
            guard let location = resolvedLocation(
                office: office, communeReference: communeReference, section: section, resolver: resolver, weekName: macroContext.weekName
            )
            else { return nil }
            let latin = resolver.resolve(path: location.path, section: location.section)
            let english = englishResolver.flatMap { eng in
                eng.sectionExists(path: location.path, section: location.section) ? eng.resolve(path: location.path, section: location.section) : nil
            }
            return (latin, english)
        }

        var sections: [Section] = []
        // `capitulis.pl`'s `capitulum_major`: the office's own shared Lauds/Vespers key
        // is `"Capitulum Laudes"` (confirmed real: 109 real `Sancti`/`Commune`/`Tempora`
        // files define it, against only 7 using `"Capitulum Vespera"`) — but the real
        // Perl's own selection is a hardcoded, narrow two-way special case, not a
        // general "prefer the indexed key" rule: `$name = 'Capitulum Vespera 1' if
        // $winner =~ /12-25/ && $vespera == 1;` and separately `$name = 'Capitulum
        // Vespera' if $winner =~ /C12/ && $hora eq 'Vespera';` (the not-yet-implemented
        // votive office, left as the existing plain fallback below). Confirmed real for
        // 24 December 2025 (first Vespers of Christmas): `Sancti/12-25.txt`'s own
        // `[Capitulum Vespera 1]` is "Titus 3:4-5" ("Appáruit benígnitas..."), the real
        // fixture's own text — trying `"Capitulum Laudes"` first (this project's own
        // earlier, un-special-cased version) found `[Capitulum Laudes]` instead
        // ("Heb 1:1-2", the *second* Vespers/Lauds text) since that key exists in the
        // same file and was tried unconditionally first.
        let capitulumSection = office.hasSuffix("12-25") && macroContext.isFirstVespers ? "Capitulum Vespera 1" : "Capitulum Laudes"
        if let capitulum = lookup(capitulumSection) ?? lookup("Capitulum Vespera") {
            sections.append(Section(kind: .capitulum, units: [
                .prose(Self.formatCapitulum(capitulum.latin), english: capitulum.english.map(Self.formatCapitulum)),
            ]))
        }
        // `hymnusmajor`'s own `checkmtv()` (`specials/hymni.pl:67-72`, `specials.pl:532-
        // 539`): "after 'Cum Nostra Hac Aetate'" -- Pope John XXIII's 1960 motu proprio
        // reforming the rubrics -- "the verse has always changed" for the Confessor
        // commons specifically (`$winner{Rule} =~ /C[45]/`): 1960 (among other
        // versions) swaps in the revised classical-meter hymn text, stored under a
        // `"Hymnus1 …"` key alongside the traditional `"Hymnus …"` one (real example:
        // `Commune/C4.txt`'s own `[Hymnus1 Vespera]`, a `@:Hymnus Vespera:s/…/…/`
        // substitution turning "Iste Conféssor…beátas Scándere sedes" into "…suprémos
        // Laudis honóres" — confirmed against the real fixture for 14 January 2025,
        // S. Hilary, whose own `[Rule]` references `C4`). Scoped exactly to this real,
        // narrow condition rather than guessing it might apply more broadly.
        let rawHymnusIsRevised = macroContext.winningRule.range(of: "C[45]", options: .regularExpression) != nil
        // `hymnusmajor`'s own reset-to-plain guard (`specials/hymni.pl:74-81`), confirmed
        // real and ported this session: `checkmtv` matches on the *Rule* field, which can
        // say `"vide C5"` (inheriting C5's own `[Rule]` behaviour) even when the office's
        // real Commune reference is a lettered variant like `"vide C5c"` whose own chain
        // eventually reaches C4 -- so `hymnusIsRevised` can fire correctly per the real
        // Perl's own identical regex, yet still be the *wrong* name to search with when
        // the office itself already has a perfectly good unrevised hymn of its own. Real
        // DO guards against exactly this: if the office's own file has neither the
        // revised name nor its indexed variant, but does have the plain (unrevised) name
        // or its indexed variant, the revision is dropped before any lookup happens.
        // Confirmed real for 12 February 2025 (Ss. Septem Fundatorum, whose own `[Rule]`
        // is `"vide C5"` — matching `C[45]` and triggering the revision — but whose own
        // file defines a proper `[Hymnus Vespera 3]`, "Matris sub almæ numine..."; without
        // this guard, the revised-name search skips past it, falls through the Commune
        // chain past C5c and C5 (neither of which defines a Vespers hymn of its own) to
        // C4's own revised `[Hymnus1 Vespera]`, "Iste Conféssor Dómini sacrátus...").
        let hymnusIsRevised: Bool
        if rawHymnusIsRevised {
            let officeHasRevisedPlain = resolver.sectionExists(path: office, section: "Hymnus1 Vespera")
            let officeHasRevisedIndexed = !macroContext.isFirstVespers && resolver.sectionExists(path: office, section: "Hymnus1 Vespera 3")
            let officeHasPlainIndexed = !macroContext.isFirstVespers && resolver.sectionExists(path: office, section: "Hymnus Vespera 3")
            let officeHasPlain = resolver.sectionExists(path: office, section: "Hymnus Vespera")
            let resetsToPlain = !officeHasRevisedPlain && !officeHasRevisedIndexed && (officeHasPlainIndexed || officeHasPlain)
            hymnusIsRevised = !resetsToPlain
        } else {
            hymnusIsRevised = false
        }
        let hymnusBaseSection = hymnusIsRevised ? "Hymnus1 Vespera" : "Hymnus Vespera"
        // `hymnusmajor`'s own second-Vespers-only extra attempt (`specials/hymni.pl:95-
        // 97`): before falling to the plain `"Hymnus Vespera"` key, second Vespers
        // specifically tries a `" 3"`-suffixed variant first — office's own file, then
        // Commune, exactly like the plain key's own fallback chain (reusing `lookup`'s
        // shared machinery, just without its Major Special tier for this first try).
        // First Vespers never gets an indexed attempt at all — confirmed by the real
        // Perl: the `$vespera == 3` guard around this extra `getproprium` call is
        // unconditional there, with no first-Vespers equivalent. Real example:
        // `Sancti/01-30.txt` (S. Martina, Virgin and Martyr, "vide C6") defines its own
        // `[Hymnus Vespera 3]` (a same-file cross-reference to `[Hymnus Laudes]`, a hymn
        // proper to her own office, not the Commune's generic one) — this project's
        // engine used to skip straight past it to the Commune's "Iesu, corona
        // Virginum" (Commune of Virgins), since it never tried the indexed key at all.
        let hymnusFromIndexedSection = macroContext.isFirstVespers ? nil : lookup("\(hymnusBaseSection) 3")
        if let hymnus = hymnusFromIndexedSection ?? lookup(hymnusBaseSection, majorSpecialSection: "Hymnus Vespera") {
            let latinStanzas = Self.hymnStanzas(hymnus.latin)
            let englishStanzas = hymnus.english.map(Self.hymnStanzas)
            let pairEnglish = englishStanzas?.count == latinStanzas.count
            let units = latinStanzas.enumerated().map { index, stanza in
                Unit.prose(stanza, english: pairEnglish ? englishStanzas?[index] : nil)
            }
            sections.append(Section(kind: .hymnus, units: units))
        }
        let primaryVersumIndex = macroContext.isFirstVespers ? 1 : 3
        let mirroredVersumIndex = 4 - primaryVersumIndex
        if let versus = ownOrCommune("Versum \(primaryVersumIndex)")
            ?? ownOrCommune("Versum \(mirroredVersumIndex)")
            ?? lookup("Versum \(primaryVersumIndex)")
        {
            // A `Versum` can carry its own literal `(Allelúja.)` in the source text (real
            // example: the Annunciation's own `[Versum 1]`, shared as-is between its
            // ordinary occurrence and the far rarer Paschaltide one) rather than an
            // inline `(sed tempore paschali)` conditional -- the same seasonal
            // add/strip `applyingSeasonalAlleluia` already applies to antiphons
            // (`assemblePsalmodia`/`assembleMagnificat`) needs to run here too. Confirmed
            // real for 24 March 2025 (first Vespers of the Annunciation, still Lent):
            // the real fixture's own versicle/response reads "Ave, María, grátia plena."
            // / "Dóminus tecum." with no "(Allelúja.)" at all — this project's engine
            // rendered the office's own literal parenthetical unstripped.
            let latinLines = versus.latin.split(separator: "\n", omittingEmptySubsequences: false)
                .map { Self.applyingSeasonalAlleluia(to: String($0), weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers) }
            let englishLines = versus.english?.split(separator: "\n", omittingEmptySubsequences: false)
                .map { Self.applyingSeasonalAlleluia(to: String($0), weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers) }
            sections.append(Section(kind: .versus, units: Self.unitsFromLines(latinLines, english: englishLines)))
        }
        return sections
    }

    /// The third fallback tier neither the office's own file nor a Commune reaches:
    /// `Psalterium/Special/Major Special.txt`, keyed by *today's own real day of the
    /// week* (not tomorrow's, even when tomorrow's first Vespers is what's actually
    /// being rendered — `horascommon.pl`'s `$dayofweek` is never swapped for this).
    /// Ports `capitulis.pl:5-23` (`capitulum_major`), `specials/hymni.pl:67-107`
    /// (`hymnusmajor`), and `specials.pl:571-653` (`getantvers`/`getfrompsalterium`) —
    /// traced in full and confirmed against the real fixture for 19 September 2026
    /// (Saturday, first Vespers of an ordinary Sunday after Pentecost): `Capitulum
    /// Laudes`/`Versum {1,3,2}` are keyed by `gettempora`'s `"Dominica"`/`"Feria"`
    /// (`dayOfWeek == 0 ? "Dominica" : "Feria"`), `Hymnus Vespera` by `"Day$dayOfWeek"`
    /// specifically — real Saturday entries land on a `(feria 7)`-conditioned variant
    /// (`Psalterium/Special/Major Special.txt`'s own `[Feria Vespera] (feria 7)`) that
    /// cross-references `Tempora/Pent01-0`'s own `Capitulum Laudes`/`Hymnus Vespera`
    /// directly — both the conditional and the cross-file `@` reference are already
    /// handled generically by `SectionResolver`, needing no special-casing here beyond
    /// building the right section name.
    ///
    /// **Now covers Advent/Lent/Passiontide/Ascension/Paschaltide/the week after
    /// Pentecost too** (`majorSpecialSeasonPrefix`, below) — originally confirmed
    /// correct for ordinary "time after Pentecost" dates only; extended after a full
    /// 2025-2040 content audit found the same fallback silently using the *ordinary*
    /// `Dominica`/`Feria`/`Day$dayOfWeek` naming for every season, when DO's own
    /// `gettempora()` gives Lenten (etc.) ferias a completely different, season-prefixed
    /// key instead. Confirmed real for 10 March 2025 (Monday, First Week of Lent):
    /// `Tempora/Quad1-1`'s own Vespers has no proper Capitulum/Hymnus/Versus of its own,
    /// and the real fixture's are Major Special's own `[Quad Vespera]` ("Joël 2:17..."),
    /// `[Hymnus Quad Vespera]` ("Audi, benígne Cónditor..."), and `[Quad Versum 3]` —
    /// not the ordinary-time `[Feria Vespera]` this project's engine fell to before.
    private func majorSpecialLocation(section: String, weekName: String, dayOfWeek: Int, resolver: SectionResolver) -> (path: String, section: String)? {
        let path = "Psalterium/Special/Major Special"
        let seasonPrefix = Self.majorSpecialSeasonPrefix(weekName: weekName, dayOfWeek: dayOfWeek)
        // Capitulum and Versum fall back to the ordinary `Dominica`/`Feria` naming
        // outside every named season; Hymnus falls back to `Day$dayOfWeek` instead
        // (`specials/hymni.pl:73-78`'s own separate `Hymnus major` branch) — two
        // different ordinary-time defaults sharing the same season detection.
        let capitulumOrVersumPrefix = seasonPrefix ?? (dayOfWeek == 0 ? "Dominica" : "Feria")
        let hymnusPrefix = seasonPrefix ?? "Day\(dayOfWeek)"

        if section == "Capitulum Laudes" {
            let name = "\(capitulumOrVersumPrefix) Vespera"
            return resolver.sectionExists(path: path, section: name) ? (path, name) : nil
        }
        if section == "Hymnus Vespera" {
            let name = "Hymnus \(hymnusPrefix) Vespera"
            return resolver.sectionExists(path: path, section: name) ? (path, name) : nil
        }
        if section.hasPrefix("Versum ") {
            // `getfrompsalterium`'s own fallback order for a `Versum $ind` miss: try the
            // asked index, then 1, then 3, then 2 (`specials.pl:648-651`).
            for ind in [section.replacingOccurrences(of: "Versum ", with: ""), "1", "3", "2"] {
                let name = "\(capitulumOrVersumPrefix) Versum \(ind)"
                if resolver.sectionExists(path: path, section: name) { return (path, name) }
            }
            return nil
        }
        return nil
    }

    /// Ports `gettempora()`'s own season detection (`horascommon.pl:2288-2343`) for the
    /// callers relevant to Major Special lookups (`'Capitulum major'`/`'Hymnus major'`/
    /// `'getfrompsalterium major'`, all matched by the same real `$caller =~ /^Capitulum
    /// |major$/` branch there — a Perl alternation-precedence trap: "starts with
    /// Capitulum" OR "ends with major", not "starts with Capitulum-or-major", but all
    /// three real caller strings satisfy it either way): Advent, Lent (weeks 1-4),
    /// Passiontide (weeks 5-6), Ascension week, Paschaltide, and the week after
    /// Pentecost each get their own season-prefixed Major Special key, taking priority
    /// over the ordinary "day of week" naming — which only actually applies outside
    /// every one of those seasons. `nil` means ordinary time.
    ///
    /// **Not ported**: the Ascension-week branch's own further `$dayname[1] !~
    /// /^Dominica/` guard (unconfirmed against a real fixture, and a narrow date range
    /// regardless); Advent's own `Adv3`-for-`Invitatorium` special case (Matins, out of
    /// this project's Vespers-only scope).
    private static func majorSpecialSeasonPrefix(weekName: String, dayOfWeek: Int) -> String? {
        if weekName.hasPrefix("Adv") { return "Adv" }
        if weekName.hasPrefix("Quad5") || weekName.hasPrefix("Quad6") { return "Quad5" }
        if weekName.hasPrefix("Quad"), !weekName.hasPrefix("Quadp") { return "Quad" }
        if weekName.hasPrefix("Pasc6") { return "Asc" }
        if weekName.hasPrefix("Pasc5"), dayOfWeek > 3 { return "Asc" }
        if weekName.range(of: "^Pasc[0-5]", options: .regularExpression) != nil { return "Pasch" }
        if weekName.hasPrefix("Pasc7") { return "Pent" }
        return nil
    }

    /// Ports DO's inline-Alleluia handling for antiphon text (`process_inline_alleluias`/
    /// `suppress_alleluia`, `LanguageTextTools.pm:39-73`, called for every displayed text
    /// block from `webdia.pl:681-685`). Some Commune/Sancti antiphon files carry a
    /// literal "Allelúia" annotation whose visibility depends on the season, not the
    /// office's own rank -- either bare (the Common of a Confessor-Bishop's own C4.txt
    /// "Sacerdótes Dei... Allelúia.") or parenthesized (the Annunciation's own proper
    /// "Missus est... (Allelúia.)"). Confirmed real for 22 February 2025 (Sexagesima
    /// week -- pre-Lent -- Chair of St Peter using Commune C4): the real fixture shows
    /// "...hymnum dícite Deo." with no "Allelúia" anywhere. And for 24 March 2025
    /// (Lent, the Annunciation's own proper antiphon): "...desponsátam Ioseph." with no
    /// "(Allelúia.)" either.
    ///
    /// Two rules combine, matching `webdia.pl:681-685`'s own order:
    /// - Outside Paschaltide, a *parenthesized* "(Allelúia...)" is removed entirely,
    ///   parens and all (`process_inline_alleluias`'s non-Paschal branch); inside
    ///   Paschaltide it's kept but unbracketed instead (confirmed unreachable by any
    ///   Vespers-only fixture this project's alpha scope covers, since this project has
    ///   no Paschaltide antiphon carrying this annotation yet -- ported for
    ///   faithfulness to the real condition, not confirmed against a real fixture).
    /// - From Septuagesima through Lent (`isAlleluiaSuppressed`, the same window
    ///   `suppress_alleluia`'s own call site gates on), *any* occurrence of the word
    ///   "Allelúia" -- parenthesized or bare -- is removed outright, along with an
    ///   immediately preceding comma or period (so "Deo. Allelúia." becomes "Deo.", the
    ///   trailing period surviving as the sentence's own new end, not the antiphon's
    ///   own original one).
    /// Outside both windows (ordinary time), a bare, unparenthesized "Allelúia" is real,
    /// fixed antiphon text (many Common-of-Saints antiphons genuinely end that way) and
    /// stays exactly as written.
    ///
    /// **Also ports `ensure_single_alleluia`** (`LanguageTextTools.pm:78-96`, called from
    /// `postprocess_ant`/`postprocess_vr` for every antiphon and versicle/response
    /// throughout Paschaltide, `horas.pl:675,687-690`): unlike the two rules above, which
    /// only ever *remove or unbracket* an alleluia the source text already carries, this
    /// one *adds* a trailing "', allelúia.'" during Paschaltide whenever the text doesn't
    /// already end with one — the far more common case, since most proper antiphons
    /// carry no alleluia annotation of their own at all. Confirmed real for 28 April
    /// 2025 (S. Pauli a Cruce, within the Easter Octave's own following weeks): the real
    /// fixture's own Magnificat antiphon reads "...cælo cóndidit ore, manu, allelúia.",
    /// where `Sancti/04-28.txt`'s own antiphon text ends plainly "...ore, manu." with no
    /// alleluia at all.
    private static func applyingSeasonalAlleluia(to text: String, weekName: String, isFirstVespers: Bool) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        let paschal = weekName.range(of: "Pasc", options: .caseInsensitive) != nil
        if paschal {
            result = result.replacingOccurrences(
                of: #"\((allel[uú][ij]a[^)]*)\)"#, with: " $1 ", options: [.regularExpression, .caseInsensitive]
            )
        } else {
            result = result.replacingOccurrences(
                of: #"\(allel[uú][ij]a[^)]*\)"#, with: "", options: [.regularExpression, .caseInsensitive]
            )
        }
        if Self.isAlleluiaSuppressed(weekName: weekName, isFirstVespers: isFirstVespers) {
            result = result.replacingOccurrences(
                of: #"[,.]?\s*allel[uú][ij]a"#, with: "", options: [.regularExpression, .caseInsensitive]
            )
        } else if paschal, result.range(of: #"allel[uú][ij]a\p{P}?\)?\s*$"#, options: [.regularExpression, .caseInsensitive]) == nil {
            result = result.replacingOccurrences(of: #"\p{P}?\s*$"#, with: "", options: .regularExpression)
            result += ", allelúia."
        }
        result = result.replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// The Septuagesima-to-Holy-Saturday Alleluia-suppression window
    /// (`suppress_alleluia`'s own gate, `webdia.pl:684-685`: `$dayname[0] =~
    /// /Quadp|Quad[1-5]|Quad6-[0-5]/`), matching this project's own `weekName` naming
    /// (`Quadp1`-`Quadp3` for Septuagesima/Sexagesima/Quinquagesima, `Quad1`-`Quad6` for
    /// Lent including Holy Week). **First Vespers of Septuagesima Sunday itself is
    /// exempted** (`Septuagesima_vesp()`, `horas.pl:214-221`): it's the last office
    /// where Alleluia is still said, even though the office being prayed (`weekName`,
    /// already the *next* day's for a first-Vespers office) already reads `"Quadp1"`.
    ///
    /// **Not ported**: `Quad6-[0-5]`'s own exclusion of day 6 specifically (Holy
    /// Saturday) -- this project's `weekName` doesn't carry Holy Week's own day-within-
    /// week number, and Holy Saturday's Vespers is a Triduum-rubric special case out of
    /// this project's current scope regardless; treating all of `Quad6` as suppressed
    /// is the safe, cautious default until the Triduum itself is implemented.
    private static func isAlleluiaSuppressed(weekName: String, isFirstVespers: Bool) -> Bool {
        guard weekName.range(of: "^(Quadp[1-3]|Quad[1-5]|Quad6)", options: .regularExpression) != nil else { return false }
        if weekName == "Quadp1", isFirstVespers { return false }
        return true
    }

    /// Ports `specials.pl:83-94`'s own "omit this section if the rule says so" check:
    /// `$rule =~ /Omit.*? $ite/i`, where `$ite` is the skeleton's own `#Name` marker's
    /// *first word* (our own skeleton groups already match this shape one-for-one —
    /// `Ordinarium/Vespera.txt`'s own `#Capitulum Hymnus Versus` marker's first word is
    /// `"Capitulum"`, so an `[Rule]` that lists `"Capitulum"` after `"Omit"` hides the
    /// whole combined group, Versus included). `.` doesn't cross lines in Perl's own
    /// default (non-`/s`) regex mode, so this only checks the single line `"Omit"`
    /// itself appears on, matching every real `[Rule]`'s own single-line `"Omit A B
    /// C..."` layout. A substring match, not a whole-word one, is DO's own actual
    /// behaviour here (not a simplification): `keyword` `"Conclusio"` (our own marker's
    /// spelling) matches a rule that says `"Conclusion"` (the English-suffixed spelling
    /// some real `[Rule]`s use, e.g. Holy Saturday's own) purely because `"Conclusio"` is
    /// a literal prefix of `"Conclusion"` — confirmed real against Holy Saturday's own
    /// fixture (19 April 2025): `[Rule]`'s own `"...Preces Suffragium Conclusion
    /// Martyrologium..."` line hides `Conclusio{omittitur}` exactly where the real page
    /// shows it.
    private static func ruleOmits(rule: String, keyword: String) -> Bool {
        for line in rule.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let omitRange = line.range(of: "Omit", options: .caseInsensitive) else { continue }
            if line[omitRange.upperBound...].range(of: " \(keyword)", options: .caseInsensitive) != nil { return true }
        }
        return false
    }

    /// Ports `specials.pl:60-81`'s own "Capitulum Versum 2" rule-text parsing: `nil`
    /// when the rule doesn't mention it at all, else whatever qualifier text (if any)
    /// follows it on the same line up to the next `;` — an empty string for an
    /// unqualified rule (applies everywhere, Vespers included), or e.g. `"ad Laudes
    /// tantum"` to restrict it to Laudes only. The caller only needs to distinguish
    /// "applies to Vespers" from "doesn't" (this project only ever renders Vespers), so
    /// the real Perl's own `"nisi ad Laudes"`/`"ad Laudes et Vesperas"` branches (which
    /// only matter for hours besides Vespers) aren't ported separately.
    private static func capitulumVersum2Qualifier(rule: String) -> String? {
        for line in rule.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let range = line.range(of: "Capitulum Versum 2", options: .caseInsensitive) else { continue }
            var qualifier = String(line[range.upperBound...])
            if let semicolon = qualifier.firstIndex(of: ";") { qualifier = String(qualifier[..<semicolon]) }
            return qualifier.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// Ports `triduum_gloria_omitted()` (`horas.pl:223-234`): the Gloria Patri doxology
    /// after each psalm/canticle is omitted from Maundy Thursday's own Vespers through
    /// Holy Saturday's (`Quad6`, days 4-6 -- Thursday/Friday/Saturday -- but *not* first
    /// Vespers, e.g. Palm Sunday's own second Vespers reaching into Holy Monday still
    /// keeps its Gloria). Confirmed real for 19 April 2025 (Holy Saturday): every one of
    /// the real fixture's five psalms and the Magnificat itself end "Gloria omittitur"
    /// with no Gloria Patri text at all, immediately followed by the antiphon's own
    /// repeat.
    ///
    /// **Not ported**: the Perl's own documented imprecision here (`horas.pl`'s own
    /// `dayofweek > 3` -- our `dayOfWeek` -- is a coarser proxy than "today's own
    /// office," by its own author's admission) — this project's `weekName`/`dayOfWeek`
    /// pairing already reflects the *office actually being prayed* (this project's own
    /// "first Vespers of tomorrow" adjustment), which is a strictly more precise signal
    /// than what the real Perl had available, so the same coarse proxy isn't needed here.
    private static func isTriduumGloriaOmitted(weekName: String, dayOfWeek: Int, isFirstVespers: Bool) -> Bool {
        weekName.hasPrefix("Quad6") && dayOfWeek > 3 && !isFirstVespers
    }

    /// Splits a raw resolved `[Hymnus Vespera]` body into its own stanzas, cleaning two
    /// conventions confirmed real (16 September 2026's own hymn, `Commune/C3.txt`) but
    /// not referenced anywhere in DO's own Perl (an exhaustive search of
    /// `horas.pl`/`specials/hymni.pl` turned up nothing — this project's own
    /// best-evidence read of what the real rendered fixture shows, not a cited
    /// mechanism):
    ///
    /// - A leading `{:H-Name:}` tune-identifier prefix (GABC chant-tune metadata,
    ///   confirmed absent from the real fixture's rendered text entirely) — stripped
    ///   outright, consistent with `CLAUDE.md`'s "no chant" scope.
    /// - The leading `v. ` drop-cap marker (`do-format.md`'s already-documented
    ///   "decorative styling for the first letter, not a liturgical marker" — the same
    ///   treatment `DOMarkers.stripLineLabel` already gives it elsewhere) on the first
    ///   stanza only, since it only ever appears at the very start of the whole hymn.
    ///
    /// Each stanza-break `_`-only line marks a genuine stanza boundary, so this returns
    /// one `.prose`-ready string per stanza rather than one long blob joined by blank
    /// lines — direct feedback: a real long hymn rendered as a single unit was cut off,
    /// since a single oversized block can't be split across pages like everything else.
    private static func hymnStanzas(_ text: String) -> [String] {
        var cleaned = text
        if let range = cleaned.range(of: #"^\{:.*?:\}"#, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }

        // The `v. ` drop-cap marker belongs to the first genuine line of hymn content --
        // usually `line 0`, but a whole-line small-font stage direction (see
        // `stripSmallFontMarkers` below) can precede it, real example: `Commune/C11.txt`'s
        // own `[Hymnus Vespera]` opens with `/:Prima stropha...:/` *before* `v. Ave maris
        // stella,`. Found the same way as the small-font marker itself (checking real
        // fixtures directly, not cited in DO's own Perl) -- the old whole-string
        // `hasPrefix` check silently did nothing whenever such a preface line was present,
        // leaving a literal `"v. "` in the rendered text.
        var lines = cleaned.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if let firstContentIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("/:") }) {
            lines[firstContentIndex] = DOMarkers.stripLineLabel(lines[firstContentIndex])
        }
        lines = lines.map(DOMarkers.stripSmallFontMarkers)
        // A `!`-marked line mid-hymn is DO's own real "red line" rubric convention
        // (`horas.pl:167-172`'s `s/^\!(.*)/setfont($redfont, $1)/`) — a genuflection
        // direction between two stanzas, not the whole-hymn-opening kind
        // `stripSmallFontMarkers`/the drop-cap search above already handle. Confirmed
        // real for 5 April 2025 (Passiontide): `Psalterium/Special/Major Special.txt`'s
        // own Passiontide hymn ("Vexilla Regis") carries a lone `!Sequens stropha dicitur
        // flexis genibus.` line right before its own "O Crux, ave..." stanza; this
        // project's engine rendered the literal `!` instead of stripping it (unlike
        // `unitsFromLines`/`unitsFromResolvedText`, which already check
        // `DOMarkers.isRubricLine` elsewhere -- `hymnStanzas` never did).
        lines = lines.map { DOMarkers.isRubricLine($0) ? DOMarkers.stripRubricMarkers($0) : $0 }
        cleaned = lines.joined(separator: "\n")

        var stanzas: [String] = []
        var current: [String] = []
        for line in cleaned.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces) == "_" {
                if !current.isEmpty { stanzas.append(current.joined(separator: "\n")) }
                current = []
            } else {
                current.append(String(line))
            }
        }
        if !current.isEmpty { stanzas.append(current.joined(separator: "\n")) }

        // A later stanza (real example: `Sancti/01-06.txt`'s own `[Hymnus Vespera]`,
        // the closing "Iesu, tibi sit glória..." doxology) can carry its own leading
        // `* ` marker -- confirmed real via the 5 January 2026 fixture, which renders
        // that stanza with no leading asterisk at all. Not referenced anywhere in DO's
        // own Perl (the same "found by comparing real fixtures, not cited" situation as
        // the `v. ` drop-cap marker above) -- a structural marker on the stanza itself,
        // stripped the same way, not liturgical content.
        return stanzas.map { $0.hasPrefix("* ") ? String($0.dropFirst(2)) : $0 }
    }

    /// Cleans a resolved `[Capitulum Laudes]`/`[Capitulum Vespera]` body into the single
    /// prose paragraph DO itself renders it as — ports `capitulis.pl`'s own
    /// `_format_capitulum` (`capitulis.pl:262-270`): the citation line's leading `!`
    /// rubric marker is dropped (shown as plain text, not in the rubric colour —
    /// confirmed real: the citation appears in the same white serif as the reading, not
    /// red), the reading line's leading `v. ` drop-cap marker is dropped
    /// (`DOMarkers.stripLineLabel`'s usual treatment — it's decorative styling, not a
    /// real versicle), and the closing `$Deo gratias` macro (already macro-expanded by
    /// `SectionResolver` to `"R. Deo grátias."` by the time this runs) has its `R.`
    /// label turned into the real `℟.` glyph DO's own rendering uses there — *not*
    /// stripped away the way a genuine versicle/response *pair* is elsewhere
    /// (`CLAUDE.md`'s "no ℣/℟ glyphs" rule is for indented V/R pairs specifically; this
    /// is a citation-plus-reading-plus-acclamation paragraph with no versicle to pair
    /// against, so it stays one `.prose` unit). Confirmed against the real oracle
    /// fixture for 16 September 2026 (`Commune/C3.txt`'s own `[Capitulum Laudes]`,
    /// reached via this session's own "Laudes"-first key change): raw
    /// `"!Sap 3:1-3\nv. Iustórum ánimæ...pace.\nR. Deo grátias."` becomes
    /// `"Sap 3:1-3 Iustórum ánimæ...pace. ℟. Deo grátias."`, matching the fixture
    /// exactly.
    private static func formatCapitulum(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let cleaned = lines.map { line -> String in
            if DOMarkers.isRubricLine(line) {
                return DOMarkers.stripRubricMarkers(line)
            }
            if line.hasPrefix("R.") || line.hasPrefix("r.") {
                return "℟." + line.dropFirst(2)
            }
            return DOMarkers.stripLineLabel(line)
        }
        return cleaned.joined(separator: " ")
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
    private func assemblePrecesFeriales(
        winner: OccurrenceResult, month: Int, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section? {
        guard shouldShowPrecesFeriales(
            winner: winner, weekName: macroContext.weekName, dayOfWeek: macroContext.dayOfWeek, month: month, rule: macroContext.winningRule
        ) else { return nil }

        let text = resolver.resolve(path: "Psalterium/Special/Major Special", section: "Preces feriales Vespera")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let latinUnits = Self.unitsFromPrecesLines(lines)

        let englishUnits: [Unit]? = englishResolver.map { eng in
            let englishText = eng.resolve(path: "Psalterium/Special/Major Special", section: "Preces feriales Vespera")
            return Self.unitsFromPrecesLines(englishText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        }
        return Section(kind: .precesFeriales, units: Self.mergeEnglish(latinUnits, englishUnits))
    }

    /// Pairs two independently-classified `Unit` arrays for the same content (Latin and
    /// English resolved and split the same way) by position, attaching English's text
    /// to Latin's unit — used where re-deriving a location-tracked lookup per piece
    /// would be overkill (fixed, single-source content like the Preces). Falls back to
    /// Latin-only if the counts don't match or a pair's shapes diverge (e.g. one side
    /// classified a line as `.rubric` and the other as `.prose`) — never guesses at a
    /// pairing it isn't sure of.
    private static func mergeEnglish(_ latinUnits: [Unit], _ englishUnits: [Unit]?) -> [Unit] {
        guard let englishUnits, englishUnits.count == latinUnits.count else { return latinUnits }
        return zip(latinUnits, englishUnits).map { latin, english in
            switch (latin, english) {
            case (.rubric(let l, _), .rubric(let e, _)): return .rubric(l, english: e)
            case (.versicleResponse(let lv, let lr, _, _), .versicleResponse(let ev, let er, _, _)):
                return .versicleResponse(versicle: lv, response: lr, versicleEnglish: ev, responseEnglish: er)
            case (.verse(let ref, let lf, let ls, _, _), .verse(_, let ef, let es, _, _)):
                return .verse(reference: ref, firstHalf: lf, secondHalf: ls, firstHalfEnglish: ef, secondHalfEnglish: es)
            case (.antiphon(let l, _), .antiphon(let e, _)): return .antiphon(l, english: e)
            case (.prose(let l, _), .prose(let e, _)): return .prose(l, english: e)
            default: return latin
            }
        }
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

/// `Psalmi major.txt`'s own verse-range notation for a psalm split across two of the
/// hour's five Vespers slots -- e.g. Friday's `"138(1-13)"` / `"138(14-24)"`, or
/// Saturday's `"144(8-'13a')"` / `"144('13b'-21)"`, whose quoted-letter boundary lands
/// mid-verse (confirmed real: `Psalm144.txt`'s own verse 13 is itself split into
/// `"144:13a"`/`"144:13b"` lines). Ported from `psalmi.pl`'s `psalm` `ScriptFunc`
/// (`horasscripts.pl:437-617`): `$v1`/`$c1` and `$v2`/`$c2` are the start/end verse
/// number and optional sub-verse letter, and the boundary rule at `horasscripts.pl:
/// 608-617` is what `contains(verse:letter:)` ports.
struct PsalmVerseRange: Equatable {
    var startVerse: Int
    var startLetter: Character?
    var endVerse: Int
    var endLetter: Character?

    /// Splits `"138(1-13)"` into its bare psalm number and the range to keep, or `nil`
    /// for an unsplit number like `"138"` (no parentheses at all).
    static func parse(_ token: String) -> (base: String, range: PsalmVerseRange)? {
        guard let openParen = token.firstIndex(of: "("), token.hasSuffix(")") else { return nil }
        let base = String(token[token.startIndex..<openParen])
        let inner = token[token.index(after: openParen)..<token.index(before: token.endIndex)]
        guard let dashIndex = inner.firstIndex(of: "-"),
            let start = parseBoundary(String(inner[inner.startIndex..<dashIndex])),
            let end = parseBoundary(String(inner[inner.index(after: dashIndex)...]))
        else { return nil }
        return (base, PsalmVerseRange(startVerse: start.verse, startLetter: start.letter, endVerse: end.verse, endLetter: end.letter))
    }

    /// Parses one boundary token -- `"1"`, `"13"`, or the quoted lettered form `"'13a'"`
    /// (the source data only ever quotes the lettered form, never a bare number).
    private static func parseBoundary(_ token: String) -> (verse: Int, letter: Character?)? {
        verseNumberAndLetter(fromVerseString: token.trimmingCharacters(in: CharacterSet(charactersIn: "'")))
    }

    /// Extracts a verse's number and optional sub-verse letter from its own full
    /// reference (e.g. `"144:13a"` -> psalm 144's own verse 13, letter `'a'`) --
    /// references use `psalm:verse` for psalms and `chapter:verse` for canticles, so
    /// only the part after the last `:` is the boundary-comparable "verse" `psalmi.pl`'s
    /// own `$v`/`$c` mean.
    static func verseNumberAndLetter(fromReference reference: String) -> (verse: Int, letter: Character?)? {
        guard let colonIndex = reference.lastIndex(of: ":") else { return nil }
        return verseNumberAndLetter(fromVerseString: String(reference[reference.index(after: colonIndex)...]))
    }

    private static func verseNumberAndLetter(fromVerseString verseString: String) -> (verse: Int, letter: Character?)? {
        let letter = verseString.last.flatMap { $0.isLetter ? $0 : nil }
        let digits = letter != nil ? String(verseString.dropLast()) : verseString
        guard let verse = Int(digits) else { return nil }
        return (verse, letter)
    }

    /// `psalmi.pl`'s own boundary rule (`horasscripts.pl:608-617`): a verse whose number
    /// equals the start keeps only sub-verses at or after the start's own letter (the
    /// whole verse, if the start itself has no letter); a verse equal to the end keeps
    /// only sub-verses at or before the end's own letter; anything strictly between the
    /// two numbers is kept whole.
    func contains(verse: Int, letter: Character?) -> Bool {
        if verse == startVerse { return startLetter == nil || (letter ?? "a") >= startLetter! }
        if verse == endVerse { return endLetter == nil || (letter ?? "z") <= endLetter! }
        return verse > startVerse && verse < endVerse
    }
}
