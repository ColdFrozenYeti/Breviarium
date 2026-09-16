import Foundation

/// Ports Divinum Officium's `vero()` (`SetupString.pl:255-303`) — the boolean evaluator
/// for a single conditional clause, e.g. `rubrica 196`, `tempore paschali`,
/// `dominica et feria 1`. Used both for `[Section] (condition)` header selection (called
/// directly, matching `setupstring_parse_file`) and, via `ConditionalLineProcessor`, for
/// inline `(sed ...)` directives within a section's body.
public enum ConditionalEvaluator {

    /// Known non-GABC predicate names and the test they perform against a subject's
    /// string value. Mirrors `%predicates` in `SetupString.pl:39-60`; GABC-only
    /// predicates (`tonus`/`toni`-related: "in solemnitatibus", "in hieme", "in æstate")
    /// are omitted since this project has no chant support and `ConditionalContext` has
    /// no `tonus`/`toni` subject for them to test against.
    static let predicates: [String: (String) -> Bool] = [
        "tridentina": { $0.range(of: "Trident", options: .caseInsensitive) != nil },
        "monastica": { $0.range(of: "Monastic", options: .caseInsensitive) != nil },
        "innovata": { matches($0, "2020 USA|NewCal") },
        "innovatis": { matches($0, "2020 USA|NewCal") },
        "paschali": { matches($0, "Paschæ|Ascensionis|Octava Pentecostes") },
        "post septuagesimam": { matches($0, "Septua|Quadra|Passio") },
        "prima": { $0 == "1" },
        "secunda": { $0 == "2" },
        "tertia": { $0 == "3" },
        "longior": { $0 == "1" },
        "brevior": { $0 == "2" },
        // SetupString.pl:53 has a stray "]" in this regex (`194[2-9]]`), which as written
        // can never match a real version string. Ported faithfully rather than "fixed" —
        // this project only ever renders "Rubrics 1960 - 1960", which the third
        // alternative (`196`) already matches, so the bug is inert for us either way.
        "summorum pontificum": { matches($0, "194[2-9]]|195[45]|196") },
        "feriali": { matches($0, "feria|vigilia") },
    ]

    /// Subject names `ConditionalContext` recognises (`SetupString.pl:18-34`'s
    /// `%subjects`, minus the GABC-only `tonus`/`toni`).
    static let knownSubjects: Set<String> = [
        "rubricis", "rubrica", "tempore", "missa", "communi",
        "die", "feria", "commune", "votiva", "officio", "ad", "mense", "dioecesis",
    ]

    /// Evaluates a conditional clause against a context. The empty condition is always
    /// true (`SetupString.pl:262`: "safer, since previously conditions weren't used").
    public static func evaluate(_ condition: String, context: ConditionalContext) -> Bool {
        let trimmed = condition.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }

        // "aut" (or) is the loosest-binding separator — split first (SetupString.pl:264-301).
        autemLoop: for autBranch in split(trimmed, onWord: "aut") {
            var negation = false

            // "et" (and) / "nisi" (and-not) chain within one "aut" branch. Perl's split
            // with a capturing separator keeps the separator words as list elements too,
            // and `$negation` is only reset at the top of the "aut" loop — so once
            // "nisi" appears, every later clause in this branch (even after a further
            // "et") stays negated. Ported as-is: this is what DO's own grammar does,
            // however sharp-edged, not a bug we get to silently fix.
            for token in splitKeepingSeparators(autBranch, separators: ["et", "nisi"]) {
                if token.isSeparator {
                    if token.text.lowercased() == "nisi" { negation = true }
                    continue
                }

                let clause = token.text.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                guard !clause.isEmpty else { continue }

                let words = clause.split(separator: " ", maxSplits: 1).map(String.init)
                var subject = words.count > 1 ? words[0] : ""
                var predicateText = words.count > 1 ? words[1] : (words.first ?? "")

                if !subject.isEmpty && !knownSubjects.contains(subject.lowercased()) {
                    // Multi-word predicate with an implicit subject (SetupString.pl:282-285).
                    predicateText = "\(subject) \(predicateText)"
                    subject = ""
                }
                if subject.isEmpty { subject = "tempore" }

                guard let subjectValue = context.value(forSubject: subject) else {
                    continue autemLoop    // Unrecognised subject: this "aut" branch fails.
                }

                let predicateResult: Bool
                if let known = predicates[predicateText.lowercased()] {
                    predicateResult = known(subjectValue)
                } else {
                    predicateResult = matches(subjectValue, predicateText)
                }

                if predicateResult == negation {
                    continue autemLoop    // This clause failed: try the next "aut" branch.
                }
            }

            return true    // Every clause in this "aut" branch held.
        }

        return false    // No "aut" branch held.
    }

    // MARK: - Tokenising helpers

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        (try? Regex("(?i)\(pattern)")).flatMap { try? $0.firstMatch(in: value) != nil } ?? false
    }

    /// Splits on a whole-word separator (`\bword\b`), discarding the separator itself —
    /// used for "aut", which Perl's `split /\baut\b/` also discards (no capturing group).
    private static func split(_ text: String, onWord word: String) -> [String] {
        guard let regex = try? Regex("(?i)\\b\(word)\\b") else { return [text] }
        return text.split(separator: regex).map(String.init)
    }

    private struct Token {
        var text: String
        var isSeparator: Bool
    }

    /// Splits on "et"/"nisi" as whole words, keeping the separators as their own tokens
    /// — mirroring Perl's `split /\b(et|nisi)\b/`, whose capturing group keeps matched
    /// separators in the result list.
    private static func splitKeepingSeparators(_ text: String, separators: [String]) -> [Token] {
        let pattern = "(?i)\\b(\(separators.joined(separator: "|")))\\b"
        guard let regex = try? Regex(pattern) else {
            return [Token(text: text, isSeparator: false)]
        }

        var tokens: [Token] = []
        var cursor = text.startIndex
        for match in text.matches(of: regex) {
            if match.range.lowerBound > cursor {
                tokens.append(Token(text: String(text[cursor..<match.range.lowerBound]), isSeparator: false))
            }
            tokens.append(Token(text: String(text[match.range]), isSeparator: true))
            cursor = match.range.upperBound
        }
        if cursor < text.endIndex {
            tokens.append(Token(text: String(text[cursor...]), isSeparator: false))
        }
        return tokens
    }
}
