import BreviariumKit
import SwiftUI

/// The *Jump to date* calendar (Beta 4): a month grid with a small dot of each day's
/// liturgical colour under its number (decision 4). The system `DatePicker` can't mark its
/// days, hence this grid; the chrome is English, like the rest of the app's chrome.
struct MonthCalendarView: View {
    let selected: SimpleDate
    let colors: @MainActor (_ year: Int, _ month: Int) -> [Int: CalendarColor]
    let onSelect: (SimpleDate) -> Void

    @State private var year: Int
    @State private var month: Int
    @State private var monthColors: [Int: CalendarColor] = [:]

    init(selected: SimpleDate, colors: @escaping @MainActor (_ year: Int, _ month: Int) -> [Int: CalendarColor], onSelect: @escaping (SimpleDate) -> Void) {
        self.selected = selected
        self.colors = colors
        self.onSelect = onSelect
        _year = State(initialValue: selected.year)
        _month = State(initialValue: selected.month)
    }

    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    private static let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var daysInMonth: Int {
        let next = month == 12 ? (1, year + 1) : (month + 1, year)
        return Computus.addDays(-1, day: 1, month: next.0, year: next.1).day
    }

    /// Sunday first; `Computus.dayOfWeek` is 0 for Sunday.
    private var leadingBlanks: Int { Computus.dayOfWeek(day: 1, month: month, year: year) }

    private var cells: [String] {
        (0..<7).map { "w\($0)" } + (0..<leadingBlanks).map { "b\($0)" } + (1...daysInMonth).map { "d\($0)" }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { move(by: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityIdentifier("previousMonthButton")
                Spacer()
                Text("\(Self.monthNames[month - 1]) \(String(year))")
                    .font(.headline)
                    .foregroundStyle(Theme.liturgicalText)
                    .accessibilityIdentifier("calendarMonthTitle")
                Spacer()
                Button { move(by: 1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityIdentifier("nextMonthButton")
            }
            .foregroundStyle(Theme.icon)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 10) {
                // One `ForEach` with distinct string IDs: the weekday letters, the blanks
                // before the 1st, and the days.
                ForEach(cells, id: \.self) { cell in
                    if cell.hasPrefix("w") {
                        Text(Self.weekdays[Int(cell.dropFirst())!])
                            .font(.caption)
                            .foregroundStyle(Theme.chrome)
                    } else if cell.hasPrefix("b") {
                        Color.clear.frame(height: 44)
                    } else {
                        dayCell(Int(cell.dropFirst())!)
                    }
                }
            }

            Button("Today") {
                onSelect(SimpleDate.today())
            }
            .foregroundStyle(Theme.icon)
            .accessibilityIdentifier("todayButton")
            Spacer()
        }
        .background(Theme.background)
        // Each month's colours are computed once (`OfficeDataStore.calendarColors`); the
        // grid shows first, the dots as soon as they are ready.
        .task(id: year * 100 + month) {
            await Task.yield()
            monthColors = colors(year, month)
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let isSelected = SimpleDate(day: day, month: month, year: year) == selected
        return Button {
            onSelect(SimpleDate(day: day, month: month, year: year))
        } label: {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.background : Theme.liturgicalText)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isSelected ? Theme.icon : Color.clear))
                CalendarDot(color: monthColors[day])
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendarDay-\(day)")
        .accessibilityValue(monthColors[day]?.rawValue ?? "")
    }

    private func move(by months: Int) {
        var m = month + months
        var y = year
        if m < 1 { m = 12; y -= 1 }
        if m > 12 { m = 1; y += 1 }
        (month, year) = (m, y)
    }
}

/// A day's colour dot: filled, or a grey ring for black (decision 4).
struct CalendarDot: View {
    let color: CalendarColor?

    var body: some View {
        Group {
            if let color {
                if color == .black {
                    Circle().stroke(Theme.liturgical(color), lineWidth: 1.2)
                } else {
                    Circle().fill(Theme.liturgical(color))
                }
            } else {
                Color.clear
            }
        }
        .frame(width: 6, height: 6)
    }
}
