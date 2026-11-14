import BreviariumKit
import SwiftUI

/// The Vespers screen, per `CLAUDE.md`'s visual spec (§ "Page structure"): a persistent
/// chrome header (item 1) and footer (item 10) around the office itself, which
/// `OfficeTypesetter` typesets once (items 2-9, with the page-1 header at the start of
/// the text) and one of two readers shows:
///
/// - **Horizontal** (the default, per the spec's "swipes horizontally between pages"):
///   `PagedOfficeReader` flows the text through page-sized TextKit containers like a
///   printed book, turned by a slide or a page curl.
/// - **Vertical**: `VerticalOfficeReader`, one continuous scroll.
///
/// The user chose both options (Settings), and the book-style flow over the spec's
/// earlier "one page per section group", which could not guarantee a page never cuts a
/// hymn stanza off mid-line (`docs/PLAN.md`, M5).
struct VespersView: View {
    @Environment(\.theme) private var theme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let content: VespersContent
    @ObservedObject var settings: SettingsStore
    /// The hour shown (Beta 2), or the Martyrology (Beta 4), and the hour picker's choice.
    let selection: OfficeHour
    let onSelectHour: (OfficeHour) -> Void
    /// A month of the *Kalendarium* (1.4), which replaced *Jump to date*.
    let kalendarium: @MainActor (_ year: Int, _ month: Int) -> [KalendariumEntry]
    /// Today, which the Kalendarium frames (the fixed date in UI tests).
    let today: SimpleDate
    /// Date navigation lives one level up in `ContentView`, which owns the displayed date
    /// -- this view only ever asks for a move, never computes one itself.
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onJump: (SimpleDate) -> Void
    /// A section to open at, once, on first appearance (UI tests only; see `BreviariumApp`).
    var initialSection: String? = nil

    @State private var showingToc = false
    @State private var showingSettings = false
    @State private var showingKalendarium = false
    @State private var showingHourPicker = false
    @State private var typesetCache = TypesetCache()
    @State private var parallelCache = ParallelCache()
    /// A section to bring into view (a table-of-contents choice); the reader clears it
    /// once it has jumped. Each reader gets it as its own offset (`jumpBinding`).
    @State private var jumpSection: BreviariumKit.Section.Kind?
    @State private var pageNumber = 1
    @State private var pageCount = 1
    @State private var appliedInitialSection = false
    /// *Menus: Hidden* (1.4): the menus brought back by a tap, until the next page turn.
    @State private var menusRevealed = false
    @State private var hideMenusTask: Task<Void, Never>?
    /// The reading position, kept when a reader is recreated (an iPad turned, 1.4).
    @State private var readingAnchor = ReadingAnchor()
    /// The reader's area, for the footer of a spread.
    @State private var readerSize: CGSize = .zero

    private var metrics: Metrics { Metrics(scale: settings.textSize.serifScale, chromeScale: settings.textSize.chromeScale) }

    /// The page controllers are rebuilt when the page turn or the theme changes: the turn
    /// is fixed at creation, and the pages' backgrounds are set there.
    private var readerID: String { "\(settings.pageTurn.rawValue)|\(settings.theme.rawValue)" }

    /// The day and the hour: either changing starts the reader at the top.
    private var dateKey: String { "\(content.day.year)-\(content.day.month)-\(content.day.day)|\(selection.key)" }

    /// Everything the typeset text depends on.
    private var officeKey: String {
        "\(dateKey)|\(settings.priestPresent)|\(settings.showRubrics)|\(settings.textSize.rawValue)"
            + "|\(settings.psalter.rawValue)|\(settings.showEnglish)|\(settings.officium.rawValue)|\(settings.rite.rawValue)"
            + "|\(settings.theme.rawValue)|\(settings.font.rawValue)|\(settings.menus == .hidden)"
    }

    /// Two pages side by side (1.4): horizontal pages in a window wider than tall with
    /// room for two pages of at least about 500 pt -- an iPad in landscape, never an
    /// iPhone (the widest is 956 pt). Every other window shows one page.
    private func isSpread(_ size: CGSize) -> Bool {
        settings.readingMode == .horizontal && size.width > size.height && size.width >= 1000
    }

    /// English shown: off under the Ambrosian rite (Beta 6: Latin only).
    private var englishShown: Bool { settings.showEnglish && settings.rite != .ambrosianus }

    /// A page's side margin: the spec's 28 pt at the default size, widened on an iPad's
    /// wide page so that a line holds no more than about 34 em. (Only where the window is
    /// of regular height: an iPhone in landscape keeps the spec's margins.)
    private func pageMargin(pageWidth: CGFloat) -> CGFloat {
        guard verticalSizeClass == .regular else { return metrics.margin }
        return max(metrics.margin, ((pageWidth - 34 * metrics.bodySize) / 2).rounded())
    }

    /// The hour's sections in order, for the table of contents.
    private var sectionKinds: [BreviariumKit.Section.Kind] {
        ContentBlock.blocks(for: content.hour).compactMap { block in
            if case .sectionStart(let kind) = block { kind } else { nil }
        }
    }

    /// English on: the parallel rows, which differ by orientation (a Matins lesson is
    /// stacked in portrait and side by side in landscape).
    private func parallelOffice(landscape: Bool) -> ParallelOffice {
        let currentMetrics = self.metrics
        let showRubrics = settings.showRubrics
        let theme = self.theme
        let typeface = settings.font
        let showsTableOfContents = settings.menus != .hidden
        return parallelCache.office(for: "\(officeKey)|\(landscape)") {
            OfficeTypesetter(
                content: content, metrics: currentMetrics, showRubrics: showRubrics, theme: theme, typeface: typeface,
                showsTableOfContents: showsTableOfContents
            )
                .typesetParallel(landscape: landscape)
        }
    }

    /// `jumpSection` as the given reader's own offset for that section.
    private func jumpBinding(_ offsets: [(kind: BreviariumKit.Section.Kind, offset: Int)]) -> Binding<Int?> {
        Binding(
            get: { jumpSection.flatMap { kind in offsets.first { $0.kind == kind }?.offset } },
            set: { if $0 == nil { jumpSection = nil } }
        )
    }

    private var office: TypesetOffice {
        let currentMetrics = self.metrics
        let showRubrics = settings.showRubrics
        let theme = self.theme
        let typeface = settings.font
        let showsTableOfContents = settings.menus != .hidden
        return typesetCache.office(for: officeKey) {
            OfficeTypesetter(
                content: content, metrics: currentMetrics, showRubrics: showRubrics, theme: theme, typeface: typeface,
                showsTableOfContents: showsTableOfContents
            ).typeset()
        }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                navigationHeader
                // Beta 6: Ambrosian Compline is Latin only, whatever the English setting.
                Group {
                    if englishShown {
                        parallelReader
                    } else {
                        reader(office)
                    }
                }
                .onGeometryChange(for: CGSize.self) { $0.size } action: { readerSize = $0 }
                footer
            }
        }
        .sheet(isPresented: $showingToc) { tocSheet }
        .onAppear {
            guard !appliedInitialSection, let initialSection else { return }
            appliedInitialSection = true
            jumpSection = sectionKinds.first { $0.rawValue == initialSection }
        }
        .sheet(isPresented: $showingKalendarium) { kalendariumSheet }
    }

    @ViewBuilder
    private func reader(_ office: TypesetOffice) -> some View {
        switch settings.readingMode {
        case .vertical:
            GeometryReader { geometry in
                VerticalOfficeReader(
                    office: office, officeID: officeKey, dateKey: dateKey, margin: pageMargin(pageWidth: geometry.size.width),
                    theme: theme, jumpTarget: jumpBinding(office.sectionOffsets), onLink: handleLink, onPageChange: updatePage
                )
            }
            .id(settings.theme)
        case .horizontal:
            GeometryReader { geometry in
                let spread = isSpread(geometry.size)
                let pageWidth = spread ? (geometry.size.width / 2).rounded() : geometry.size.width
                PagedOfficeReader(
                    office: office, officeID: officeKey, dateKey: dateKey, pageSize: geometry.size,
                    margin: pageMargin(pageWidth: pageWidth), curl: settings.pageTurn == .curl, spread: spread, theme: theme,
                    anchor: readingAnchor, jumpTarget: jumpBinding(office.sectionOffsets), onLink: handleLink,
                    onPageChange: updatePage
                )
                // The page turn and the spine are fixed when the page controller is created.
                .id("\(readerID)|\(spread)")
            }
        }
    }

    /// English on (`CLAUDE.md`, "Parallel English"): the same two reading modes, over
    /// `OfficeTypesetter.typesetParallel`'s rows.
    private var parallelReader: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let parallel = parallelOffice(landscape: landscape)
            // Two columns need the width more than wide margins: the margins stop growing
            // past the default size's 28 pt.
            let margin = min(metrics.margin, 28)
            let gutter = margin * 0.6
            switch settings.readingMode {
            case .vertical:
                ParallelVerticalReader(
                    office: parallel, officeID: "\(officeKey)|\(landscape)", dateKey: dateKey, width: geometry.size.width,
                    margin: margin, gutter: gutter, theme: theme, jumpTarget: jumpBinding(parallel.sectionOffsets),
                    onLink: handleLink, onPageChange: updatePage
                )
                .id(settings.theme)
            case .horizontal:
                // On an iPad spread (1.4) the pages face each other, Latin and English,
                // each with the margins of a single page.
                let spread = isSpread(geometry.size)
                ParallelPagedReader(
                    office: parallel, officeID: "\(officeKey)|\(landscape)", dateKey: dateKey, pageSize: geometry.size,
                    margin: spread ? pageMargin(pageWidth: (geometry.size.width / 2).rounded()) : margin, gutter: gutter,
                    curl: settings.pageTurn == .curl, spread: spread, theme: theme, anchor: readingAnchor,
                    jumpTarget: jumpBinding(parallel.sectionOffsets), onLink: handleLink, onPageChange: updatePage
                )
                .id("\(readerID)|\(spread)")
            }
        }
    }

    private func handleLink(_ url: URL) {
        if url == OfficeLink.tableOfContents {
            showingToc = true
        } else if url == OfficeLink.jumpToDate {
            // The date line opens the Kalendarium (1.4).
            showingKalendarium = true
        }
    }

    private func updatePage(_ number: Int, _ count: Int) {
        // A page turn hides the menus a tap brought back (*Menus: Hidden*, 1.4).
        if number != pageNumber, menusRevealed {
            menusRevealed = false
            hideMenusTask?.cancel()
        }
        pageNumber = number
        pageCount = count
    }

    // MARK: Item 1 -- navigation title

    /// The menus' look (1.4): *Standard* in the theme's rubric colour, *Prayer* in grey,
    /// and *Hidden* drawn as *Prayer* while a tap has brought them back.
    private var menuColor: Color { settings.menus == .standard ? theme.rubric : theme.chrome }

    /// Whether the menus are on screen: always, except under *Hidden* until a tap.
    private var menusShown: Bool { settings.menus != .hidden || menusRevealed }

    /// A leading gear icon and trailing day-navigation chevrons aren't themselves part of
    /// `CLAUDE.md`'s visual spec (which only describes the centred title here), but
    /// Settings and date navigation both need *some* entry point and the spec doesn't say
    /// where -- small icons in this row's otherwise-empty corners keep every other
    /// element of the reference screenshot untouched. Since 1.4 (`docs/1.4_plan.md`) they
    /// are in the rubric colour by default, the title reads as the picker it is, and a
    /// calendar button opens the calendar; *Prayer* keeps the earlier grey row.
    ///
    /// Under *Hidden* the row keeps its height, invisible, so the pages never reflow when
    /// the menus come and go; a tap on it brings them back.
    private var navigationHeader: some View {
        ZStack {
            Button {
                showingHourPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(content.hourTitle)
                        .font(.system(size: metrics.navTitleSize))
                    if settings.menus == .standard {
                        Image(systemName: "chevron.down")
                            .font(.system(size: metrics.navTitleSize * 0.75, weight: .semibold))
                    }
                }
                .foregroundStyle(menuColor)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(content.hourTitle)
            .accessibilityIdentifier("hourPickerButton")
            HStack(spacing: 14) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(menuColor)
                }
                .accessibilityIdentifier("settingsButton")
                Spacer()
                if settings.menus == .standard {
                    Button {
                        showingKalendarium = true
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(menuColor)
                    }
                    .accessibilityIdentifier("calendarButton")
                }
                Button(action: onPreviousDay) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(menuColor)
                }
                .accessibilityIdentifier("previousDayButton")
                Button(action: onNextDay) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(menuColor)
                }
                .accessibilityIdentifier("nextDayButton")
            }
            .padding(.horizontal, metrics.margin)
        }
        .opacity(menusShown ? 1 : 0)
        .allowsHitTesting(menusShown)
        .overlay {
            if !menusShown {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { revealMenus() }
                    .accessibilityElement()
                    .accessibilityLabel("Show menus")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("showMenusTop")
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showingHourPicker) {
            HourPickerView(current: selection, officium: settings.officium, rite: settings.rite) { hour in
                showingHourPicker = false
                onSelectHour(hour)
            }
        }
    }

    /// *Hidden* (1.4): the menus come back for a moment, until the next page turn or
    /// five seconds, whichever is first.
    private func revealMenus() {
        menusRevealed = true
        hideMenusTask?.cancel()
        hideMenusTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            // Not while a sheet the menus opened is up: it would lose its anchor.
            if !showingSettings, !showingHourPicker, !showingKalendarium, !showingToc { menusRevealed = false }
        }
    }

    // MARK: Item 10 -- footer

    private var footer: some View {
        // Three independent slots (nothing on the left, per CLAUDE.md) rather than an
        // HStack of Spacers, so the centre text lands on the true midpoint. The short
        // date doubles as a jump-to-date control (the date line on page 1 is the other).
        // Under *Hidden* (1.4) only a bare page number is left, and a tap on it brings
        // the menus back.
        ZStack {
            if menusShown {
                Text("Page \(pageLabel) of \(pageCount)")
                    .font(.system(size: metrics.footerSize))
                    .foregroundStyle(theme.chrome)
                    .accessibilityIdentifier("pageCounter")
            } else {
                Text(pageLabel)
                    .font(.system(size: metrics.footerSize))
                    .foregroundStyle(theme.chrome)
                    .padding(.horizontal, 24)
                    .contentShape(Rectangle())
                    .onTapGesture { revealMenus() }
                    .accessibilityHint("Shows the menus")
                    .accessibilityIdentifier("pageNumber")
            }
            HStack {
                Spacer()
                Button {
                    showingKalendarium = true
                } label: {
                    Text(content.shortDate)
                        .font(.system(size: metrics.footerSize))
                        .foregroundStyle(menuColor)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("jumpToDateButton")
            }
            .opacity(menusShown ? 1 : 0)
            .allowsHitTesting(menusShown)
        }
        .padding(.horizontal, metrics.margin)
        .padding(.vertical, 10)
    }

    /// The page shown, or on an iPad spread with English off the two pages shown
    /// (`3–4`); facing Latin and English count as one page.
    private var pageLabel: String {
        guard isSpread(readerSize), !englishShown, pageNumber < pageCount else { return "\(pageNumber)" }
        return "\(pageNumber)–\(pageNumber + 1)"
    }

    // MARK: Table of contents

    private var tocSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(sectionKinds.enumerated()), id: \.offset) { _, kind in
                    Button {
                        showingToc = false
                        jumpSection = kind
                    } label: {
                        Text(OfficeTypesetter.headingText(for: kind))
                    }
                }
            }
            .navigationTitle(content.hourTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showingToc = false }
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }

    // MARK: The Kalendarium

    /// The *Kalendarium* (1.4), from the calendar button, the date line and the footer's
    /// date: it replaced *Jump to date*.
    private var kalendariumSheet: some View {
        KalendariumView(
            selected: SimpleDate(day: content.day.day, month: content.day.month, year: content.day.year),
            today: today, scale: settings.textSize.chromeScale, entries: kalendarium,
            onSelect: { date in
                showingKalendarium = false
                onJump(date)
            },
            onClose: { showingKalendarium = false }
        )
    }
}

/// The hour picker (Beta 2), modelled on `design/reference/Hours Picker.png` and reduced to
/// the office's own hours (`CLAUDE.md`): one row per hour, the current one checked.
struct HourPickerView: View {
    @Environment(\.theme) private var theme
    let current: OfficeHour
    /// The office chosen in Settings: the picker lists only its own hours (decided
    /// 2026-09-26).
    let officium: Officium
    var rite: Rite = .romanus
    let onSelect: (OfficeHour) -> Void

    private var rows: [OfficeHour] { OfficeHour.rows(for: officium, rite: rite) }

    var body: some View {
        NavigationStack {
            List(rows, id: \.self) { hour in
                Button {
                    onSelect(hour)
                } label: {
                    HStack {
                        Text(hour.title)
                            .font(.system(size: 20))
                            .foregroundStyle(theme.liturgicalText)
                        Spacer()
                        if hour == current {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.icon)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(theme.background)
                .accessibilityIdentifier("hour-\(hour.key)")
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("Horæ")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(theme.colorScheme)
    }
}
