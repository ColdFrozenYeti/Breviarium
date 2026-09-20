/// Normalises Latin text to the classical I-only orthography `CLAUDE.md` requires
/// (`Iesum`, `eius`, `iudicáre`, `Ierúsalem` — never `Jesum`/`ejus`/`judicáre`/`Jerúsalem`).
///
/// Divinum Officium's own source texts mix J and I spellings inconsistently (they come
/// from different historical printings), so this always normalises J/j -> I/i in Latin
/// text rather than trying to detect which spelling a given file already uses.
///
/// Also ports the one further literal substitution DO's own `spell_var()`
/// (`horascommon.pl:2184-2200`) applies for 1960-family rubrics alongside its `tr/Jj/
/// Ii/`: `s/er eúmdem/er eúndem/g`, a spelling revision from the same rubric reform
/// ("Cum Nostra Hac Aetate") that motivated `HourAssembler`'s own revised
/// Confessor-hymn texts (`checkmtv`, see its doc comment there). Found
/// via a full 2025-2040 content audit: `Prayers.txt`'s own `[Per eumdem]` collect-ending
/// macro body has the traditional "eúmdem" spelling, but DO's real rendering always
/// shows "eúndem" instead — confirmed against the real fixture for 4 January 2025.
/// `spell_var`'s other substitution, `s/H-Iesu/H-Jesu/` (undoing the blanket J->I inside
/// a hymn-tune identifier like `{:H-IesuRedemptorOmnium:}`), is deliberately not
/// ported: this project's own `hymnStanzas` strips that whole `{:...:}` prefix before
/// display, so the identifier's own spelling is never shown to begin with.
///
/// Also strips the mid-verse `†` "flexa" mark some Bea-psalter verses carry directly in
/// their own source text — ports `horasscripts.pl`'s own `s/†\s*//g if $noflexa;`, the
/// unconditional half of the same "Breviarium Romanum style" rule (`Discussion #4504`)
/// that governs the `‡` dagger this project's engine already handles separately and
/// contextually (`HourAssembler`'s own psalm-antiphon dagger rule) — `†`, unlike `‡`,
/// is *always* deleted outright, no context needed. Confirmed real for 4 January 2025:
/// `Psalm110.txt`'s own "110:9 Redemptiónem misit pópulo suo, † státuit..." renders in
/// the real fixture as "...pópulo suo, státuit..." with no `†` anywhere.
///
/// A handful of verses (real example: `Psalm144.txt`'s own "144:19 Voluntátem
/// timéntium se fáciet, ‡ et clamórem eórum áudiet, * et salvábit eos.") also carry a
/// *raw* `‡` directly in their own source text — the other half of the same
/// `Discussion #4504` rule, `s/‡\s+(.*?)\*\s*/* $1/g if $noflexa;`: the dagger *moves*
/// to become the verse's own `*` half-split point, consuming whatever ordinary `*` came
/// later in the same verse. This is the source-text case, distinct from `HourAssembler`'s
/// own *inserted* `‡` (added at render time when an antiphon quotes a whole verse) —
/// by the time that logic runs, any raw `‡` from the source has already been resolved
/// away here, so the two never interact in `BreviariumData`'s own build-time pass.
/// Confirmed real for 18 January 2026: the real fixture reads "144:19 Voluntátem
/// timéntium se fáciet, * et clamórem eórum áudiet, et salvábit eos." — the `*` has
/// moved to where the `‡` was, and the verse's own later `*` is gone.
///
/// **Scoped to a `‡` immediately preceded by `,`/`;`/`:`**, not every `‡` — this
/// same function is *also* reused by `OracleTests` to normalise a real DO fixture
/// (already-rendered output, per `data/SOURCE.md`'s own note) before comparing it
/// against this project's engine, and a *real* fixture can legitimately contain a `‡`
/// from `HourAssembler`'s own insertion (the antiphon-quotes-a-whole-verse case) —
/// unlike a raw source `‡`, that one is never preceded by punctuation, only by a bare
/// verse number (`"132:2 ‡ Sicut…"`). Applying the unscoped substitution there
/// corrupted that separate, correct case — found the same day, comparing a real
/// fixture against this project's own rendering after this fix first shipped too
/// broadly.
public enum LatinOrthography {

    /// Applies J -> I normalisation to a single line of Latin prose.
    ///
    /// Lines that are pure DO reference/macro directives (`@file:section`, `$Name`,
    /// `&Name`) are left untouched, since those are structural identifiers — not
    /// prose — and some of them (e.g. `&Deus_in_adjutorium`) contain a literal `j`
    /// that must survive unchanged to keep matching the identifier BreviariumKit's
    /// resolution engine looks up.
    public static func normalizeLine(_ line: String) -> String {
        if isReferenceDirectiveLine(line) {
            return line
        }
        return normalizeProse(line)
    }

    /// Applies J -> I normalisation to a multi-line block of Latin text, line by line,
    /// preserving reference/macro directive lines untouched (see `normalizeLine`).
    public static func normalize(_ text: String) -> String {
        // CRLF-checked-out files (Windows) would otherwise collapse into a single
        // "line": Swift's Character (grapheme cluster) view treats "\r\n" as one
        // Character, so `split(separator: "\n")` never finds a boundary inside it —
        // this only ever surfaces locally on Windows, never on Linux CI.
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { normalizeLine(String($0)) }
            .joined(separator: "\n")
    }

    /// True if this line, trimmed, is entirely a `@`/`$`/`&` reference directive with
    /// no other prose sharing the line — the case that must not be touched.
    static func isReferenceDirectiveLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return false }
        return first == "@" || first == "$" || first == "&"
    }

    private static func normalizeProse(_ text: String) -> String {
        var result = String()
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "j": result.append("i")
            case "J": result.append("I")
            default: result.append(character)
            }
        }
        result = result.replacingOccurrences(of: "er eúmdem", with: "er eúndem")
        result = result.replacingOccurrences(of: #"†\s*"#, with: "", options: .regularExpression)
        return result.replacingOccurrences(of: #"(?<=[,;:])\s+‡\s+(.*?)\*\s*"#, with: " * $1", options: .regularExpression)
    }
}
