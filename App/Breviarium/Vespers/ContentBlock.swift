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
    case unit(index: Int, BreviariumKit.Unit)

    var id: String {
        switch self {
        case .pageHeader: "header"
        case .sectionStart(let kind): "start-\(kind.rawValue)"
        case .unit(let index, _): "unit-\(index)"
        }
    }

    static func blocks(for hour: Hour) -> [ContentBlock] {
        var blocks: [ContentBlock] = [.pageHeader]
        var unitIndex = 0
        for section in hour.sections where !section.units.isEmpty {
            blocks.append(.sectionStart(section.kind))
            for unit in section.units {
                blocks.append(.unit(index: unitIndex, unit))
                unitIndex += 1
            }
        }
        return blocks
    }
}
