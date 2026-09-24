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
    let content: VespersContent
    @ObservedObject var settings: SettingsStore
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
    @State private var typesetCache = TypesetCache()
    /// A character offset to bring into view (a table-of-contents choice); the reader
    /// clears it once it has jumped.
    @State private var jumpTarget: Int?
    @State private var pageNumber = 1
    @State private var pageCount = 1
    @State private var appliedInitialSection = false

    private var metrics: Metrics { Metrics(scale: settings.textSize.serifScale, chromeScale: settings.textSize.chromeScale) }

    private var dateKey: String { "\(content.day.year)-\(content.day.month)-\(content.day.day)" }

    /// Everything the typeset text depends on.
    private var officeKey: String {
        "\(dateKey)|\(settings.priestPresent)|\(settings.showRubrics)|\(settings.textSize.rawValue)"
    }

    private var office: TypesetOffice {
        let currentMetrics = self.metrics
        let showRubrics = settings.showRubrics
        return typesetCache.office(for: officeKey) {
            OfficeTypesetter(content: content, metrics: currentMetrics, showRubrics: showRubrics).typeset()
        }
    }

    var body: some View {
        let typeset = self.office
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                navigationHeader
                reader(typeset)
                footer
            }
        }
        .sheet(isPresented: $showingToc) { tocSheet(typeset) }
        .onAppear {
            guard !appliedInitialSection, let initialSection else { return }
            appliedInitialSection = true
            jumpTarget = typeset.sectionOffsets.first { $0.kind.rawValue == initialSection }?.offset
        }
        .sheet(isPresented: $showingDatePicker) { datePickerSheet }
    }

    @ViewBuilder
    private func reader(_ office: TypesetOffice) -> some View {
        switch settings.readingMode {
        case .vertical:
            VerticalOfficeReader(
                office: office, officeID: officeKey, dateKey: dateKey, margin: metrics.margin,
                jumpTarget: $jumpTarget, onLink: handleLink, onPageChange: updatePage
            )
        case .horizontal:
            GeometryReader { geometry in
                PagedOfficeReader(
                    office: office, officeID: officeKey, dateKey: dateKey, pageSize: geometry.size, margin: metrics.margin,
                    curl: settings.pageTurn == .curl, jumpTarget: $jumpTarget, onLink: handleLink, onPageChange: updatePage
                )
            }
            // The page-turn style is fixed when the page controller is created.
            .id(settings.pageTurn)
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
                Button(action: onPreviousDay) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Theme.chrome)
                }
                .accessibilityIdentifier("previousDayButton")
                Button(action: onNextDay) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Theme.chrome)
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
    }

    // MARK: Item 10 -- footer

    private var footer: some View {
        // Three independent slots (nothing on the left, per CLAUDE.md) rather than an
        // HStack of Spacers, so the centre text lands on the true midpoint. The short
        // date doubles as a jump-to-date control (the date line on page 1 is the other).
        ZStack {
            Text("Page \(pageNumber) of \(pageCount)")
                .font(.system(size: metrics.footerSize))
                .foregroundStyle(Theme.chrome)
                .accessibilityIdentifier("pageCounter")
            HStack {
                Spacer()
                Button {
                    showingDatePicker = true
                } label: {
                    Text(content.shortDate)
                        .font(.system(size: metrics.footerSize))
                        .foregroundStyle(Theme.chrome)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("jumpToDateButton")
            }
        }
        .padding(.horizontal, metrics.margin)
        .padding(.vertical, 10)
    }

    // MARK: Table of contents

    private func tocSheet(_ office: TypesetOffice) -> some View {
        NavigationStack {
            List {
                ForEach(Array(office.sectionOffsets.enumerated()), id: \.offset) { _, section in
                    Button {
                        showingToc = false
                        jumpTarget = section.offset
                    } label: {
                        Text(OfficeTypesetter.headingText(for: section.kind))
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
        .preferredColorScheme(.dark)
    }

    // MARK: Jump to date

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { SimpleDate(day: content.day.day, month: content.day.month, year: content.day.year).asDate },
                    set: { newDate in
                        showingDatePicker = false
                        onJump(SimpleDate(newDate))
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Jump to date")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingDatePicker = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
