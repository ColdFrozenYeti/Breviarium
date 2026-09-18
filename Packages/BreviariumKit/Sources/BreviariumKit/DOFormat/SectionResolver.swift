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
        resolveSection(path: path, section: section, depth: 0)
    }

    /// Whether `path` defines `section` itself, following its `baseFile` chain
    /// (`do-format.md`'s whole-file inclusion) if it doesn't directly — for callers
    /// (`HourAssembler`) that need to fall back to a different file (the Commune) when
    /// an office doesn't define a section at all, distinct from the section existing
    /// but resolving empty.
    public func sectionExists(path: String, section: String) -> Bool {
        !corpus.rawSections(path: resolvingBaseChain(from: path, section: section), name: section).isEmpty
    }

    /// Follows `path`'s `baseFile` chain to the first file (possibly `path` itself)
    /// that actually defines `section` at all — needed before `winningVariant` can pick
    /// among that file's own conditioned variants. Real example: `Commune/C7a.txt`
    /// (a Commune sub-variant carrying only its own Mass-proper overrides) has no
    /// `[Ant Vespera]`/`[Hymnus Vespera]` of its own, leaning on its own preamble's
    /// `@Commune/C7` reference for those — confirmed as a real, previously-missing gap
    /// via S. Elisabeth Viduæ's real Vespers (19 November), whose `[Rank]` names
    /// exactly this Commune (`"vide C7a"`).
    private func resolvingBaseChain(from path: String, section: String, depth: Int = 0) -> String {
        guard depth < Self.maxInclusionDepth else { return path }
        if !corpus.rawSections(path: path, name: section).isEmpty { return path }
        guard let base = corpus.baseFile(path: path) else { return path }
        return resolvingBaseChain(from: base, section: section, depth: depth + 1)
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
        guard !corpus.rawSections(path: path, name: "Officium").isEmpty,
            let separator = rank.range(of: ";;")
        else { return rank }
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
        return resolveInclusionsAndMacros(in: text, depth: depth)
    }

    /// Picks the winning `[Name] (condition)` variant: the *last* one (in file order)
    /// whose condition is empty or holds against `context` — mirroring
    /// `setupstring_parse_file`'s hash-overwrite semantics (`SetupString.pl:340-348`),
    /// where each new true-conditioned header replaces the previous entry for that key.
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
    private func resolveInclusionsAndMacros(in text: String, depth: Int) -> String {
        guard depth < Self.maxInclusionDepth else {
            return "Cannot resolve too deeply nested references"
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var resolvedLines: [String] = []
        resolvedLines.reserveCapacity(lines.count)

        for line in lines {
            if line.first == "@", let inclusion = parseInclusion(line) {
                var included = resolveSection(path: inclusion.path, section: inclusion.section, depth: depth + 1)
                if let subs = inclusion.substitutions {
                    included = applySubstitutions(subs, to: included)
                }
                resolvedLines.append(included)
            } else if line.first == "$" {
                resolvedLines.append(resolvePrayerMacroLine(String(line.dropFirst()), depth: depth))
            } else if line.first == "&", let macroContext,
                let resolved = ScriptMacros.resolve(String(line.dropFirst()), context: macroContext, resolver: self, isEnglish: isEnglish)
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
        for (prefix, path) in Self.sigilPaths where line.hasPrefix(prefix) {
            let rest = String(line.dropFirst(prefix.count))
            let section = prefix == "Preces " ? "Preces \(rest)" : rest
            return resolveSection(path: path, section: section, depth: depth + 1)
        }

        let name = line
        if sectionExists(path: Self.prayersPath, section: name) {
            return resolveSection(path: Self.prayersPath, section: name, depth: depth + 1)
        }
        if name.hasSuffix("."), sectionExists(path: Self.prayersPath, section: String(name.dropLast())) {
            return resolveSection(path: Self.prayersPath, section: String(name.dropLast()), depth: depth + 1)
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
                    result += captured
                }
                i = j
            } else {
                result.append(chars[i])
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
