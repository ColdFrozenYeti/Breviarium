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
    let content: VespersContent
    @ObservedObject var settings: SettingsStore
    /// The hour shown (Beta 2), or the Martyrology (Beta 4), and the hour picker's choice.
    let selection: OfficeHour
    let onSelectHour: (OfficeHour) -> Void
    /// Each day's colour for a month of the *Jump to date* calendar (Beta 4).
    let calendarColors: @MainActor (_ year: Int, _ month: Int) -> [Int: CalendarColor]
    /// Date navigation lives one level up in `ContentView`, which owns the displayed date
    /// -- this view only ever asks for a move, never computes one itself.
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onJump: (SimpleDate) -> Void
    /// A section to open at, once, on first appearance (UI tests only; see `BreviariumApp`).
    var initialSection: String? = nil

    @State private var showingToc = false
    @State private var showingSettings = false
    @State private var showingDatePicker = false
    @State private var showingHourPicker = false
    @State private var typesetCache = TypesetCache()
    @State private var parallelCache = ParallelCache()
    /// A section to bring into view (a table-of-contents choice); the reader clears it
    /// once it has jumped. Each reader gets it as its own offset (`jumpBinding`).
    @State private var jumpSection: BreviariumKit.Section.Kind?
    @State private var pageNumber = 1
    @State private var pageCount = 1
    @State private var appliedInitialSection = false

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
            + "|\(settings.theme.rawValue)"
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
        return parallelCache.office(for: "\(officeKey)|\(landscape)") {
            OfficeTypesetter(content: content, metrics: currentMetrics, showRubrics: showRubrics, theme: theme)
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
        return typesetCache.office(for: officeKey) {
            OfficeTypesetter(content: content, metrics: currentMetrics, showRubrics: showRubrics, theme: theme).typeset()
        }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                navigationHeader
                // Beta 6: Ambrosian Compline is Latin only, whatever the English setting.
                if settings.showEnglish, settings.rite != .ambrosianus {
                    parallelReader
                } else {
                    reader(office)
                }
                footer
            }
        }
        .sheet(isPresented: $showingToc) { tocSheet }
        .onAppear {
            guard !appliedInitialSection, let initialSection else { return }
            appliedInitialSection = true
            jumpSection = sectionKinds.first { $0.rawValue == initialSection }
        }
        .sheet(isPresented: $showingDatePicker) { datePickerSheet }
    }

    @ViewBuilder
    private func reader(_ office: TypesetOffice) -> some View {
        switch settings.readingMode {
        case .vertical:
            VerticalOfficeReader(
                office: office, officeID: officeKey, dateKey: dateKey, margin: metrics.margin, theme: theme,
                jumpTarget: jumpBinding(office.sectionOffsets), onLink: handleLink, onPageChange: updatePage
            )
            .id(settings.theme)
        case .horizontal:
            GeometryReader { geometry in
                PagedOfficeReader(
                    office: office, officeID: officeKey, dateKey: dateKey, pageSize: geometry.size, margin: metrics.margin,
                    curl: settings.pageTurn == .curl, theme: theme, jumpTarget: jumpBinding(office.sectionOffsets), onLink: handleLink,
                    onPageChange: updatePage
                )
            }
            // The page-turn style is fixed when the page controller is created.
            .id(readerID)
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
                ParallelPagedReader(
                    office: parallel, officeID: "\(officeKey)|\(landscape)", dateKey: dateKey, pageSize: geometry.size,
                    margin: margin, gutter: gutter, curl: settings.pageTurn == .curl, theme: theme,
                    jumpTarget: jumpBinding(parallel.sectionOffsets), onLink: handleLink, onPageChange: updatePage
                )
                .id(readerID)
            }
        }
    }

    private func handleLink(_ url: URL) {
        if url == OfficeLink.tableOfContents {
            showingToc = true
        } else if url == OfficeLink.jumpToDate {
            showingDatePicker = true
        }
    }

    private func updatePage(_ number: Int, _ count: Int) {
        pageNumber = number
        pageCount = count
    }

    // MARK: Item 1 -- navigation title

    /// A leading gear icon and trailing day-navigation chevrons aren't themselves part of
    /// `CLAUDE.md`'s visual spec (which only describes the centred title here), but
    /// Settings and date navigation both need *some* entry point and the spec doesn't say
    /// where -- small, chrome-coloured icons in this row's otherwise-empty corners were
    /// the chosen option among a few discussed, since they keep every other element of
    /// the reference screenshot untouched.
    private var navigationHeader: some View {
        ZStack {
            // The title opens the hour picker (Universalis's own behaviour). A tappable
            // `Text`, not a `Button`, so UI tests still find it as static text.
            Text(content.hourTitle)
                .font(.system(size: metrics.navTitleSize))
                .foregroundStyle(theme.chrome)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { showingHourPicker = true }
                .accessibilityIdentifier("hourPickerButton")
            HStack {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(theme.chrome)
                }
                .accessibilityIdentifier("settingsButton")
                Spacer()
                Button(action: onPreviousDay) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(theme.chrome)
                }
                .accessibilityIdentifier("previousDayButton")
                Button(action: onNextDay) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(theme.chrome)
                }
                .accessibilityIdentifier("nextDayButton")
            }
            .padding(.horizontal, metrics.margin)
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

    // MARK: Item 10 -- footer

    private var footer: some View {
        // Three independent slots (nothing on the left, per CLAUDE.md) rather than an
        // HStack of Spacers, so the centre text lands on the true midpoint. The short
        // date doubles as a jump-to-date control (the date line on page 1 is the other).
        ZStack {
            Text("Page \(pageNumber) of \(pageCount)")
                .font(.system(size: metrics.footerSize))
                .foregroundStyle(theme.chrome)
                .accessibilityIdentifier("pageCounter")
            HStack {
                Spacer()
                Button {
                    showingDatePicker = true
                } label: {
                    Text(content.shortDate)
                        .font(.system(size: metrics.footerSize))
                        .foregroundStyle(theme.chrome)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("jumpToDateButton")
            }
        }
        .padding(.horizontal, metrics.margin)
        .padding(.vertical, 10)
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

    // MARK: Jump to date

    private var datePickerSheet: some View {
        NavigationStack {
            MonthCalendarView(
                selected: SimpleDate(day: content.day.day, month: content.day.month, year: content.day.year),
                colors: calendarColors
            ) { date in
                showingDatePicker = false
                onJump(date)
            }
            .padding()
            // Black to the sheet's edges, under the title bar too, as the hour picker is:
            // the padding sat outside the calendar's own black, in the sheet's grey.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .navigationTitle("Jump to date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingDatePicker = false }
                }
            }
        }
        .presentationBackground(theme.background)
        .preferredColorScheme(theme.colorScheme)
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
