import Foundation

/// The dot of the day's liturgical colour in the *Jump to date* calendar (Beta 4,
/// decision 4): the colour of the day's own office, the one Lauds shows.
public enum CalendarColor: String, Sendable, CaseIterable {
    case white, red, green, violet, rose, black

    /// DO's colour for the office (`LiturgicalColorClassifier`, its `liturgical_color`),
    /// with two changes for the calendar: Our Lady's feasts, which DO marks blue, are
    /// white, their liturgical colour; and Gaudete and Laetare Sundays, which DO gives as
    /// violet, are rose.
    public init(color: LiturgicalColor, officePath: String) {
        if officePath == "Tempora/Adv3-0" || officePath == "Tempora/Quad4-0" {
            self = .rose
            return
        }
        switch color {
        case .white, .blue: self = .white
        case .red: self = .red
        case .green: self = .green
        case .violet: self = .violet
        case .black: self = .black
        }
    }
}

extension LiturgicalCalendarEngine {
    /// The calendar colour of a date: its own office, as at Lauds.
    public func calendarColor(day: Int, month: Int, year: Int) -> CalendarColor? {
        guard let office = self.day(day: day, month: month, year: year) else { return nil }
        return CalendarColor(color: office.color, officePath: office.occurrence.winningPath)
    }
}
