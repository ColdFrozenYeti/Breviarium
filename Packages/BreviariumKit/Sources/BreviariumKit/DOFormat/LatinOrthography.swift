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
        return result.replacingOccurrences(of: "er eúmdem", with: "er eúndem")
    }
}
