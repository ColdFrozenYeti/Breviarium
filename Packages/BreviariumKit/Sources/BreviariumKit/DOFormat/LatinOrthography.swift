/// Normalises Latin text to the classical I-only orthography `CLAUDE.md` requires
/// (`Iesum`, `eius`, `iudicáre`, `Ierúsalem` — never `Jesum`/`ejus`/`judicáre`/`Jerúsalem`).
///
/// Divinum Officium's own source texts mix J and I spellings inconsistently (they come
/// from different historical printings), so this always normalises J/j -> I/i in Latin
/// text rather than trying to detect which spelling a given file already uses.
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
        text
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
        return result
    }
}
