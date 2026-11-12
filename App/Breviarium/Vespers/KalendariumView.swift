import BreviariumKit
import SwiftUI

/// The *Kalendarium* (1.4, `docs/1.4_plan.md`, M2), which replaces *Jump to date*: the
/// year as a list of months, one row a day, modelled on Universalis's calendar list
/// (measured from the user's screenshot; `CLAUDE.md`, "Kalendarium"):
///
/// - a band with the month and year at the top of each month, pinned while it scrolls;
/// - a row per day, every row one line and the same height, divided by fine rules: the
///   day's number, its class (*III*), its name (bold for a I or II class day), and a dot
///   of its colour; a name too long for the line in an Ordo's abbreviations
///   (`Kalendarium.shortName`), and cut off if that is still too long;
/// - today framed in the theme's icon colour;
/// - the months down the right edge, to jump to one, and the year and *Today* at the foot.
///
/// Every row comes from the engine (`OfficeDataStore.kalendarium`); this view only lays it
/// out. Tapping a day opens it, at the hour already chosen.
struct KalendariumView: View {
    @Environment(\.theme) private var theme
    /// The day shown in the office, where the list opens.
    let selected: SimpleDate
    let today: SimpleDate
    /// The chrome's text-size scale (`TextSizeSetting.chromeScale`).
    let scale: CGFloat
    let entries: @MainActor (_ year: Int, _ month: Int) -> [KalendariumEntry]
    let onSelect: (SimpleDate) -> Void
    let onClose: () -> Void

    @State private var year: Int
    /// A row or month to scroll to, once laid out.
    @State private var scrollTarget: String?

    init(
        selected: SimpleDate, today: SimpleDate, scale: CGFloat,
        entries: @escaping @MainActor (_ year: Int, _ month: Int) -> [KalendariumEntry],
        onSelect: @escaping (SimpleDate) -> Void, onClose: @escaping () -> Void
    ) {
        self.selected = selected
        self.today = today
        self.scale = scale
        self.entries = entries
        self.onSelect = onSelect
        self.onClose = onClose
        _year = State(initialValue: selected.year)
        _scrollTarget = State(initialValue: Self.rowID(selected.day, selected.month))
    }

    /// The chrome's months, in Latin like the date line (`LatinDateLine`).
    static let monthNames = [
        "Ianuarius", "Februarius", "Martius", "Aprilis", "Maius", "Iunius",
        "Iulius", "Augustus", "September", "October", "November", "December",
    ]
    static let monthIndex = ["Ian", "Feb", "Mar", "Apr", "Mai", "Iun", "Iul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func rowID(_ day: Int, _ month: Int) -> String { "d\(month)-\(day)" }
    static func monthID(_ month: Int) -> String { "m\(month)" }

    private var nameSize: CGFloat { 17 * scale }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(1...12, id: \.self) { month in
                                Section {
                                    ForEach(entries(year, month), id: \.day) { entry in
                                        row(entry)
                                    }
                                } header: {
                                    monthBand(month)
                                }
                            }
                        }
                        // Room for the month index on the right and the buttons below.
                        .padding(.trailing, 30)
                        .padding(.bottom, 80)
                    }
                    .onAppear { scroll(proxy) }
                    .onChange(of: scrollTarget) { scroll(proxy) }
                    .onChange(of: year) { scroll(proxy) }

                    monthIndexColumn
                }
                .overlay(alignment: .bottom) { footer }
            }
            .background(theme.background)
            .navigationTitle("Kalendarium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
        .presentationBackground(theme.background)
        .preferredColorScheme(theme.colorScheme)
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard let target = scrollTarget else { return }
        // After the lazy stack has laid out the rows around the target.
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: target.hasPrefix("m") ? .top : .center)
            scrollTarget = nil
        }
    }

    // MARK: The month band

    private func monthBand(_ month: Int) -> some View {
        Text("\(Self.monthNames[month - 1]) \(String(year))")
            .font(.system(size: nameSize, weight: .semibold))
            .foregroundStyle(theme.liturgicalText)
            .padding(.leading, 17)
            .frame(maxWidth: .infinity, minHeight: 29 * scale, alignment: .leading)
            .background(theme.background.overlay(theme.chrome.opacity(0.16)))
            .id(Self.monthID(month))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("kalendariumMonth-\(month)")
    }

    // MARK: A day

    private func row(_ entry: KalendariumEntry) -> some View {
        let isToday = entry.day == today.day && entry.month == today.month && entry.year == today.year
        return Button {
            onSelect(SimpleDate(day: entry.day, month: entry.month, year: entry.year))
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(entry.day)")
                    .font(.system(size: nameSize))
                    .foregroundStyle(theme.liturgicalText)
                    .frame(width: 32 * scale, alignment: .leading)
                Text(entry.classis ?? "")
                    .font(.system(size: nameSize * 0.8))
                    .foregroundStyle(theme.chrome)
                    .frame(width: 40 * scale, alignment: .leading)
                // The whole name if it fits the line, else the abbreviated one, cut off
                // if it still doesn't (decided 2026-11-12: one line, equal rows).
                ViewThatFits(in: .horizontal) {
                    name(entry.titleBlock.nameLine, major: Self.isMajor(entry.classis))
                        .fixedSize(horizontal: true, vertical: false)
                    name(entry.shortName, major: Self.isMajor(entry.classis))
                        .truncationMode(.tail)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                if let color = entry.color {
                    let (symbol, tint) = dot(color)
                    Image(systemName: symbol)
                        .font(.system(size: nameSize * 0.62))
                        .foregroundStyle(tint)
                        .padding(.leading, 6)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .padding(.vertical, 8 * scale)
            .contentShape(Rectangle())
            .overlay {
                if isToday {
                    Rectangle().strokeBorder(theme.icon, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.chrome.opacity(0.35))
                .frame(height: 0.5)
                .padding(.leading, 16)
        }
        .id(Self.rowID(entry.day, entry.month))
        .accessibilityElement(children: .combine)
        .accessibilityValue(entry.color?.rawValue ?? "")
        .accessibilityIdentifier("kalendariumDay-\(entry.month)-\(entry.day)")
    }

    private func name(_ text: String, major: Bool) -> some View {
        Text(text)
            .font(.system(size: nameSize, weight: major ? .bold : .regular))
            .foregroundStyle(theme.liturgicalText)
    }

    /// A I or II class day is bold (Universalis bolds Sundays and feasts); the Ambrosian
    /// ranks read *Sol. I cl.*, *II cl.* and so on.
    static func isMajor(_ classis: String?) -> Bool {
        guard let classis else { return false }
        if classis == "I" || classis == "II" { return true }
        let words = classis.split(separator: " ")
        return zip(words, words.dropFirst()).contains { ($0 == "I" || $0 == "II") && $1 == "cl." }
            || classis.hasPrefix("I cl.") || classis.hasPrefix("II cl.")
    }

    /// The dot, as the calendar has drawn it since Beta 4: filled, or a grey ring for
    /// black; on a light theme a black day is a black dot (the user, 10 October 2026), and
    /// a white day a gold ring, without which it vanishes into the page (11 October 2026).
    private func dot(_ color: CalendarColor) -> (String, Color) {
        switch color {
        case .black where theme.isLight: ("circle.fill", .black)
        case .black: ("circle", theme.liturgical(.black))
        case .white where theme.isLight: ("circle", Self.gold)
        default: ("circle.fill", theme.liturgical(color))
        }
    }

    /// The white dot's edge on a light theme: an old gold, dark enough to read on white.
    static let gold = Color(red: 0.722, green: 0.569, blue: 0.184) // #B8912F

    // MARK: The month index and the foot

    private var monthIndexColumn: some View {
        VStack(spacing: 2) {
            ForEach(1...12, id: \.self) { month in
                Button {
                    scrollTarget = Self.monthID(month)
                } label: {
                    Text(Self.monthIndex[month - 1])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.icon)
                        .frame(width: 30, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("kalendariumIndex-\(month)")
            }
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 18) {
                Button {
                    year -= 1
                    scrollTarget = Self.monthID(1)
                } label: { Image(systemName: "chevron.left") }
                    .accessibilityIdentifier("previousYearButton")
                Text(String(year))
                    .monospacedDigit()
                    .accessibilityIdentifier("kalendariumYear")
                Button {
                    year += 1
                    scrollTarget = Self.monthID(1)
                } label: { Image(systemName: "chevron.right") }
                    .accessibilityIdentifier("nextYearButton")
            }
            .padding(.horizontal, 20)
            .frame(height: 48)
            .background(Capsule().fill(theme.chrome.opacity(0.22)).background(Capsule().fill(theme.background)))
            Spacer()
            Button {
                year = today.year
                scrollTarget = Self.rowID(today.day, today.month)
            } label: {
                Text("Today")
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(Capsule().fill(theme.chrome.opacity(0.22)).background(Capsule().fill(theme.background)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("kalendariumTodayButton")
        }
        .font(.system(size: 17 * scale))
        .foregroundStyle(theme.liturgicalText)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
