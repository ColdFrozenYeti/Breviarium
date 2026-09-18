import BreviariumKit
import SwiftUI

/// The Vespers screen, per `CLAUDE.md`'s visual spec (§ "Page structure") -- paginated,
/// one page per `Section`, with the date line/day title/TOC button/hour title/opening
/// rubric (items 2-6) shown on page 1 only, and a persistent custom header (item 1) and
/// footer (item 10) on every page.
///
/// Not yet built: the Settings-driven rubrics/English toggles (both hardcoded here --
/// `showRubrics: true`, English off) and true content-overflow pagination within a
/// single `Section` (`docs/rubrics-1960-vespers.md` §5 explicitly defers PSALMODIA's
/// possible multi-page split to empirical M5 decision; each page here is one whole
/// `Section`'s content in a `ScrollView`, which is correct but not yet "paginated" in
/// the sense of never needing to scroll within a page).
struct VespersView: View {
    let content: VespersContent
    var showRubrics: Bool = true

    @State private var pageIndex = 0
    @State private var showingToc = false

    private var metrics: Metrics { Metrics() }

    // `BreviariumKit.Section` is spelled out everywhere below: SwiftUI has its own
    // `Section` type, so a bare `Section` is ambiguous with both modules imported.
    private var pages: [BreviariumKit.Section] {
        content.hour.sections.filter { !$0.units.isEmpty }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                navigationHeader
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, section in
                        pageView(index: index, section: section)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                footer
            }
        }
        .sheet(isPresented: $showingToc) {
            tocSheet
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

    // MARK: One page

    private func pageView(index: Int, section: BreviariumKit.Section) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if index == 0 {
                    pageOneHeader
                }
                separator
                sectionHeading(section.kind)
                    .padding(.bottom, metrics.bodySize * 0.6)
                ForEach(Array(section.units.enumerated()), id: \.offset) { _, unit in
                    UnitView(unit: unit, metrics: metrics, showRubrics: showRubrics)
                        .padding(.bottom, metrics.extraLineSpacing)
                }
            }
            .padding(.horizontal, metrics.margin)
            .padding(.bottom, 24)
        }
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
        // CLAUDE.md's "Day title block" wants continuation lines of a wrapped name
        // hanging-indented ~38pt. Plain SwiftUI `Text` has no per-line-position control
        // (no first-line-vs-continuation distinction) to express that; achieving it
        // properly needs either `NSParagraphStyle.firstLineHeadIndent`/`headIndent` via
        // an `AttributedString` (untested whether SwiftUI's `Text` honours those on
        // this OS version) or a `UIViewRepresentable` text view, which `CLAUDE.md` asks
        // to flag before reaching for. Flagged here rather than guessed: the name line
        // below wraps flush-left with no hanging indent for now.
        VStack(alignment: .leading, spacing: metrics.bodySize * 0.2) {
            if let classisLine = content.day.titleBlock.classisLine {
                Text(classisLine)
                    .font(LiturgicalFont.regular(metrics.bodySize))
                    .foregroundStyle(Theme.liturgicalText)
            }
            Text(content.day.titleBlock.nameLine)
                .font(LiturgicalFont.black(metrics.dayTitleNameSize))
                .foregroundStyle(Theme.liturgicalText)
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
            Text("Page \(pageIndex + 1) of \(pages.count)")
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
                ForEach(Array(pages.enumerated()), id: \.offset) { index, section in
                    Button {
                        pageIndex = index
                        showingToc = false
                    } label: {
                        Text(Self.headingText(for: section.kind))
                    }
                }
            }
            .navigationTitle(content.hourTitle)
        }
        .preferredColorScheme(.dark)
    }
}
