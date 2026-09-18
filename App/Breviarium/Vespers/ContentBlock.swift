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
    case unit(index: Int, unit: BreviariumKit.Unit, alternateVerse: Bool)

    var id: String {
        switch self {
        case .pageHeader: "header"
        case .sectionStart(let kind): "start-\(kind.rawValue)"
        case .psalmSeparator(let afterIndex): "psalm-separator-\(afterIndex)"
        case .unit(let index, _, _): "unit-\(index)"
        }
    }

    static func blocks(for hour: Hour) -> [ContentBlock] {
        var blocks: [ContentBlock] = [.pageHeader]
        var unitIndex = 0
        for section in hour.sections where !section.units.isEmpty {
            blocks.append(.sectionStart(section.kind))
            var verseCount = 0
            var previousWasAntiphon = false
            for unit in section.units {
                if case .antiphon = unit {
                    if previousWasAntiphon {
                        blocks.append(.psalmSeparator(afterIndex: unitIndex))
                    }
                    verseCount = 0
                }
                var alternateVerse = false
                if case .verse = unit {
                    alternateVerse = verseCount.isMultiple(of: 2)
                    verseCount += 1
                }
                blocks.append(.unit(index: unitIndex, unit: unit, alternateVerse: alternateVerse))
                unitIndex += 1
                if case .antiphon = unit { previousWasAntiphon = true } else { previousWasAntiphon = false }
            }
        }
        return blocks
    }
}
