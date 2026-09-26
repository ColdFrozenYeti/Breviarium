import Foundation

/// Resolves a section's full text against a complete `ConditionalContext`: evaluates
/// `[Name] (condition)` header variants to pick a winner, runs
/// `ConditionalLineProcessor` on its body, and follows `@` inclusions and `$` prayer
/// macros recursively. This is the actual render-time entry point the pieces in
/// `ConditionalEvaluator`/`ConditionalGrammar`/`ConditionalLineProcessor` exist to serve.
///
/// `&` script macros (`do-format.md`) resolve too, but only when `macroContext` is
/// supplied — `ScriptMacros` needs day/context-specific facts (`$rank`, `$priest`,
/// `$vespera`...) that live in the office-assembly layer, not in `ConditionalContext`
/// itself, so a resolver used purely for plain section text (no macro context) leaves
/// `&Name` lines untouched, same as an unresolvable `@`/`$` reference.
public struct SectionResolver {
    public var corpus: OfficeCorpus
    public var context: ConditionalContext
    public var macroContext: MacroContext?
    /// True when `corpus` is DO's English tree, never orthography-normalised — a small
    /// number of `ScriptMacros` lookups (`&Deus_in_adjutorium`) need this because the
    /// section name they query differs: `Prayers.txt`'s Latin header is stored
    /// J-to-I-normalised (`"Deus in adiutorium"`), but the English header keeps its own
    /// literal spelling (`"Deus in adjutorium"`, with a `j` — English text is never
    /// touched by that normalisation pass).
    public var isEnglish: Bool

    /// Where `$Name` macros resolve from (`do-format.md`).
    public static let prayersPath = "Psalterium/Common/Prayers.txt"

    /// A `$`-line can carry one of two special sigil prefixes instead of naming a
    /// `Prayers.txt` entry directly, each dispatching to its own separate file
    /// (`webdia.pl`'s `expand()`: `$rubrica ` -> `rubric()` -> `Rubricae.txt`, `$Preces `
    /// -> `prex()` -> `Preces.txt` — distinct hashes from `prayer()`'s `Prayers.txt`,
    /// confirmed while tracing why `Preces.txt`'s own `[Preces feriales Vespera]`
    /// section body literally names itself (`$Preces feriales Vespera`) without
    /// recursing: it isn't a `$Name` self-reference at all, it's this sigil resolving
    /// to a completely different file).
    private static let sigilPaths: [(prefix: String, path: String)] = [
        ("rubrica ", "Psalterium/Common/Rubricae.txt"),
        ("Preces ", "Psalterium/Special/Preces.txt"),
    ]

    /// Matches `setupstring()`'s own nesting cap (`SetupString.pl:698`: `$iiij++ > 6`).
    private static let maxInclusionDepth = 6

    public init(corpus: OfficeCorpus, context: ConditionalContext, macroContext: MacroContext? = nil, isEnglish: Bool = false) {
        self.corpus = corpus
        self.context = context
        self.macroContext = macroContext
        self.isEnglish = isEnglish
    }

    /// Resolves one section to its final text.
    public func resolve(path: String, section: String) -> String {
        // `horas.pl:117`: a line ending in `~` runs on into the next one as DO shows it
        // (Pent13-0's `[Ant 2]`, "Cum transíret ~" / "Iesus * quoddam castéllum…",
        // with a rubric-conditional alternative between them).
        let text = resolveSection(path: path, section: section, depth: 0)
        guard text.contains("~") else { return text }
        // The next line's own "r." (first letter red, `horas.pl:178`) goes before the
        // merge: Preces' "Orémus pro Pontífice nostro~" / "r. N.".
        return text.replacingOccurrences(of: #"[ \t]*~[ \t]*\n[ \t]*(?:r\.[ \t]*)?"#, with: " ", options: .regularExpression)
    }

    /// Whether `path` actually resolves `section` under the current `context` — not just
    /// whether a raw section by that name is present on disk at all, which real files
    /// often have with every one of its variants gated to a *different* rubric (e.g.
    /// `Sancti/09-14.txt`'s own `[Ant Vespera] (rubrica cisterciensis)`, the Holy Cross's
    /// only variant of that section, present in the file but never true under Rubrics
    /// 1960). Checking raw presence alone made a caller like `HourAssembler`'s Commune
    /// fallback (`resolvedLocation`, and `assemblePsalmodia`'s own inline `location`)
    /// conclude the office already defines the section itself and skip the fallback
    /// entirely -- the office's own lookup then found no true-conditioned variant either
    /// and printed the `"<path>:<section> is missing!"` placeholder verbatim into
    /// rendered content. Found via a full sweep across 2025-2040
    /// (`OracleTests.vespersAssemblesWithoutPlaceholderTextAcrossTheFullOracleRange`)
    /// turning up ~260 instances across a dozen distinct
    /// files, every single one this exact shape: a rubric-gated-only section with no
    /// plain fallback variant of its own. `winningVariant` already has the correct,
    /// already-tested condition-matching logic (`resolve()` itself is built on it) --
    /// this was simply the one caller not consulting it.
    /// One `$Name` or `&Name` line as DO expands it (a prayer, a rubric, a script
    /// macro); any other line as it is. Beta 3: Matins emits these line by line
    /// (`$Pater noster Et`, `$rubrica Pater secreto`, `$Jube domne`).
    public func expandMacroLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.first == "$" { return resolvePrayerMacroLine(String(trimmed.dropFirst()), depth: 0) }
        if trimmed.first == "&", let macroContext,
            let resolved = ScriptMacros.resolve(String(trimmed.dropFirst()), context: macroContext, resolver: self, isEnglish: isEnglish)
        {
            return resolved
        }
        return line
    }

    public func sectionExists(path: String, section: String) -> Bool {
        winningVariant(path: path, section: section) != nil
    }

    /// Follows `path`'s `baseFile` chain to the first file (possibly `path` itself)
    /// that actually defines `section` at all — needed before `winningVariant` can pick
    /// among that file's own conditioned variants. Real example: `Commune/C7a.txt`
    /// (a Commune sub-variant carrying only its own Mass-proper overrides) has no
    /// `[Ant Vespera]`/`[Hymnus Vespera]` of its own, leaning on its own preamble's
    /// `@Commune/C7` reference for those — confirmed as a real, previously-missing gap
    /// via S. Elisabeth Viduæ's real Vespers (19 November), whose `[Rank]` names
    /// exactly this Commune (`"vide C7a"`).
    ///
    /// **A conditionally-gated preamble inclusion is skipped when its condition holds**
    /// (`BaseFileReference.condition`, evaluated here — the one place this project ever
    /// evaluates a "preamble" condition, since `RawSectionParser` deliberately never
    /// does). Confirmed real for `Tempora/Pasc6-5.txt`/`Pasc6-6.txt` (the Friday/Saturday
    /// within the week after Ascension): their own preamble is `@Tempora/Pasc6-0`
    /// immediately followed by `(sed rubrica 196 aut rubrica cisterciensis omittitur)`
    /// — under 1960 rubrics that condition holds, so the base inclusion is *omitted*,
    /// and resolution should instead fall through to each section's own ordinary
    /// Commune-reference chain (`Pasc6-5`'s own `[Rank]` names `"ex Tempora/Pasc5-4"`,
    /// Ascension's own file). Evaluated by running the two-line preamble snippet
    /// through the exact same `ConditionalLineProcessor` every section body already
    /// uses, rather than re-deriving "what does an omittitur scope phrase mean" as new
    /// logic here — a real fixture confirmed this project's own engine was instead
    /// always following the unconditioned base file, wrongly rendering Sunday-after-
    /// Ascension's own Capitulum/Versum ("1 Petri 4:7-8" / "Dóminus in cælo...") on both
    /// of these dates every year instead of Ascension's own ("Act. 1:1-2" / "Ascéndit
    /// Deus in iubilatióne..." — confirmed against the real fixture for 22 May 2026).
    private func resolvingBaseChain(from path: String, section: String, depth: Int = 0) -> String {
        guard depth < Self.maxInclusionDepth else { return path }
        if !corpus.rawSections(path: path, name: section).isEmpty { return path }
        guard let base = corpus.baseFile(path: path), Self.baseFileApplies(base, context: context) else {
            // `checklatinfile` (`SetupString.pl:824-844`): a Monastic or Dominican file the
            // bundle doesn't have falls back to the Roman one. `Tempora/Pent06-1`'s
            // `@TemporaM/Pent01-3:Responsory2` reads `Tempora/Pent01-3`.
            if depth == 0, let match = path.firstMatch(of: /^(Sancti|Tempora|Commune)(?:M|OP)\//) {
                let roman = String(match.1) + "/" + path[match.range.upperBound...]
                if !corpus.rawSections(path: roman, name: section).isEmpty || corpus.baseFile(path: roman) != nil {
                    return resolvingBaseChain(from: roman, section: section, depth: depth + 1)
                }
            }
            return path
        }
        return resolvingBaseChain(from: base.file, section: section, depth: depth + 1)
    }

    private static func baseFileApplies(_ base: BaseFileReference, context: ConditionalContext) -> Bool {
        guard !base.condition.isEmpty else { return true }
        let resolved = ConditionalLineProcessor.resolve(lines: ["@\(base.file)", base.condition], context: context)
        return resolved.contains { $0.hasPrefix("@") }
    }

    /// The `[Rank]` field with its title auto-filled from `[Officium]`'s resolved text --
    /// mirrors `SetupString.pl`'s own safeguard substitution (`$sections{'Rank'} =~
    /// s/^.*?;;/$sections{'Officium'};;/;`, applied only `if (exists($sections{'Officium'}))`),
    /// documented but not previously wired up in `do-format.md`'s `[Rank]` field section.
    /// Without this, `OfficeRank.title` reads whatever the file's own `[Rank]` line
    /// literally starts with -- empty for nearly every real Tempora/Sancti file, since
    /// DO leaves that leading field blank on disk specifically so this substitution fills
    /// it in at load time. Every title-based rubric check (the RG15 Immaculate Conception
    /// exception, the Feria/Sabbato/Vigilia/octave exclusions in `Concurrence` and
    /// `Commemorations`) depends on callers using this instead of a raw `resolve(path:
    /// section: "Rank")`.
    public func resolveRank(path: String) -> String {
        let rank = resolve(path: path, section: "Rank")
        // The real Perl's own `if (exists($sections{'Officium'}))` reads an
        // already-chain-resolved section hash, so a pure `@`-inclusion redirect file
        // (real example: `Tempora/Quad6-4r.txt`, Holy Thursday's own redirect target,
        // whose entire content is the single line `@Tempora/Quad6-4`) counts as having
        // `[Officium]` there too, inherited from the base file. The literal,
        // non-chain-aware `corpus.rawSections(path:name:)` this used before missed
        // exactly that case, leaving such a file's own `OfficeRank.title` empty even
        // though its `[Rank]` field's numeric/degree parts resolved correctly via the
        // same chain — `sectionExists` is this project's own chain-aware equivalent,
        // already used everywhere else for exactly this kind of check. Confirmed real
        // for 16 April 2025 (Holy Wednesday): an empty-titled commemoration candidate
        // for `Tempora/Quad6-4r` slipped past `Commemorations`' own title-based
        // exclusions (which all match against `.title`), wrongly commemorating Holy
        // Thursday's Institution of the Eucharist at Holy Wednesday's own Vespers.
        guard sectionExists(path: path, section: "Officium"), let separator = rank.range(of: ";;") else { return rank }
        var officium = resolve(path: path, section: "Officium")
        while let last = officium.last, last.isWhitespace { officium.removeLast() }
        return officium + rank[separator.lowerBound...]
    }

    /// Resolves psalm/canticle verse text specifically — reads the winning `[Name]
    /// (condition)` variant's raw body **without** running it through
    /// `ConditionalLineProcessor` first. Confirmed necessary against real data: DO
    /// itself never applies `process_conditional_lines` to psalm/canticle files at all
    /// (`horasscripts.pl:552`: `do_read(checkfile(...))`, a plain raw read that bypasses
    /// `setupstring_parse_file`/`process_conditional_lines` entirely), because verse
    /// text is static and unconditional. Running it through inline-conditional
    /// resolution anyway is actively harmful: a psalm/canticle file's own leading
    /// `"(Title * Source)"` comment line (real example: `Psalm232.txt`'s `"(Canticum B.
    /// Mariæ Virginis * Luc. 1:46-55)"`) gets misparsed by `ConditionalLineProcessor` as
    /// a `(condition)` clause — its garbage "condition" text evaluates false, and the
    /// grammar's default forward scope for an unrecognised clause (`.line`) silently
    /// swallows the very next line, which is the psalm's own first verse. Confirmed
    /// against the real fixture for 16 September 2026: the Magnificat's own `"1:46"`
    /// was missing entirely — a *missing* unit, which no earlier oracle test could have
    /// caught (only a *wrong* one fails the existing `.contains()`-based comparison).
    /// `Psalm.parseVerses`'s own existing "skip a leading `(...)` title line" logic
    /// (checking each line's reference starts with a digit) is already exactly what's
    /// needed once the input is the plain raw body — no further change needed there.
    public func resolvePsalmText(path: String, section: String) -> String {
        guard let winner = winningVariant(path: path, section: section) else {
            return "\(path):\(section) is missing!"
        }
        return resolveInclusionsAndMacros(in: winner.body.joined(separator: "\n"), depth: 0)
    }

    // MARK: - Section resolution

    private func resolveSection(path: String, section: String, depth: Int) -> String {
        guard let winner = winningVariant(path: path, section: section) else {
            return "\(path):\(section) is missing!"    // Mirrors get_loadtime_inclusion's own message.
        }
        let lines = ConditionalLineProcessor.resolve(lines: winner.body, context: context)
        let text = lines.joined(separator: "\n")
        return resolveInclusionsAndMacros(in: text, depth: depth, callerPath: path)
    }

    /// Picks the winning `[Name] (condition)` variant: the *last* one (in file order)
    /// whose condition is empty or holds against `context` — mirroring
    /// `setupstring_parse_file`'s hash-overwrite semantics (`SetupString.pl:340-348`),
    /// where each new true-conditioned header replaces the previous entry for that key.
    /// The winning variant's body, unresolved (`@` references still in place): for a
    /// caller that needs to read a reference itself, as `getrefs` does.
    public func unresolvedBody(path: String, section: String) -> [String]? {
        winningVariant(path: path, section: section)?.body
    }

    private func winningVariant(path: String, section: String) -> RawSection? {
        let resolvedPath = resolvingBaseChain(from: path, section: section)
        var winner: RawSection?
        for candidate in corpus.rawSections(path: resolvedPath, name: section) {
            if candidate.condition.isEmpty || ConditionalEvaluator.evaluate(candidate.condition, context: context) {
                winner = candidate
            }
        }
        return winner
    }

    // MARK: - `@` inclusion and `$` prayer macro resolution

    /// Processes a resolved section's text line by line: a line that is itself a `@`
    /// inclusion directive (already fully qualified by `RawSectionParser`) or a `$Name`
    /// prayer macro gets replaced by its resolved text; everything else passes through.
    /// `SetupString.pl:519-527`, `get_loadtime_inclusion`: in Paschaltide an `@` into
    /// the Commons of Apostles and Martyrs (`C1`-`C3`) reads their Paschal form
    /// (`C3` -> `C3p`, `C3a` -> `C3ap`), except from inside those Commons and for a hymn,
    /// collect, lesson or versicle. 9 June 2038: Ss. Primus and Felician's `[Ant 2]`,
    /// `@Commune/C3`, is "Fíliæ Ierúsalem…" at Lauds.
    private func paschalInclusionPath(_ path: String, section: String, callerPath: String?) -> String {
        guard context.tempore.range(of: "Pasch|Ascensionis|Pentecostes", options: .regularExpression) != nil,
            let callerPath, callerPath.range(of: "C[123]", options: .regularExpression) == nil,
            section.range(of: "Hymnus|Oratio|Lectio|Secreta|Postcommunio|Versum", options: [.regularExpression, .caseInsensitive]) == nil,
            let match = path.firstMatch(of: /(C[123][abcd]*)$/)
        else { return path }
        let paschal = path.replacingCharacters(in: match.range, with: match.1 + "p")
        return sectionExists(path: paschal, section: section) ? paschal : path
    }

    private func resolveInclusionsAndMacros(in text: String, depth: Int, callerPath: String? = nil) -> String {
        guard depth < Self.maxInclusionDepth else {
            return "Cannot resolve too deeply nested references"
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var resolvedLines: [String] = []
        resolvedLines.reserveCapacity(lines.count)

        for line in lines {
            if line.first == "@", let inclusion = parseInclusion(line) {
                // As for `$` lines below: the header may carry the I spelling.
                var section = inclusion.section
                let path = paschalInclusionPath(inclusion.path, section: section, callerPath: callerPath)
                if !sectionExists(path: path, section: section) {
                    let iSpelling = section.replacingOccurrences(of: "j", with: "i").replacingOccurrences(of: "J", with: "I")
                    if sectionExists(path: path, section: iSpelling) { section = iSpelling }
                }
                // DO applies an inclusion's substitutions to the section's own text, its
                // `@` lines still unresolved (`get_loadtime_inclusion` reads the cached,
                // unresolved file), and resolves them afterwards. The Rosary's Matins
                // hymn, `@Sancti/10-07:Hymnus Vespera:s/\@Psalterium.*//s`, drops the
                // doxology that way.
                if let subs = inclusion.substitutions, let winner = winningVariant(path: path, section: section) {
                    let raw = ConditionalLineProcessor.resolve(lines: winner.body, context: context).joined(separator: "\n")
                    let substituted = applySubstitutions(subs, to: raw)
                    resolvedLines.append(resolveInclusionsAndMacros(in: substituted, depth: depth + 1, callerPath: path))
                } else {
                    resolvedLines.append(resolveSection(path: path, section: section, depth: depth + 1))
                }
            } else if line.first == "$" {
                // DO's `expand` trims the line first (`webdia.pl`, `s/\s+$//`): the English
                // `Sancti/02-24` ends its collect with `$Per Dominum ` (trailing space),
                // which must still expand.
                resolvedLines.append(resolvePrayerMacroLine(String(line.dropFirst()).trimmingCharacters(in: .whitespaces), depth: depth))
            } else if line.first == "&", let macroContext,
                let resolved = ScriptMacros.resolve(
                    String(line.dropFirst()).trimmingCharacters(in: .whitespaces), context: macroContext, resolver: self, isEnglish: isEnglish
                )
            {
                resolvedLines.append(resolved)
            } else {
                resolvedLines.append(String(line))
            }
        }

        return resolvedLines.joined(separator: "\n")
    }

    /// A `$Name` line's captured name can carry a trailing sentence-final period as
    /// literal text in the source (e.g. `Commune/C3.txt`'s Oratio ends with the line
    /// `$Per Dominum.`, but `Prayers.txt`'s own header is `[Per Dominum]`, no period,
    /// and its own resolved text already ends "...R. Amen." with its own period) --
    /// confirmed by running a real Vespers assembly end to end, not documented in
    /// do-format.md previously. Falls back to stripping one trailing `.` (without
    /// re-adding it -- the resolved prayer text already supplies its own closing
    /// punctuation) only when the full name doesn't resolve, so a real macro name that
    /// happens to end in `.` is never second-guessed.
    ///
    /// Checks the `rubrica `/`Preces ` sigil prefixes first (`sigilPaths`) — `$rubrica
    /// X` looks up the bare name `X` in `Rubricae.txt` (`rubric($name)`'s own lookup
    /// has no prefix), while `$Preces X` looks up `"Preces X"`, prefix retained, in
    /// `Preces.txt` (`prex("Preces $line", ...)`'s own reconstruction) — confirmed
    /// against each file's real header naming (`Rubricae.txt`: `[Pater secreto]`, bare;
    /// `Preces.txt`: `[Preces feriales Vespera]`, prefixed).
    private func resolvePrayerMacroLine(_ line: String, depth: Int) -> String {
        // The data build normalises J to I in section headers (Latin prose) but not in
        // `$` reference lines, so a Latin `$Deus in adjutorium` must also try
        // `[Deus in adiutorium]` (Beta 2: Compline's skeleton names prayers directly).
        func candidates(_ name: String) -> [String] {
            let iSpelling = name.replacingOccurrences(of: "j", with: "i").replacingOccurrences(of: "J", with: "I")
            return iSpelling == name ? [name] : [name, iSpelling]
        }
        for (prefix, path) in Self.sigilPaths where line.hasPrefix(prefix) {
            let rest = String(line.dropFirst(prefix.count))
            let section = prefix == "Preces " ? "Preces \(rest)" : rest
            let found = candidates(section).first { sectionExists(path: path, section: $0) } ?? section
            return resolveSection(path: path, section: found, depth: depth + 1)
        }

        let name = line
        for candidate in candidates(name) where sectionExists(path: Self.prayersPath, section: candidate) {
            return resolveSection(path: Self.prayersPath, section: candidate, depth: depth + 1)
        }
        if name.hasSuffix(".") {
            for candidate in candidates(String(name.dropLast())) where sectionExists(path: Self.prayersPath, section: candidate) {
                return resolveSection(path: Self.prayersPath, section: candidate, depth: depth + 1)
            }
        }
        return resolveSection(path: Self.prayersPath, section: name, depth: depth + 1)
    }

    private struct Inclusion {
        var path: String
        var section: String
        var substitutions: String?
    }

    /// Parses an already-qualified `@File:Section[:Substitutions]` line (see
    /// `RawSectionParser.qualifySelfReferences`, which guarantees file and section are
    /// always present by the time a line reaches here).
    private func parseInclusion(_ line: Substring) -> Inclusion? {
        guard let match = try? Self.qualifiedInclusionRegex.firstMatch(in: line),
            let path = match.output[1].substring, let section = match.output[2].substring
        else { return nil }
        let subs = match.output[3].substring.map(String.init)
        return Inclusion(path: String(path), section: String(section), substitutions: subs)
    }

    private nonisolated(unsafe) static let qualifiedInclusionRegex: Regex<AnyRegexOutput> =
        // swiftlint:disable:next force_try
        try! Regex(#"^@([^\n:]+):([^\n:]+)(?::(.*))?$"#)

    // MARK: - Substitutions (`do_inclusion_substitutions`, `SetupString.pl:491-505`)

    /// Applies a chain of `@`-inclusion substitution directives to `text`: either a
    /// 1-indexed line selector (`3`, `3-5`, or negated `!3-5` to keep everything
    /// *except* that range) or a `s/pattern/replacement/flags` regex substitution.
    private func applySubstitutions(_ subs: String, to text: String) -> String {
        var result = text
        var cursor = subs.startIndex

        while cursor < subs.endIndex,
            let match = try? Self.substitutionDirectiveRegex.firstMatch(in: subs[cursor...])
        {
            if let regexReplace = match.output[1].substring {
                result = applyRegexSubstitution(String(regexReplace), replacement: match.output[2].substring.map(String.init) ?? "",
                    flags: match.output[3].substring.map(String.init) ?? "", to: result)
            } else if let startText = match.output[5].substring, let start = Int(startText) {
                let negated = match.output[4].substring == "!"
                let end = match.output[7].substring.flatMap { Int($0) } ?? start
                result = applyLineSelection(start: start, end: end, negated: negated, to: result)
            }
            cursor = match.range.upperBound
        }
        return result
    }

    private func applyLineSelection(start: Int, end: Int, negated: Bool, to text: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let startIndex = max(0, start - 1)
        guard startIndex < lines.count else { return text }
        let length = max(1, end - start + 1)
        let range = startIndex..<min(lines.count, startIndex + length)

        if negated {
            lines.removeSubrange(range)
        } else {
            lines = Array(lines[range])
        }
        return lines.joined(separator: "\n")
    }

    private func applyRegexSubstitution(_ pattern: String, replacement: String, flags: String, to text: String) -> String {
        var options: [String] = []
        if flags.contains("i") { options.append("i") }
        if flags.contains("s") { options.append("s") }
        if flags.contains("m") { options.append("m") }
        let prefix = options.isEmpty ? "" : "(?\(options.joined())"
        let fullPattern = prefix.isEmpty ? pattern : "\(prefix))\(pattern)"

        guard let regex = try? Regex(fullPattern) else { return text }
        let maxReplacements = flags.contains("g") ? Int.max : 1

        // Perl's replacement string supports $1-style backreferences; expand them
        // ourselves via the match-based closure overload, since Swift's plain-string
        // replacement overload treats the replacement as a literal.
        return text.replacing(regex, maxReplacements: maxReplacements) { match in
            expandBackreferences(replacement, match: match)
        }
    }

    private func expandBackreferences(_ replacement: String, match: Regex<AnyRegexOutput>.Match) -> String {
        var result = ""
        let chars = Array(replacement)
        var i = 0
        // Perl's `\u`/`\l` change the case of the next character produced, literal or
        // captured (the English Little Office's `R. \u$2`, `Commune/C12`'s Responsory7).
        var caseNext: Character?
        func append(_ text: some StringProtocol) {
            guard let mode = caseNext, let first = text.first else { result += text; return }
            result += mode == "u" ? first.uppercased() : first.lowercased()
            result += text.dropFirst()
            caseNext = nil
        }
        while i < chars.count {
            if chars[i] == "$", i + 1 < chars.count, chars[i + 1].isNumber {
                var j = i + 1
                var numberText = ""
                while j < chars.count, chars[j].isNumber {
                    numberText.append(chars[j])
                    j += 1
                }
                if let groupIndex = Int(numberText), groupIndex < match.output.count,
                    let captured = match.output[groupIndex].substring
                {
                    append(captured)
                }
                i = j
            } else if chars[i] == "\\", i + 1 < chars.count {
                // Perl's escapes in a replacement: `\n` is a newline (Pentecost Tuesday's
                // `s/V\. .*/V. Spíritus Paráclitus, allelúja.\nR. …/s`), `\t` a tab, and any
                // other escaped character itself.
                switch chars[i + 1] {
                case "n": append("\n")
                case "t": append("\t")
                case "u", "l": caseNext = chars[i + 1]
                default: append(String(chars[i + 1]))
                }
                i += 2
            } else {
                append(String(chars[i]))
                i += 1
            }
        }
        return result
    }

    /// Ports the alternation in `do_inclusion_substitutions`'s matching regex
    /// (`SetupString.pl:494`): either `s/pattern/replacement/flags` (groups 1-3) or a
    /// line selector `!?N(-M)?` (groups 4-7).
    private nonisolated(unsafe) static let substitutionDirectiveRegex: Regex<AnyRegexOutput> =
        // swiftlint:disable:next force_try
        try! Regex(#"(?:s/([^/]*)/([^/]*)/([gism]*))|(?:(!?)(\d+)(-(\d+))?)"#)
}
