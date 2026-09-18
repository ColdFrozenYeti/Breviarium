import Foundation

/// A plain day/month/year, for the app's own date-navigation state -- deliberately not
/// `Date`/`Calendar` round-tripped on every step, so "the next day" is exact integer
/// arithmetic (`Computus.addDays`) with no timezone to get wrong.
struct SimpleDate: Equatable {
    var day: Int
    var month: Int
    var year: Int

    /// UTC, matching `OfficeDataStore`'s own convention -- this is chrome/navigation
    /// state, not something that should drift with the device's timezone mid-scroll.
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func today() -> SimpleDate {
        let components = utcCalendar.dateComponents([.day, .month, .year], from: Date())
        return SimpleDate(day: components.day ?? 1, month: components.month ?? 1, year: components.year ?? 2000)
    }

    var asDate: Date {
        Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    init(day: Int, month: Int, year: Int) {
        self.day = day
        self.month = month
        self.year = year
    }

    init(_ date: Date) {
        let components = Self.utcCalendar.dateComponents([.day, .month, .year], from: date)
        day = components.day ?? 1
        month = components.month ?? 1
        year = components.year ?? 2000
    }

    /// Convenience for `Computus.addDays`'s own return shape.
    init(_ tuple: (day: Int, month: Int, year: Int)) {
        day = tuple.day
        month = tuple.month
        year = tuple.year
    }
}
