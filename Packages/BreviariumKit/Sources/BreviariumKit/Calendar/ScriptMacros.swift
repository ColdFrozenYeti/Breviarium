import Foundation

/// The render-time facts `ScriptMacros` needs beyond what `SectionResolver` already
/// carries in `ConditionalContext` — everything DO's own `&`-macro subroutines
/// (`horasscripts.pl`) read from other globals (`$winner`/`$rank`/`$rule`, `$priest`,
/// `$dayname[0]`, `$dayofweek`, `$vespera`) rather than from the per-file conditional
/// context.
public struct MacroContext: Sendable {
    /// `$dayname[0]` — the temporal week code of the office actually being prayed this
    /// Vespers (e.g. `"Quadp1"`, `"Pasc0"`), not necessarily today's own week when
    /// tomorrow's first Vespers pre-empts it.
    public var weekName: String
    /// `$dayofweek`: 0 = Sunday ... 6 = Saturday, for the calendar date this Vespers is
    /// prayed on (i.e. "today", regardless of whether tomorrow's office wins).
    public var dayOfWeek: Int
    public var priest: Bool
    /// `$rank`/`$rule` of the winning office (`Concurrence.vespersOffice`).
    public var winningRank: OfficeRank
    public var winningRule: String
    /// `$vespera == 1` (tomorrow's first Vespers pre-empts) vs. `== 3` (today's own).
    public var isFirstVespers: Bool

    public init(
        weekName: String, dayOfWeek: Int, priest: Bool,
        winningRank: OfficeRank, winningRule: String, isFirstVespers: Bool
    ) {
        self.weekName = weekName
        self.dayOfWeek = dayOfWeek
        self.priest = priest
        self.winningRank = winningRank
        self.winningRule = winningRule
        self.isFirstVespers = isFirstVespers
    }
}

/// Resolves `&Name` script macros (`do-format.md`) for Vespers — a focused, non-GABC
/// port of the handful of `:ScriptFunc` subroutines Vespers actually reaches
/// (`horasscripts.pl`), with every chant/GABC branch dropped per `CLAUDE.md` ("no
/// chant, audio, or play button"). Each macro ultimately bottoms out in a `$Name`
/// lookup from `Psalterium/Common/Prayers.txt`, resolved via the same `SectionResolver`
/// that already handles `$`/`@` — `ScriptMacros` only decides *which* prayer text and
/// how to adjust it.
public enum ScriptMacros {

    /// The macro names Vespers' own `Ordinarium/Vespera.txt` skeleton invokes directly.
    /// (`&Divinum_auxilium` also appears there, but only `(rubrica cisterciensis aut
    /// rubrica 1963)` — never for us.)
    public static let vespersMacroNames: Set<String> = [
        "Deus_in_adjutorium", "Alleluia", "Dominus_vobiscum", "Benedicamus_Domino", "Gloria",
    ]

    /// Resolves one `&Name` macro to its final text, or `nil` if `name` isn't one this
    /// port implements (callers should leave the line untouched in that case, the same
    /// way `SectionResolver` already treats unresolvable references).
    public static func resolve(_ name: String, context: MacroContext, resolver: SectionResolver, isEnglish: Bool = false) -> String? {
        switch name {
        case "Deus_in_adjutorium": return deusInAdjutorium(resolver: resolver, isEnglish: isEnglish)
        case "Alleluia": return alleluia(context: context, resolver: resolver)
        case "Gloria": return gloria(context: context, resolver: resolver)
        case "Dominus_vobiscum": return dominusVobiscum(context: context, resolver: resolver)
        case "Benedicamus_Domino": return benedicamusDomino(context: context, resolver: resolver)
        default: return nil
        }
    }

    /// `horasscripts.pl:30-63`. The ferial/festal/solemn tone selection is entirely a
    /// GABC/chant concern (`$lang !~ /gabc/` is always true for us, so DO's own logic
    /// always takes that branch too) — always the plain "Deus in adiutorium" text.
    ///
    /// The section name is queried with the I-spelling, not `Prayers.txt`'s own literal
    /// `[Deus in adjutorium]` header: `LatinOrthography.normalize` runs over the whole
    /// raw file text before `RawSectionParser` ever splits it into sections, so a
    /// header naming a real Latin word (not a `@`/`$`/`&` reference identifier, which
    /// are exempted) is stored J-to-I-normalized like any other prose in the file —
    /// confirmed missing against the real bundle before this fix (querying the literal
    /// `j`-spelling silently found nothing).
    private static func deusInAdjutorium(resolver: SectionResolver, isEnglish: Bool) -> String {
        resolver.resolve(path: SectionResolver.prayersPath, section: isEnglish ? "Deus in adjutorium" : "Deus in adiutorium")
    }

    /// `horasscripts.pl:64-83`. Chooses "Allelúia" vs. the penitential "Laus tibi,
    /// Dómine..." — said throughout Septuagesima and Lent (any `"Quad"`-prefixed week,
    /// which covers both the `Quadp1-3` pre-Lent weeks and `Quad0-6` Lent proper), except
    /// at the one first Vespers where Alleluia is still said for the last time before the
    /// season's own first Vespers takes over (`Septuagesima_vesp()`).
    ///
    /// **Scope limit:** `Septuagesima_vesp()`'s rarer branch — the evening before
    /// Septuagesima Sunday when a higher-ranking weekday office keeps *today's own*
    /// second Vespers instead of the usual automatic Sunday pre-emption — isn't covered;
    /// that needs the original (non-winning) office's week code, which `Concurrence`
    /// doesn't currently expose when it loses. Flagged rather than silently assumed
    /// handled; a real occurrence should surface as an oracle diff.
    private static func alleluia(context: MacroContext, resolver: SectionResolver) -> String {
        let text = resolver.resolve(path: SectionResolver.prayersPath, section: "Alleluia")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        let isSeptuagesimaVespers =
            context.dayOfWeek == 6 && context.isFirstVespers && context.weekName.hasPrefix("Quadp1")
        let usesLausTibi = context.weekName.range(of: "Quad", options: .caseInsensitive) != nil && !isSeptuagesimaVespers

        let index = usesLausTibi ? 1 : 0
        return index < lines.count ? lines[index] : text
    }

    /// `horasscripts.pl:89-95`. Drops the GABC `Prima`/`gabc` branch (irrelevant: not
    /// chant, and not a Vespers concern) and `Gloria1`/`Gloria2` (responsories/
    /// Invitatorium — not part of Vespers).
    private static func gloria(context: MacroContext, resolver: SectionResolver) -> String {
        if triduumGloriaOmitted(context: context) { return "" }
        if context.winningRule.range(of: "Requiem gloria", options: .caseInsensitive) != nil {
            return resolver.resolve(path: SectionResolver.prayersPath, section: "Requiem")
        }
        return resolver.resolve(path: SectionResolver.prayersPath, section: "Gloria")
    }

    /// `horas.pl:226-233`. The Triduum's silenced Gloria Patri: Holy Week (`"Quad6"`),
    /// Thursday through Saturday (`dayOfWeek > 3`), and only for the day's *own* Vespers
    /// (not first Vespers of Easter, anticipated Holy Saturday evening, which falls
    /// outside `Quad6` entirely by the time it's resolved as tomorrow's office).
    private static func triduumGloriaOmitted(context: MacroContext) -> Bool {
        context.weekName.range(of: "Quad6", options: .caseInsensitive) != nil
            && context.dayOfWeek > 3
            && context.isFirstVespers == false
    }

    /// `horasscripts.pl:112-129`. Vespers calls plain `&Dominus_vobiscum` (not the
    /// `_1`/`_2` wrappers, which are Prime/Office-of-the-Dead-specific and always leave
    /// `$precesferiales` at its default 0 for us) — so this always takes the plain
    /// priest/non-priest branch `CLAUDE.md`'s toggle describes directly.
    private static func dominusVobiscum(context: MacroContext, resolver: SectionResolver) -> String {
        let text = resolver.resolve(path: SectionResolver.prayersPath, section: "Dominus")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 4 else { return text }
        return context.priest ? "\(lines[0])\n\(lines[1])" : "\(lines[2])\n\(lines[3])"
    }

    /// `horasscripts.pl:160-186`. Adds the farewell "..., allelúia, allelúia." to both
    /// the versicle and response throughout the Paschal octave (`"Pasc0"`) and at the one
    /// first Vespers of Septuagesima (see `alleluia`'s scope-limit note — the same rarer
    /// branch is dropped here too, for the same reason). Every other GABC-chantTone
    /// branch is dropped as not applicable to plain text.
    private static func benedicamusDomino(context: MacroContext, resolver: SectionResolver) -> String {
        let text = resolver.resolve(path: SectionResolver.prayersPath, section: "Benedicamus Domino")

        let isSeptuagesimaVespers =
            context.dayOfWeek == 6 && context.isFirstVespers && context.weekName.hasPrefix("Quadp1")
        let isPaschalOctave = context.weekName.range(of: "Pasc0", options: .caseInsensitive) != nil

        guard isPaschalOctave || isSeptuagesimaVespers else { return text }

        let alleluiaDuplex = resolver.resolve(path: SectionResolver.prayersPath, section: "Alleluia Duplex")
        let firstLine = alleluiaDuplex.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let suffix = firstLine.lowercased()

        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard line.hasSuffix(".") else { return String(line) }
                return "\(line.dropLast()), \(suffix)"
            }
            .joined(separator: "\n")
    }
}
