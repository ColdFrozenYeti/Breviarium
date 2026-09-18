import BreviariumKit
import SwiftUI

/// The Vespers screen, per `CLAUDE.md`'s visual spec (§ "Page structure") -- the date
/// line/day title/TOC button/hour title (items 2-6) at the top, then a persistent chrome
/// header (item 1) and footer (item 10).
///
/// Rendered as one continuously scrolling document rather than the spec's swipeable
/// pages, for now: direct feedback, after a real rendering showed a long hymn stanza cut
/// off mid-line at a page boundary (the previous height-measurement-based pagination
/// estimated its height slightly wrong, and unlike ordinary overflow the *first* block on
/// a page has nowhere earlier to spill onto). Continuous scroll sidesteps needing that
/// measurement pass at all -- text simply flows, the way a real paginated document's
/// *content* does, without yet committing to where the page breaks fall. Swipeable
/// paging is deferred to the beta milestones (alongside the other hours, the aesthetic
/// pass, and the Ambrosian rite): once the content itself is right, slicing it into pages
/// is a separate, smaller problem. The footer keeps the spec's "Page N of M" shape at a
/// trivial "Page 1 of 1" in the meantime, rather than dropping it, since the layout slot
/// itself isn't going away.
struct VespersView: View {
    let content: VespersContent
    @ObservedObject var settings: SettingsStore

    @State private var showingToc = false
    @State private var showingSettings = false

    private var metrics: Metrics { Metrics(scale: settings.textSize.serifScale, chromeScale: settings.textSize.chromeScale) }

    private var blocks: [ContentBlock] { ContentBlock.blocks(for: content.hour) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                navigationHeader
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(blocks) { block in
                                blockView(block)
                                    .id(block.id)
                            }
                        }
                        .padding(.horizontal, metrics.margin)
                    }
                    .sheet(isPresented: $showingToc) {
                        tocSheet(proxy: proxy)
                    }
                }
                footer
            }
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
        case .psalmSeparator:
            // The sole source of spacing above and below itself -- the antiphon just
            // before it has its own trailing space suppressed (`ContentBlock.blocks`),
            // so this padding alone decides how centred the line looks between the two
            // antiphons it separates.
            Rectangle()
                .fill(Theme.liturgicalText.opacity(0.4))
                .frame(width: metrics.separatorWidth * 0.4, height: 1)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, metrics.bodySize * 0.5)
        case .unit(_, let unit, let alternateVerse, let trailingSpace):
            UnitView(
                unit: unit, metrics: metrics, showRubrics: settings.showRubrics,
                italicizeWholeVerse: alternateVerse, suppressTrailingSpace: trailingSpace == .suppressed
            )
            .padding(.bottom, Self.trailingSpacePadding(trailingSpace, metrics: metrics))
        }
    }

    private static func trailingSpacePadding(_ trailingSpace: ContentBlock.TrailingSpace, metrics: Metrics) -> CGFloat {
        switch trailingSpace {
        case .standard: metrics.extraLineSpacing
        case .suppressed: 0
        case .stanzaBreak: metrics.bodySize * 0.6
        }
    }

    // MARK: Item 1 -- navigation title

    /// A leading gear icon isn't itself part of `CLAUDE.md`'s visual spec (which only
    /// describes the centred title here), but Settings needs *some* entry point and the
    /// spec doesn't say where -- a small, chrome-coloured icon in the otherwise-empty
    /// corner of this row was the chosen option among a few discussed, since it keeps
    /// every other element of the reference screenshot untouched.
    private var navigationHeader: some View {
        ZStack {
            Text(content.hourTitle)
                .font(.system(size: metrics.navTitleSize))
                .foregroundStyle(Theme.chrome)
                .frame(maxWidth: .infinity)
            HStack {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Theme.chrome)
                }
                .accessibilityIdentifier("settingsButton")
                Spacer()
            }
            .padding(.horizontal, metrics.margin)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
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
        // centre Text wouldn't actually land that text on the true midpoint. "Page 1 of
        // 1" until swipeable paging comes back (see this file's own doc comment) -- the
        // slot stays, the count is just trivially true for now.
        ZStack {
            Text("Page 1 of 1")
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

    private func tocSheet(proxy: ScrollViewProxy) -> some View {
        NavigationStack {
            List {
                ForEach(Array(sectionKindsInOrder.enumerated()), id: \.offset) { _, kind in
                    Button {
                        showingToc = false
                        withAnimation {
                            proxy.scrollTo(ContentBlock.sectionStart(kind).id, anchor: .top)
                        }
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
}
