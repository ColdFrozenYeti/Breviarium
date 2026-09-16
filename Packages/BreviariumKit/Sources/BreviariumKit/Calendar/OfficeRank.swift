import Foundation

/// A parsed `[Rank]` field: `Title;;DegreeLabel;;NumericPrecedence;;CommuneReference`
/// (`do-format.md`). `numericPrecedence` is DO's old (pre-1960) nine-or-so-grade scale,
/// used for every version's precedence comparisons regardless of which rubrics are being
/// rendered; `docs/rubrics-1960-vespers.md` §1 has the full table and how 1960 collapses
/// it into just four display tiers.
public struct OfficeRank: Equatable, Sendable {
    public var title: String
    public var degreeLabel: String
    public var numericPrecedence: Double
    public var communeReference: String

    public init(title: String, degreeLabel: String, numericPrecedence: Double, communeReference: String) {
        self.title = title
        self.degreeLabel = degreeLabel
        self.numericPrecedence = numericPrecedence
        self.communeReference = communeReference
    }

    /// Parses a raw `[Rank]` field value. Returns `nil` if it doesn't look like a rank
    /// field at all (fewer than 3 `;;`-separated parts, or a non-numeric precedence) --
    /// callers should treat that the same way DO treats a missing/empty `%saint`/
    /// `%tempora` hash: there's no real office here.
    public init?(rankFieldValue: String) {
        let parts = rankFieldValue.components(separatedBy: ";;")
        // A resolved [Rank] field's numeric part can carry a trailing newline (the real
        // file's own trailing blank line surviving through ConditionalLineProcessor's
        // join) -- Double(_:) rejects that outright, so this only ever surfaced once
        // Occurrence was actually run against real bundled data end to end, not the
        // synthetic (already-trimmed) fixtures every unit test had used until then.
        guard parts.count >= 3, let precedence = Double(parts[2].trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        title = parts[0]
        degreeLabel = parts[1]
        numericPrecedence = precedence
        communeReference = parts.count > 3 ? parts[3].trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }
}

/// Maps `OfficeRank.numericPrecedence` to the 1960-rubrics display name, per
/// `web/www/horas/Latin/Psalterium/Comment.txt`'s `[Festa] (rubrica 196)` block
/// (`docs/rubrics-1960-vespers.md` §1): five of the eight old grades collapse into just
/// two display tiers (IV./III. classis), which is a real, citable simplification the
/// 1960 rubrics made -- not an approximation this project is introducing.
public enum RankDisplayName1960 {
    private static let table = [
        "Feria",         // 0
        "IV. classis",   // 1 - Simplex
        "III. classis",  // 2 - Semiduplex
        "III. classis",  // 3 - Duplex
        "III. classis",  // 4 - Duplex majus
        "II. classis",   // 5 - Duplex II classis
        "I. classis",    // 6 - Duplex I classis
        "I. classis",    // 7 - above
    ]

    /// Fractional precedence values are fine-grained tie-breaking nudges within the same
    /// conceptual tier (e.g. `4.9`, `6.01`) -- they round down to their integer floor's
    /// display name, never crossing into the next tier.
    public static func name(for numericPrecedence: Double) -> String {
        let index = min(table.count - 1, max(0, Int(numericPrecedence.rounded(.down))))
        return table[index]
    }
}
