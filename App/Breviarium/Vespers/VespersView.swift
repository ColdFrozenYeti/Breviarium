import BreviariumKit
import SwiftUI

/// The Vespers screen, per `CLAUDE.md`'s visual spec (§ "Page structure") -- swipeable
/// pages, with the date line/day title/TOC button/hour title (items 2-6) on page 1 only,
/// and a persistent chrome header (item 1) and footer (item 10) on every page.
///
/// Pagination is content-driven, not "one page per Section": per direct feedback, text
/// should flow continuously the way a real paginated document does -- a section that
/// doesn't fully fit in the space left on a page just continues its own units onto the
/// next page, with no heading/separator repeated (`ContentBlock.sectionStart` is its own
/// block, emitted exactly once per section, wherever it lands). Plain SwiftUI, no
/// UIKit: every block is measured once (an invisible render pass, `HeightPreferenceKey`)
/// at the real content width, then greedily packed into pages against the real
/// available height -- `CLAUDE.md` asks to flag a UIKit reach before taking it, and a
/// height-measurement pass turned out to cover this without needing one.
///
/// Not yet built: the Settings-driven rubrics/English toggles (both hardcoded here --
/// `showRubrics: true`, English off). A single block taller than one page (the whole
/// Hymnus is currently one `.prose` block, not split by stanza) still gets a page to
/// itself with an internal `ScrollView` as a safety net, rather than being split --
/// splitting it would need `HourAssembler` to emit one unit per stanza, not attempted
/// here.
struct VespersView: View {
    let content: VespersContent
    var showRubrics: Bool = true

    @State private var heights: [String: CGFloat] = [:]
    @State private var pages: [[ContentBlock]] = []
    @State private var pageIndex = 0
    @State private var showingToc = false

    private var metrics: Metrics { Metrics() }

    private var blocks: [ContentBlock] { ContentBlock.blocks(for: content.hour) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                navigationHeader
                GeometryReader { geometry in
                    if pages.isEmpty {
                        measuringPass(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        TabView(selection: $pageIndex) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { index, pageBlocks in
                                pageView(pageBlocks)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                }
                footer
            }
        }
        .sheet(isPresented: $showingToc) {
            tocSheet
        }
    }

    // MARK: Measuring pass

    /// Renders every block once, off-screen, purely to read back its real height at the
    /// real content width -- then computes the page breaks and switches to the real
    /// paginated view. The user never sees this pass (opacity 0).
    private func measuringPass(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                blockView(block)
                    .background(
                        GeometryReader { blockGeometry in
                            Color.clear.preference(key: HeightPreferenceKey.self, value: [block.id: blockGeometry.size.height])
                        }
                    )
            }
        }
        .padding(.horizontal, metrics.margin)
        .frame(width: width, alignment: .topLeading)
        .opacity(0)
        .onPreferenceChange(HeightPreferenceKey.self) { newHeights in
            heights.merge(newHeights) { _, new in new }
        }
        .task(id: heights.count) {
            guard heights.count == blocks.count else { return }
            // Working hypothesis, not yet independently confirmed: GeometryReader-based
            // measurement can report a transient, not-yet-settled height on an early
            // layout pass before reporting the real one moments later, without
            // necessarily changing the *count* of blocks measured. This is the
            // best-fit explanation for a real observed failure -- committing to `pages`
            // the instant the count completed once made the Oratio collect's text
            // vanish entirely (present in the assembled Hour, confirmed by a passing
            // oracle test, but absent from every rendered page). Waiting a beat and
            // re-reading `heights` picks up any late-arriving corrections before pages
            // are computed from it; if the symptom recurs, this guess needs revisiting.
            try? await Task.sleep(for: .milliseconds(150))
            guard heights.count == blocks.count, pages.isEmpty else { return }
            // `height` is already the space left over between the navigation header and
            // the footer (this GeometryReader's own VStack siblings) -- a small safety
            // margin, not their heights again, avoids an off-by-a-hair overflow.
            pages = Self.paginate(blocks: blocks, heights: heights, availableHeight: max(height - 4, 1))
        }
    }

    private static func paginate(blocks: [ContentBlock], heights: [String: CGFloat], availableHeight: CGFloat) -> [[ContentBlock]] {
        var pages: [[ContentBlock]] = []
        var current: [ContentBlock] = []
        var currentHeight: CGFloat = 0
        for block in blocks {
            let blockHeight = heights[block.id] ?? 0
            if !current.isEmpty, currentHeight + blockHeight > availableHeight {
                pages.append(current)
                current = []
                currentHeight = 0
            }
            current.append(block)
            currentHeight += blockHeight
        }
        if !current.isEmpty { pages.append(current) }
        return pages.isEmpty ? [[]] : pages
    }

    // MARK: One page

    private func pageView(_ pageBlocks: [ContentBlock]) -> some View {
        // The ScrollView is a safety net (a single block taller than one page, or a
        // slightly-off height estimate), not the primary interaction -- normally a
        // page's own content already fits exactly, since that's what pagination solved.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(pageBlocks) { block in blockView(block) }
            }
            .padding(.horizontal, metrics.margin)
        }
    }

    @ViewBuilder
    private func blockView(_ block: ContentBlock) -> some View {
        switch block {
        case .pageHeader:
            pageOneHeader
        case .sectionStart(let kind):
            VStack(alignment: .leading, spacing: 0) {
                separator
                sectionHeading(kind)
            }
            .padding(.bottom, metrics.bodySize * 0.6)
        case .unit(_, let unit, let alternateVerse):
            UnitView(unit: unit, metrics: metrics, showRubrics: showRubrics, italicizeWholeVerse: alternateVerse)
                .padding(.bottom, metrics.extraLineSpacing)
        }
    }

    // MARK: Item 1 -- navigation title

    private var navigationHeader: some View {
        Text(content.hourTitle)
            .font(.system(size: metrics.navTitleSize))
            .foregroundStyle(Theme.chrome)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    // MARK: Items 2-6 -- page 1's own header block

    private var pageOneHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content.dateLine)
                .font(.system(size: metrics.dateLineSize).italic())
                .foregroundStyle(Theme.rubric)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, metrics.bodySize * 0.8)

            dayTitleBlock
                .padding(.bottom, metrics.bodySize * 0.6)

            Button {
                showingToc = true
            } label: {
                Image(systemName: "list.bullet")
                    .foregroundStyle(Theme.icon)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, metrics.bodySize * 0.8)

            Text(content.hourTitle)
                .font(LiturgicalFont.regular(metrics.hourTitleSize))
                .foregroundStyle(Theme.liturgicalText)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, metrics.bodySize * 0.8)
        }
    }

    private var dayTitleBlock: some View {
        // The name line uses HangingIndentText (a small UIViewRepresentable) rather than
        // plain SwiftUI Text: confirmed against a real rendering that a wrapped name
        // (e.g. "Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum") wraps flush-left with
        // no hanging indent otherwise -- CLAUDE.md's ~38pt hanging indent needs
        // NSParagraphStyle.headIndent, which plain Text has no way to express.
        VStack(alignment: .leading, spacing: metrics.bodySize * 0.2) {
            if let classisLine = content.day.titleBlock.classisLine {
                Text(classisLine)
                    .font(LiturgicalFont.regular(metrics.bodySize))
                    .foregroundStyle(Theme.liturgicalText)
            }
            HangingIndentText(
                text: content.day.titleBlock.nameLine,
                fontName: LiturgicalFont.blackName,
                fontSize: metrics.dayTitleNameSize,
                color: Theme.liturgicalText,
                indent: metrics.hangingIndent
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            if let commemorationLine = content.day.titleBlock.commemorationLine {
                Text(commemorationLine)
                    .font(LiturgicalFont.regular(metrics.bodySize))
                    .foregroundStyle(Theme.liturgicalText)
            }
        }
    }

    // MARK: Item 7 -- section separator

    private var separator: some View {
        Rectangle()
            .fill(Theme.liturgicalText)
            .frame(width: metrics.separatorWidth, height: 1)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, metrics.separatorSpacing)
    }

    // MARK: Item 8 -- section heading

    private func sectionHeading(_ kind: BreviariumKit.Section.Kind) -> some View {
        Text(Self.headingText(for: kind))
            .font(LiturgicalFont.black(metrics.sectionHeadingSize))
            .foregroundStyle(Theme.liturgicalText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func headingText(for kind: BreviariumKit.Section.Kind) -> String {
        switch kind {
        case .introductio: "INTRODUCTIO"
        case .psalmodia: "PSALMODIA"
        case .capitulum: "CAPITULUM"
        case .hymnus: "HYMNUS"
        case .versus: "VERSUS"
        case .canticum: "CANTICUM"
        case .precesFeriales: "PRECES FERIALES"
        case .oratio: "ORATIO"
        case .conclusio: "CONCLUSIO"
        }
    }

    // MARK: Item 10 -- footer

    private var footer: some View {
        // Three independent slots (nothing on the left, per CLAUDE.md) rather than an
        // HStack of Spacers -- with a fixed-width trailing date, two Spacers around a
        // centre Text wouldn't actually land that text on the true midpoint.
        ZStack {
            Text("Page \(pageIndex + 1) of \(max(pages.count, 1))")
                .font(.system(size: metrics.footerSize))
                .foregroundStyle(Theme.chrome)
            HStack {
                Spacer()
                Text(content.shortDate)
                    .font(.system(size: metrics.footerSize))
                    .foregroundStyle(Theme.chrome)
            }
        }
        .padding(.horizontal, metrics.margin)
        .padding(.vertical, 10)
    }

    // MARK: Table of contents

    private var tocSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(sectionKindsInOrder.enumerated()), id: \.offset) { _, kind in
                    Button {
                        if let target = firstPageIndex(containing: kind) { pageIndex = target }
                        showingToc = false
                    } label: {
                        Text(Self.headingText(for: kind))
                    }
                }
            }
            .navigationTitle(content.hourTitle)
        }
        .preferredColorScheme(.dark)
    }

    private var sectionKindsInOrder: [BreviariumKit.Section.Kind] {
        content.hour.sections.filter { !$0.units.isEmpty }.map(\.kind)
    }

    private func firstPageIndex(containing kind: BreviariumKit.Section.Kind) -> Int? {
        pages.firstIndex { page in
            page.contains { block in
                if case .sectionStart(let blockKind) = block { return blockKind == kind }
                return false
            }
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    // A computed property, not a stored `static var =`, so there's no mutable global
    // state for Swift 6's strict concurrency checking to flag -- each access just
    // returns a fresh empty dictionary literal.
    static var defaultValue: [String: CGFloat] { [:] }
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}
