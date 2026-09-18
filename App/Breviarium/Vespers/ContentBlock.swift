import BreviariumKit

/// One piece of content in the whole hour's flattened, linear reading order -- what
/// `VespersView` renders straight down its one continuous scroll (see that file's own
/// doc comment for why it's a single scroll rather than swiped pages for now).
/// `.sectionStart` is its own block, emitted exactly once per section, so a heading is
/// never repeated.
enum ContentBlock: Identifiable {
    case pageHeader
    case sectionStart(BreviariumKit.Section.Kind)
    /// A small dividing line between one psalm/canticle's closing antiphon and the next
    /// one's opening antiphon -- direct feedback, after a real rendering showed two
    /// consecutive antiphons (e.g. "Assúmpta est María in cælum..." immediately followed
    /// by "María Virgo assúmpta est...") running together with nothing but padding
    /// between them, since both share the same bold-italic styling. Detected in
    /// `blocks(for:)` from the unit stream itself: `HourAssembler` always closes a psalm
    /// with its own antiphon and opens the next with its own, so two `.antiphon` units
    /// with nothing between them is exactly a psalm boundary.
    case psalmSeparator(afterIndex: Int)
    /// `alternateVerse` is true when this `.verse` unit should render as a whole in
    /// italics -- direct feedback: alternate verses of a psalm should read "as if said
    /// by one person and then another" (verse 1 italic, verse 2 not, verse 3 italic...
    /// confirmed against the real Bea Psalm135, where verse 10 "Qui percússit..." is
    /// the non-italic one and verse 11 "Et edúxit..." is the italic one -- i.e. odd
    /// verse numbers are the italic side). Always `false` for non-`.verse` units, which
    /// ignore it. Computed here (not in `UnitView`, which renders one unit in isolation
    /// with no notion of its neighbours) by counting `.verse` units since the last
    /// `.antiphon`, since an antiphon marks the start of a new psalm/canticle and the
    /// alternation restarts there.
    case unit(index: Int, unit: BreviariumKit.Unit, alternateVerse: Bool, trailingSpace: TrailingSpace)

    /// How much room to leave below a `.unit` block -- also computed here rather than in
    /// `UnitView`, for the same "needs to see neighbours" reason as `alternateVerse`.
    enum TrailingSpace {
        case standard
        /// No extra gap after this block -- used for a psalm's closing antiphon
        /// immediately before a `.psalmSeparator`. Without this, the antiphon's own
        /// "separate it from the psalm below" bottom padding stacked with the
        /// separator's own padding, leaving the line sitting closer to the antiphon
        /// *below* it than the one above -- direct feedback that the line "ought to be
        /// more centred". Suppressing it here makes the separator's own vertical padding
        /// the sole, symmetric source of spacing on both sides of itself.
        case suppressed
        /// A visible paragraph gap -- used between one hymn stanza and the next
        /// (`HourAssembler.hymnStanzas` emits one `.prose` unit per stanza with nothing
        /// else between them), since the standard inter-line spacing read as one
        /// continuous, unbroken paragraph rather than as separate stanzas -- direct
        /// feedback comparing a real rendering.
        case stanzaBreak
    }

    var id: String {
        switch self {
        case .pageHeader: "header"
        case .sectionStart(let kind): "start-\(kind.rawValue)"
        case .psalmSeparator(let afterIndex): "psalm-separator-\(afterIndex)"
        case .unit(let index, _, _, _): "unit-\(index)"
        }
    }

    static func blocks(for hour: Hour) -> [ContentBlock] {
        var blocks: [ContentBlock] = [.pageHeader]
        var unitIndex = 0
        for section in hour.sections where !section.units.isEmpty {
            blocks.append(.sectionStart(section.kind))
            var verseCount = 0
            var previousWasAntiphon = false
            let units = section.units
            for (localIndex, unit) in units.enumerated() {
                if case .antiphon = unit {
                    if previousWasAntiphon {
                        // Guaranteed by construction: `previousWasAntiphon` is only ever
                        // set right after appending exactly this shape of block.
                        if case .unit(let previousIndex, let previousUnit, let previousAlternate, _) = blocks[blocks.count - 1] {
                            blocks[blocks.count - 1] = .unit(
                                index: previousIndex, unit: previousUnit, alternateVerse: previousAlternate, trailingSpace: .suppressed
                            )
                        }
                        blocks.append(.psalmSeparator(afterIndex: unitIndex))
                    }
                    verseCount = 0
                }
                var alternateVerse = false
                if case .verse = unit {
                    alternateVerse = verseCount.isMultiple(of: 2)
                    verseCount += 1
                }
                var trailingSpace: TrailingSpace = .standard
                if case .prose = unit, localIndex + 1 < units.count, case .prose = units[localIndex + 1] {
                    trailingSpace = .stanzaBreak
                }
                blocks.append(.unit(index: unitIndex, unit: unit, alternateVerse: alternateVerse, trailingSpace: trailingSpace))
                unitIndex += 1
                if case .antiphon = unit { previousWasAntiphon = true } else { previousWasAntiphon = false }
            }
        }
        return blocks
    }
}
