import Foundation

/// The traditional Roman rite's liturgical colours.
///
/// `blue` isn't one of the classical five (Marian feasts are truly *white*) — it's a
/// deliberate, long-established convention (also used by Divinum Officium itself, and
/// common in printed ordos) to visually distinguish Marian feasts from other white days
/// at a glance. Kept here for the same reason DO keeps it, not as a claim about Mass
/// vestment colour.
public enum LiturgicalColor: String, Codable, Sendable, Equatable {
    case white, red, green, violet, black, blue
}

/// Classifies a day's liturgical colour from its `[Officium]` title text. Ports
/// `liturgical_color()` (`DivinumOfficium/Main.pm`) — a sequence of regex checks against
/// the Latin title, returning on the first match — with its internal token names
/// remapped to real colour names (`Main.pm`'s own token → what it actually means):
///
/// - `'black'` → `.white` (DO's own comment: the app renders white-vestment days as
///   black *text* since it's shown against a white background there; the token always
///   meant liturgical white, never literal black)
/// - `'grey'` → `.black` (DO's stand-in for genuine black vestment days — Good Friday,
///   All Souls)
/// - `'blue'`, `'red'`, `'green'`, `'purple'` → `.blue`, `.red`, `.green`, `.violet`
///
/// **Branch order matters**: this is a plain first-match-wins sequence, and several
/// title patterns deliberately match more than one branch (see the ported test suite,
/// `LiturgicalColorTests.swift`, carried over case-for-case from DO's own
/// `t/DivinumOfficium/{LiturgicalColor,Main}.t`). Two branches are case-*sensitive* in
/// the original (no `/i` flag) — the Marian pattern and the anchored `^In Vigilia
/// Ascensionis`/`^In Vigilia Epiphaniæ` check — every other branch is case-insensitive;
/// this distinction is preserved exactly.
public enum LiturgicalColorClassifier {

    public static func classify(title: String) -> LiturgicalColor {
        // Blue: Marian feasts, except a Marian Vigil (which falls through to purple).
        // Case-sensitive in the original, both the match and the exclusion.
        if matches(title, #"(?:Beat|Sanct)(?:ae|æ) Mari"#, caseSensitive: true)
            && !matches(title, "Vigil", caseSensitive: true)
        {
            return .blue
        }

        // Red (first pass): Pentecost's vigil/Ember days, beheadings, martyrs, relics.
        if matches(title, #"(?:Vigilia Pentecostes|Quattuor Temporum Pentecostes|Decollatione|Martyr|Reliquia)"#) {
            return .red
        }

        // Black (real black vestments): the dead, Good Friday (either historical title).
        if matches(title, #"(?:Defunctorum|Parasceve|Morte)"#) {
            return .black
        }

        // White, anchored and case-sensitive: the 1960-rubrics-specific short titles for
        // the eve of the Ascension and the eve of the Epiphany.
        if matches(title, #"^In Vigilia Ascensionis|^In Vigilia Epiphaniæ"#, caseSensitive: true) {
            return .white
        }

        // Violet: Advent, Septuagesima through Holy Saturday, Vigils, Ember days,
        // Rogation days — except when "commemoratione" or "votivum" guards it off.
        if matches(
            title,
            #"(?:Vigilia|Quattuor|Rogatio|Passion|Palmis|gesim|(?:Majoris )?Hebdomadæ(?: Sanctæ)?|Sabbato Sancto|Dolorum|Ciner|Adventus)"#
        )
            && !matches(title, "commemoratione|votivum") {
            return .violet
        }

        // White (second pass): everything else conventionally white -- feasts of the
        // Lord not already covered, Confessors, the Baptist's Nativity, dedications,
        // the Chair/Conversion of an Apostle (checked before red's "Apostol" below).
        if matches(title, #"(?:Conversione|Dedicatione|Cathedra|oann|Pasch|Confessor|Ascensio|Cena)"#) {
            return .white
        }

        // Green: ordinary time, with Pentecost's own octave excluded (the lookahead only
        // looks forward, so "infra octavam Pentecosten" -- octave text *before* the
        // word -- doesn't exclude it; only text *after* "Pentecosten" does).
        if matches(title, #"(?:Pentecosten(?!.*infra octavam)|Epiphaniam|post octavam)"#) {
            return .green
        }

        // Red (second pass): Pentecost Sunday itself, Evangelists, Holy Innocents, the
        // Precious Blood, the Holy Cross, Apostles.
        if matches(title, #"(?:Pentecostes|Evangel|Innocentium|Sanguinis|Cruc|Apostol)"#) {
            return .red
        }

        return .white    // Default fallback -- DO's own final `return 'black'`.
    }

    private static func matches(_ text: String, _ pattern: String, caseSensitive: Bool = false) -> Bool {
        let fullPattern = caseSensitive ? pattern : "(?i)\(pattern)"
        guard let regex = try? Regex(fullPattern) else { return false }
        return (try? regex.firstMatch(in: text)) != nil
    }
}
