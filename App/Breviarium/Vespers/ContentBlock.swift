import BreviariumKit

/// One piece of content in the whole hour's flattened, linear reading order --
/// what the pagination in `VespersView` measures and buckets into pages, per direct
/// feedback that text should flow continuously across page boundaries rather than
/// resetting to a fixed "one page per Section" layout. A `Section` that doesn't fit in
/// the space left on a page simply continues its units onto the next page, with no
/// heading/separator repeated -- `.sectionStart` is its own block, emitted exactly once
/// per section, wherever that happens to land.
enum ContentBlock: Identifiable {
    case pageHeader
    case sectionStart(BreviariumKit.Section.Kind)
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
        case .unit(let index, _, _): "unit-\(index)"
        }
    }

    static func blocks(for hour: Hour) -> [ContentBlock] {
        var blocks: [ContentBlock] = [.pageHeader]
        var unitIndex = 0
        for section in hour.sections where !section.units.isEmpty {
            blocks.append(.sectionStart(section.kind))
            var verseCount = 0
            for unit in section.units {
                if case .antiphon = unit { verseCount = 0 }
                var alternateVerse = false
                if case .verse = unit {
                    alternateVerse = verseCount.isMultiple(of: 2)
                    verseCount += 1
                }
                blocks.append(.unit(index: unitIndex, unit: unit, alternateVerse: alternateVerse))
                unitIndex += 1
            }
        }
        return blocks
    }
}
