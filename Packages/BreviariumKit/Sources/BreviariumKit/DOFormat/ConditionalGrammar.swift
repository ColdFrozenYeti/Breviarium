/// Shared grammar for DO's `(stopwords condition scope)` conditional syntax, used by
/// both section-header condition extraction (`RawSectionParser`) and inline `(sed ...)`
/// directive processing (`ConditionalLineProcessor`). Ports the regex/strength/scope
/// machinery in `SetupString.pl:69-162`, kept separate from `ConditionalEvaluator`
/// (which only handles the boolean evaluation of the extracted condition text).
enum ConditionalGrammar {

    /// The four scope reaches a conditional can have, in each direction
    /// (`SetupString.pl:113-116`).
    enum Scope: Equatable {
        case null   // No text affected.
        case line   // A single line.
        case chunk  // Until the next blank line.
        case nest   // Until a (weakly) stronger conditional.
    }

    /// Stopword -> strength (`SetupString.pl:78-85`). Higher strength lets a later
    /// conditional override/close out earlier, weaker ones.
    static let stopwordWeights: [String: Int] = [
        "sed": 1, "vero": 1, "atque": 2, "attamen": 3, "si": 0, "deinde": 1,
    ]

    /// Stopwords with *implicit* backward scope even without an explicit scope phrase
    /// (`SetupString.pl:81`: a copy of the main stopword set at the point `si`/`deinde`
    /// hadn't been added yet).
    static let backscopedStopwords: Set<String> = ["sed", "vero", "atque", "attamen"]

    /// A conditional clause: `(` optional-stopwords condition optional-scope-phrase `)`.
    struct Clause {
        var stopwords: String
        var condition: String
        var scopePhrase: String
    }

    /// Matches one `(...)` conditional at the start of `text` (after leading whitespace)
    /// and returns the parsed clause plus the text remaining after the closing paren.
    /// Mirrors `$conditional_regex` (`SetupString.pl:109`).
    static func matchLeadingClause(in text: Substring) -> (clause: Clause, rest: Substring)? {
        guard let match = try? clauseRegex.firstMatch(in: text), match.range.lowerBound == text.startIndex
        else { return nil }

        let stopwords = match.output[1].substring.map(String.init) ?? ""
        let condition = match.output[2].substring.map(String.init) ?? ""
        let scopePhrase = match.output[3].substring.map(String.init) ?? ""
        return (Clause(stopwords: stopwords, condition: condition, scopePhrase: scopePhrase), text[match.range.upperBound...])
    }

    /// Given a clause's stopwords and scope phrase, computes its strength and its
    /// backward/forward scope. Ports `parse_conditional` (`SetupString.pl:134-162`),
    /// minus the `vero()` call, which callers do separately via `ConditionalEvaluator`.
    static func parseScopeAndStrength(stopwords: String, scopePhrase: String) -> (strength: Int, backscope: Scope, forwardscope: Scope) {
        let words = stopwords.split(separator: " ").map { $0.lowercased() }
        let strength = words.reduce(0) { $0 + (stopwordWeights[$1] ?? 0) }
        let implicitBackscope = words.contains { backscopedStopwords.contains($0) }

        let scopeLower = scopePhrase.lowercased()
        let backscope: Scope
        if scopeLower.contains("versuum") || scopeLower.contains("omittuntur") {
            backscope = .nest
        } else if scopeLower.contains("versus") || scopeLower.contains("omittitur") {
            backscope = .chunk
        } else if !scopeLower.contains("semper") && implicitBackscope {
            backscope = .line
        } else {
            backscope = .null
        }

        let forwardscope: Scope
        if scopeLower.contains("omittitur") || scopeLower.contains("omittuntur") {
            forwardscope = .null
        } else if scopeLower.contains("dicuntur") {
            forwardscope = (backscope == .chunk) ? .chunk : .nest
        } else {
            forwardscope = (backscope == .chunk || backscope == .nest) ? .chunk : .line
        }

        return (strength, backscope, forwardscope)
    }

    // MARK: - Regex

    /// Ports `$scope_regex` (`SetupString.pl:88-108`). Written as one line rather than
    /// Perl's free-spacing `/x` layout, since that relies on incidental whitespace
    /// between tokens being ignored — easier to just not have any than to depend on
    /// matching `/x` semantics exactly in Swift's regex engine. Every `\s` below is
    /// meaningful (present in the original); nothing here is decorative.
    private static let scopePhrasePattern =
        #"(?:\bloco\s+(?:hu[ij]us\s+versus|horum\s+versuum)\b)?\s*(?:\b(?:(?:dicitur|dicuntur)(?:\s+semper)?|(?:hic\s+versus\s+)?omittitur|(?:hoc\s+versus\s+)?omittitur|(?:hæc\s+versus\s+)?omittuntur|(?:hi\s+versus\s+)?omittuntur|(?:haec\s+versus\s+)?omittuntur)\b)?"#

    /// Ports `$conditional_regex` (`SetupString.pl:109`): `\(\s*(stopwords)*(.*?)(scope)?\s*\)`.
    ///
    /// Note: the original Perl pattern `($stopwords_regex\b)*` has no whitespace between
    /// repetitions, so back-to-back real Latin stopwords never actually occur — in
    /// practice it matches zero or one stopword, never more. Ported here as `(word)?`
    /// rather than a literal `*` repetition, which is behaviourally identical for any
    /// real input and avoids inventing whitespace-separated multi-stopword handling DO's
    /// own grammar doesn't actually support.
    private static let clauseRegex: Regex<AnyRegexOutput> = {
        let stopwordsAlt = stopwordWeights.keys.joined(separator: "|")
        // Leading "(?i)": SetupString.pl's $conditional_regex itself isn't flagged /i
        // (its /o just means "compile once"), but every real example is lowercase and
        // the subject/predicate matching vero() does downstream is explicitly
        // case-insensitive throughout — matching case-insensitively here too is a safe
        // superset, not a behaviour change, and guards against stray capitalisation at
        // a sentence start somewhere in the corpus.
        let pattern = #"(?i)\(\s*(?:(\#(stopwordsAlt))\b)?(.*?)(\#(scopePhrasePattern))?\s*\)"#
        // swiftlint:disable:next force_try
        return try! Regex(pattern)
    }()
}
