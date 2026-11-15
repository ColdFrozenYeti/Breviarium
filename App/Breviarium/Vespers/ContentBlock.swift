import BreviariumKit

/// One piece of content in the whole hour's flattened, linear reading order -- what
/// `OfficeTypesetter` turns into one attributed string for every reading mode.
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
    /// `alternateVerse` is true when this `.verse` unit (or the Introductio's *Allelúia*
    /// after its doxology) should render as a whole in
    /// italics -- direct feedback: alternate verses of a psalm should read "as if said
    /// by one person and then another". 1.6.1 (the user, 15 November 2026): the first
    /// verse is upright, then italic, upright... -- even verses are the italic side, as
    /// in the Theme and Font galleries' sample; until 1.6 the first verse was italic.
    /// The psalm's *Glória Patri* carries the alternation on. Always `false` for non-`.verse` units, which
    /// ignore it. Computed here (not in `OfficeTypesetter`, which typesets one unit at a
    /// time with no notion of its neighbours) by counting `.verse` units since the last
    /// `.antiphon`, since an antiphon marks the start of a new psalm/canticle and the
    /// alternation restarts there.
    case unit(index: Int, unit: BreviariumKit.Unit, alternateVerse: Bool, trailingSpace: TrailingSpace)

    /// How much room to leave below a `.unit` block -- also computed here rather than in
    /// `OfficeTypesetter`, for the same "needs to see neighbours" reason as `alternateVerse`.
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
            // Matins: a responsory (after a lesson) is not a psalm, so its verses don't
            // alternate; and the invitatory's antiphon, said twice, is not two psalms.
            var inResponsory = false
            // Inside the *Glória Patri* that answers *Deus in adiutórium* (see below).
            var inOpeningGloria = false
            let separatesPsalms = section.kind != .invitatorium
            let units = section.units
            for (localIndex, unit) in units.enumerated() {
                switch unit {
                case .lesson: inResponsory = true
                case .antiphon, .psalmTitle: inResponsory = false
                default: break
                }
                if case .antiphon = unit {
                    if previousWasAntiphon, separatesPsalms {
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
                // 1.4: the *Glória Patri* answers *Deus in adiutórium* as its next versicle
                // and response (upright, then italic), and the *Allelúia* (or *Laus tibi*)
                // after it belongs to the response. 1.6.1: in whatever section *Deus in
                // adiutórium* falls, not only the Introductio: at Compline it closes the
                // short lesson's section, after the Confiteor.
                let previous = localIndex > 0 ? units[localIndex - 1] : nil
                switch unit {
                case .verse(_, let firstHalf, _, _, _):
                    if case .versicleResponse = previous, Self.isGloriaPatri(firstHalf) {
                        verseCount = 0
                        inOpeningGloria = true
                    }
                case .prose:
                    // The *Allelúia* straight after the *Sicut erat* keeps the flag.
                    if case .verse = previous {} else { inOpeningGloria = false }
                default:
                    inOpeningGloria = false
                }
                var alternateVerse = false
                if case .verse = unit, !inResponsory {
                    alternateVerse = !verseCount.isMultiple(of: 2)
                    verseCount += 1
                }
                if inOpeningGloria, case .prose = unit, case .verse = previous {
                    // The response's italic, like the *Sicut erat* before it.
                    alternateVerse = true
                    inOpeningGloria = false
                }
                var trailingSpace: TrailingSpace = .standard
                if case .prose = unit, localIndex + 1 < units.count, case .prose = units[localIndex + 1] {
                    trailingSpace = .stanzaBreak
                }
                // 1.4: a little room before every *Orémus*, as between the collect's parts.
                if localIndex + 1 < units.count, case .prose(let next, _) = units[localIndex + 1], Self.isOremus(next) {
                    trailingSpace = .stanzaBreak
                }
                blocks.append(.unit(index: unitIndex, unit: unit, alternateVerse: alternateVerse, trailingSpace: trailingSpace))
                unitIndex += 1
                if case .antiphon = unit { previousWasAntiphon = true } else { previousWasAntiphon = false }
            }
        }
        return blocks
    }

    /// The first half of the doxology, *Glória Patri, et Fílio,* (the Dominican office
    /// spells it without the accent).
    static func isGloriaPatri(_ text: String) -> Bool {
        text.hasPrefix("Glória Patri") || text.hasPrefix("Gloria Patri")
    }

    /// *Orémus.* (or the Dominican *Oremus.*) on a line of its own.
    static func isOremus(_ text: String) -> Bool {
        text == "Orémus." || text == "Oremus."
    }
}
