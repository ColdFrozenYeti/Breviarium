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

        // `Ordinarium/Vespera` is language-neutral scaffolding (shared, not duplicated
        // per language — see `BreviariumDataPipeline`'s own doc comment), so resolving
        // it again against an English-backed resolver walks the *same* `#Name`-grouped
        // structure, just with `&`/`$` macros bottoming out in English text instead.
        let englishResolver = englishCorpus.map { SectionResolver(corpus: $0, context: context, macroContext: macroContext, isEnglish: true) }
        let englishGroups: [String: SkeletonGroup] = englishResolver.map { resolver in
            let text = resolver.resolve(path: "Ordinarium/Vespera", section: RawSectionParser.wholeFileSectionName)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            return Dictionary(Self.groupSkeletonLines(lines).map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        } ?? [:]

        var sections: [Section] = []
        for group in groups {
            switch group.name {
            case "Incipit":
                sections.append(Section(kind: .introductio, units: Self.unitsFromLines(group.lines, english: englishGroups[group.name]?.lines)))
            case "Psalmi":
                sections.append(assemblePsalmodia(
                    office: winner.winningPath, resolver: resolver, macroContext: macroContext, dayOfWeek: macroContext.dayOfWeek,
                    englishResolver: englishResolver
                ))
            case "Canticum: Magnificat":
                sections.append(assembleMagnificat(office: winner.winningPath, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
            case "Oratio":
                // Ports orationes.pl:34,63-74's `$ind = $hora eq 'Vespera' ? $vespera : 2`
                // priority: an `[Oratio 1]` (first Vespers) or `[Oratio 3]` (second
                // Vespers, our common case) wins over the plain `[Oratio]` whenever it
                // exists -- same discovery and real example (Commune/C3.txt, Ss.
                // Cornelii et Cypriani) as assemblePsalmodia's Ant Vespera 3 handling.
                let indexedOratio = "Oratio \(macroContext.isFirstVespers ? 1 : 3)"
                let oratioLocation = resolvedLocation(
                    office: winner.winningPath, communeReference: winner.winningRank.communeReference, section: indexedOratio, resolver: resolver
                ) ?? resolvedLocation(
                    office: winner.winningPath, communeReference: winner.winningRank.communeReference, section: "Oratio", resolver: resolver
                )
                if let oratioLocation {
                    let collect = resolver.resolve(path: oratioLocation.path, section: oratioLocation.section)
                    let named = substituteName(in: collect, office: winner.winningPath, resolver: resolver)
                    // English only if it has this *exact* section too -- never a
                    // different (mismatched) one, per this case's own doc comment on
                    // `resolvedLocation`.
                    let englishCollect: String? = englishResolver.flatMap { eng in
                        guard eng.sectionExists(path: oratioLocation.path, section: oratioLocation.section) else { return nil }
                        let text = eng.resolve(path: oratioLocation.path, section: oratioLocation.section)
                        return substituteName(in: text, office: winner.winningPath, resolver: eng)
                    }
                    var oratioUnits = Self.unitsFromResolvedText(named, english: englishCollect)
                    oratioUnits.append(contentsOf: assembleCommemorations(
                        day: day, month: month, year: year, winningRank: winner.winningRank, resolver: resolver, macroContext: macroContext
                    ))
                    sections.append(Section(kind: .oratio, units: oratioUnits))
                }
            case "Conclusio":
                sections.append(Section(kind: .conclusio, units: Self.unitsFromLines(group.lines, english: englishGroups[group.name]?.lines)))
            case "Capitulum Hymnus Versus":
                sections.append(contentsOf: assembleCapitulumHymnusVersus(
                    office: winner.winningPath, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver
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
        let latinLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { DOMarkers.stripLineLabel(String($0)) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let englishLines = english?.split(separator: "\n", omittingEmptySubsequences: false)
            .map { DOMarkers.stripLineLabel(String($0)) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let paired = (englishLines?.count == latinLines.count) ? englishLines : nil

        return latinLines.enumerated().map { index, line in .prose(line, english: paired?[index]) }
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
    private func resolvedLocation(office: String, communeReference: String, section: String, resolver: SectionResolver) -> (path: String, section: String)? {
        if resolver.sectionExists(path: office, section: section) { return (office, section) }
        guard let fallbackPath = Self.communeFallbackPath(communeReference), resolver.sectionExists(path: fallbackPath, section: section)
        else { return nil }
        return (fallbackPath, section)
    }

    /// A section this office doesn't define at all, falling back to its Commune.
    private func resolveWithCommuneFallback(office: String, communeReference: String, section: String, resolver: SectionResolver) -> String? {
        resolvedLocation(office: office, communeReference: communeReference, section: section, resolver: resolver)
            .map { resolver.resolve(path: $0.path, section: $0.section) }
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

        let ind = macroContext.isFirstVespers ? 1 : 3
        return toRender.flatMap { commemorationUnits(for: $0, ind: ind, weekName: macroContext.weekName, resolver: resolver) ?? [] }
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
            resolvedLocation(office: commemoration.path, communeReference: communeReference, section: section, resolver: resolver)
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
    private func assemblePsalmodia(
        office: String, resolver: SectionResolver, macroContext: MacroContext, dayOfWeek: Int, englishResolver: SectionResolver?
    ) -> Section {
        let communeReference = macroContext.winningRank.communeReference
        let communeReferenceIsEx = communeReference.range(of: "^ex\\s", options: [.regularExpression, .caseInsensitive]) != nil

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
            if pairs.isEmpty, let fifthPsalm = festalFifthPsalmNumber(
                office: office, communeReference: communeReference, resolver: resolver, isFirstVespers: macroContext.isFirstVespers
            ) {
                let antiphons = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).filter { !$0.isEmpty }
                let festalNumbers = ["109", "110", "111", "112", fifthPsalm]
                pairs = zip(antiphons, festalNumbers).map { ($0, $1) }
            }
            return (pairs, pairs.isEmpty ? nil : loc)
        }

        var pairs: [(antiphon: String, psalmNumber: String)] = []
        var winningLocation: (path: String, section: String)?
        if !macroContext.isFirstVespers {
            (pairs, winningLocation) = candidatePairs(section: "Ant Vespera 3", allowCommune: communeReferenceIsEx)
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

        var units: [Unit] = []
        for (index, pair) in pairs.enumerated() {
            let english = index < englishAntiphons.count ? englishAntiphons[index] : nil
            var psalmContent = psalmUnits(number: pair.psalmNumber, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)

            // Direct feedback, comparing a real rendering against real DO output: when
            // the antiphon's own words exactly equal the psalm's first verse (a real,
            // common case -- e.g. Psalm 132's antiphon "Ecce quam bonum..." verbatim
            // repeats 132:1), DO marks this with a "‡" at the end of the antiphon and
            // another at the start of the second verse (getantcross(), horas.pl:238-278).
            // Ported for exactly this whole-first-verse case, not DO's fully general
            // "dagger anywhere N words into the psalm" algorithm, which treats the whole
            // psalm as one continuous word stream rather than per-verse and would need a
            // bigger restructuring than this warrants.
            var antiphonText = pair.antiphon
            if let firstVerseText = Self.firstVerseText(in: psalmContent),
                Self.antiphonMatchesWholeVerse(antiphon: pair.antiphon, verseText: firstVerseText)
            {
                antiphonText = "\(pair.antiphon) ‡"
                psalmContent = Self.addingLeadingDagger(toSecondVerseOf: psalmContent)
            }

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

    /// The first `.verse` unit's full text (both halves rejoined) -- used only to check
    /// against the antiphon for the dagger rule above.
    private static func firstVerseText(in units: [Unit]) -> String? {
        for unit in units {
            if case .verse(_, let firstHalf, let secondHalf, _, _) = unit {
                return "\(firstHalf) \(secondHalf)".trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Prepends "‡ " to the second `.verse` unit's `firstHalf` (Gloria's own two lines
    /// count as `.verse` too, but the dagger rule only ever concerns a psalm's own
    /// verse 2, which always comes first).
    private static func addingLeadingDagger(toSecondVerseOf units: [Unit]) -> [Unit] {
        var verseCount = 0
        return units.map { unit in
            guard case .verse(let reference, let firstHalf, let secondHalf, let firstEnglish, let secondEnglish) = unit else { return unit }
            verseCount += 1
            guard verseCount == 2 else { return unit }
            return .verse(
                reference: reference, firstHalf: "‡ \(firstHalf)", secondHalf: secondHalf,
                firstHalfEnglish: firstEnglish, secondHalfEnglish: secondEnglish
            )
        }
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

    private static func depunctuatedWords(_ text: String) -> [String] {
        text.split(separator: " ").compactMap { depunctuatedWord($0) }
    }

    /// Ports `getantcross()`'s word-by-word matching (`horas.pl:238-278`), scoped to an
    /// exact whole-verse match (see the dagger rule's own doc comment in
    /// `assemblePsalmodia` for what's not attempted).
    private static func antiphonMatchesWholeVerse(antiphon: String, verseText: String) -> Bool {
        let antiphonWords = depunctuatedWords(antiphon)
        guard !antiphonWords.isEmpty else { return false }
        return antiphonWords == depunctuatedWords(verseText)
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
    private func gloriaUnits(resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?) -> [Unit] {
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
    private func assembleMagnificat(office: String, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?) -> Section {
        // `"Ant 3"` is keyed by the same first/second-Vespers index as `assemblePsalmodia`'s
        // `Ant Vespera 3` and the Oratio case's `Oratio 3` (`orationes.pl:34`'s `$ind` --
        // 1 for first Vespers, 3 for second): `[Ant 1]`/`[Ant 3]` sit right after
        // `[Versum 1]`/`[Versum 3]` in a Commune file's own chronological layout (real
        // example: `Commune/C1.txt`/`C3.txt`), each hour's own Magnificat-slot antiphon,
        // not a fixed "3" regardless of which Vespers is being sung.
        let ind = macroContext.isFirstVespers ? 1 : 3
        let communeReference = macroContext.winningRank.communeReference
        var units: [Unit] = []
        let plainLocation = resolvedLocation(office: office, communeReference: communeReference, section: "Ant \(ind)", resolver: resolver)
        let numberedLocation = resolvedLocation(office: office, communeReference: communeReference, section: "Ant Vespera \(ind)", resolver: resolver)
        if let location = plainLocation ?? numberedLocation {
            let text = resolver.resolve(path: location.path, section: location.section)
            let antiphon = text.split(separator: "\n", omittingEmptySubsequences: false).first
                .map { String($0).components(separatedBy: ";;").first ?? String($0) }
            if let antiphon, !antiphon.isEmpty {
                let english: String? = englishResolver.flatMap { eng in
                    guard eng.sectionExists(path: location.path, section: location.section) else { return nil }
                    let englishText = eng.resolve(path: location.path, section: location.section)
                    return englishText.split(separator: "\n", omittingEmptySubsequences: false).first
                        .map { String($0).components(separatedBy: ";;").first ?? String($0) }
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
        office: String, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> [Section] {
        let communeReference = macroContext.winningRank.communeReference
        func lookup(_ section: String) -> (latin: String, english: String?)? {
            guard let location = resolvedLocation(office: office, communeReference: communeReference, section: section, resolver: resolver)
            else { return nil }
            let latin = resolver.resolve(path: location.path, section: location.section)
            let english = englishResolver.flatMap { eng in
                eng.sectionExists(path: location.path, section: location.section) ? eng.resolve(path: location.path, section: location.section) : nil
            }
            return (latin, english)
        }

        var sections: [Section] = []
        if let capitulum = lookup("Capitulum Vespera") {
            sections.append(Section(kind: .capitulum, units: [.prose(capitulum.latin, english: capitulum.english)]))
        }
        if let hymnus = lookup("Hymnus Vespera") {
            let latinStanzas = Self.hymnStanzas(hymnus.latin)
            let englishStanzas = hymnus.english.map(Self.hymnStanzas)
            let pairEnglish = englishStanzas?.count == latinStanzas.count
            let units = latinStanzas.enumerated().map { index, stanza in
                Unit.prose(stanza, english: pairEnglish ? englishStanzas?[index] : nil)
            }
            sections.append(Section(kind: .hymnus, units: units))
        }
        if let versus = lookup("Versum \(macroContext.isFirstVespers ? 1 : 3)") {
            let latinLines = versus.latin.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let englishLines = versus.english?.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            sections.append(Section(kind: .versus, units: Self.unitsFromLines(latinLines, english: englishLines)))
        }
        return sections
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
        cleaned = DOMarkers.stripLineLabel(cleaned)

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
        return stanzas
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
