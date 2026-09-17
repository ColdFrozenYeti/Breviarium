/// The bundle `BreviariumData` produces and `BreviariumKit` loads at app launch:
/// every parsed office file (raw sections, unevaluated — see `RawSectionParser`) plus
/// the flattened 1960 sanctoral calendar table (`KalendariaResolver`).
///
/// Shipped as plain (uncompressed) JSON for the alpha — `docs/PLAN.md`'s data-pipeline
/// section anticipated possibly gzip-compressing this, but that was explicitly
/// contingent on measured size warranting it ("M2 measures this and only reaches for a
/// byte-offset index or a custom binary layout if the measured numbers say so"); the
/// same reasoning applies to compression. Measuring comes first — see `BreviariumData`'s
/// size report — and compression is a candidate follow-up only if the plain-JSON number
/// turns out to matter, not a default.
public struct DataBundle: Codable, Sendable {
    public var formatVersion: Int
    /// The plain Latin corpus (`Tempora`, `Sancti`, `Commune`, `Psalterium`) — every `@`
    /// reference within it resolves against this same set, since DO's `@` directive is
    /// always same-language by convention.
    public var latin: [RawOfficeFile]
    /// The Pius XII (Bea) psalter overlay — `Psalterium/` only (`do-format.md`'s options
    /// table). Kept separate rather than merged into `latin`, since its own paths (e.g.
    /// `"Psalterium/Dom1/Matutinum"`) intentionally collide with `latin`'s: `makeCorpus`
    /// layers this on top so a Bea file shadows its plain-Latin counterpart, falling
    /// back to `latin` for anything the Bea overlay doesn't have.
    public var latinBea: [RawOfficeFile]
    /// DO's own English text (`web/www/horas/English`) — Douay-Rheims wording for
    /// Scripture (psalms, canticles, capitula) and DO's own English translation for
    /// everything else, confirmed by direct comparison against DRB wording (e.g. Ps.
    /// 109 "The Lord said to my Lord: Sit thou at my right hand..." matches verbatim) —
    /// `CLAUDE.md`'s "Douay-Rheims (as on DRBO) for Scripture and Divinum Officium's
    /// English for everything else" is already what this single tree contains, not two
    /// separate sources to reconcile. No orthography normalisation runs on it
    /// (`CLAUDE.md`: "Never touch English").
    public var english: [RawOfficeFile]
    /// The flattened 1960 sanctoral calendar: `"MM-DD" -> fileref` (`KalendariaResolver`).
    public var calendar: [String: String]

    public init(
        formatVersion: Int = breviariumKitDataFormatVersion,
        latin: [RawOfficeFile],
        latinBea: [RawOfficeFile],
        english: [RawOfficeFile],
        calendar: [String: String]
    ) {
        self.formatVersion = formatVersion
        self.latin = latin
        self.latinBea = latinBea
        self.english = english
        self.calendar = calendar
    }

    /// The Latin corpus `SectionResolver` should read from: the Bea psalter layered on
    /// top of plain Latin, matching DO's own `Latin-Bea` dash-fallback behaviour
    /// (`do-format.md`).
    public func makeLatinCorpus() -> OfficeCorpus {
        LayeredOfficeCorpus(layers: [InMemoryOfficeCorpus(files: latinBea), InMemoryOfficeCorpus(files: latin)])
    }

    /// The English corpus — no Bea-equivalent overlay exists for English (confirmed: no
    /// `English-Bea` sibling directory in the checkout), so this is just the one tree.
    public func makeEnglishCorpus() -> OfficeCorpus {
        InMemoryOfficeCorpus(files: english)
    }
}

/// Tries each layer's `OfficeCorpus` in order, returning the first non-empty result —
/// the read-time equivalent of DO's own dash-fallback language layering
/// (`SetupString.pl:594-599`), generalised as a reusable combinator.
public struct LayeredOfficeCorpus: OfficeCorpus {
    public var layers: [OfficeCorpus]

    public init(layers: [OfficeCorpus]) {
        self.layers = layers
    }

    public func rawSections(path: String, name: String) -> [RawSection] {
        for layer in layers {
            let sections = layer.rawSections(path: path, name: name)
            if !sections.isEmpty { return sections }
        }
        return []
    }
}
