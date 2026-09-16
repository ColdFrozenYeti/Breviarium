import Foundation

/// Date arithmetic ported from Divinum Officium's `Date.pm`: Easter (the "computus"),
/// leap years, day-of-week, and day-of-year conversions. Everything else in `Calendar/`
/// (temporal cycle naming, sanctoral lookup, precedence) is built on these.
///
/// A plain `(day, month, year)` triple is used throughout rather than `Foundation.Date`,
/// matching `Date.pm` itself and sidestepping any question of which calendar/timezone
/// configuration `Foundation`'s `Calendar` would use — this project only ever needs
/// proleptic-Gregorian civil dates from 1582 onward, exactly what `Date.pm` implements.
public enum Computus {

    /// Easter Sunday for `year`, as `(day, month)`. Ports `geteaster()`
    /// (`Date.pm:94-105`) — DO's own comment attributes this to CPAN's `Date::Easter`;
    /// it's the standard "anonymous Gregorian algorithm".
    public static func easter(year: Int) -> (day: Int, month: Int) {
        let g = year % 19
        let c = year / 100
        let h = (c - c / 4 - (8 * c + 13) / 25 + 19 * g + 15) % 30
        let i = h - (h / 28) * (1 - (h / 28) * (29 / (h + 1)) * ((21 - g) / 11))
        let j = (year + year / 4 + i + 2 - c + c / 4) % 7
        let l = i - j
        let month = 3 + (l + 40) / 44
        let day = l + 28 - 31 * (month / 4)
        return (day, month)
    }

    /// Gregorian leap year rule (`Date.pm:112-121`; valid from 1582 onward, which covers
    /// every date this project ever computes).
    public static func isLeapYear(_ year: Int) -> Bool {
        guard year != 0 else { return false }
        return year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
    }

    /// Cumulative days before each month in a non-leap year (`Date.pm:161`'s `@MONTHSUP`).
    private static let cumulativeDaysBeforeMonth = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

    /// 1-indexed day-of-year, e.g. 1 for Jan 1 (`Date.pm:164-168`, `date_to_ydays`).
    public static func dayOfYear(day: Int, month: Int, year: Int) -> Int {
        cumulativeDaysBeforeMonth[month - 1] + day + (month > 2 && isLeapYear(year) ? 1 : 0)
    }

    /// The inverse of `dayOfYear` (`Date.pm:139-149`, `ydays_to_date`).
    public static func date(dayOfYear: Int, year: Int) -> (day: Int, month: Int) {
        var monthLengths = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        if isLeapYear(year) { monthLengths[2] += 1 }

        var month = 1
        var day = dayOfYear
        while month < 13 && day > monthLengths[month] {
            day -= monthLengths[month]
            month += 1
        }
        return (day, month)
    }

    /// 0 = Sunday ... 6 = Saturday (`Date.pm:124-129`).
    public static func dayOfWeek(day: Int, month: Int, year: Int) -> Int {
        let centuryTerm = (year - 1) / 4 - (year - 1) / 100 + (year - 1) / 400
        return ((year * 365 + centuryTerm - 1 + dayOfYear(day: day, month: month, year: year)) % 7 + 7) % 7
    }

    /// Day-of-year of the first Sunday of Advent (the 4th Sunday before Christmas —
    /// or, if Christmas itself is a Sunday, the Sunday one full week earlier, since
    /// Advent 1 can never coincide with Christmas day). Ports `getadvent()`
    /// (`Date.pm:85-91`).
    public static func firstSundayOfAdvent(year: Int) -> Int {
        let christmas = dayOfYear(day: 25, month: 12, year: year)
        let christmasWeekday = dayOfWeek(day: 25, month: 12, year: year)
        let daysSinceSunday = christmasWeekday == 0 ? 7 : christmasWeekday
        return christmas - daysSinceSunday - 21
    }

    /// Adds `days` (positive or negative) to a calendar date, returning the result.
    /// Not present in `Date.pm` under this name, but built from the same
    /// day-of-year/day-of-week primitives as `prevnext()` (`Date.pm:229-238`) rather
    /// than introducing a separate date-arithmetic path via `Foundation.Calendar`.
    /// The `"MM-DD"` key used to look up a date in the sanctoral calendar
    /// (`Kalendaria`/`Sancti`). Ports `get_sday()` (`Date.pm:193-208`): the leap day is
    /// always kept on 24 February and numbered internally as the 29th, so offices
    /// ordinarily on 24 Feb shift to 25 Feb, 25 Feb's to 26 Feb, and so on through the
    /// end of the month — the traditional Roman calendar's *bissextile* reckoning,
    /// rather than treating 29 Feb as an inserted extra day.
    public static func sanctoralKey(day: Int, month: Int, year: Int) -> String {
        var adjustedDay = day
        if isLeapYear(year) && month == 2 {
            if day == 24 {
                adjustedDay = 29
            } else if day > 24 {
                adjustedDay -= 1
            }
        }
        return String(format: "%02d-%02d", month, adjustedDay)
    }

    public static func addDays(_ days: Int, day: Int, month: Int, year: Int) -> (day: Int, month: Int, year: Int) {
        guard days != 0 else { return (day, month, year) }

        let yearLength = isLeapYear(year) ? 366 : 365
        let target = dayOfYear(day: day, month: month, year: year) + days

        if target > yearLength {
            // dayOfYear(1, 1, year+1) == 1, so the delta must be (target - yearLength - 1)
            // for the recursive call to land back on `target - yearLength` -- day 1 of
            // the next year already accounts for one of the days past this year's end.
            return addDays(target - yearLength - 1, day: 1, month: 1, year: year + 1)
        }
        if target < 1 {
            // Recurse from Dec 31 of the previous year with the (still negative or
            // zero) remaining delta; dayOfYear(Dec 31, previousYear) + target lands
            // back in [1, previousYearLength] for any realistic offset.
            return addDays(target, day: 31, month: 12, year: year - 1)
        }
        let (d, m) = date(dayOfYear: target, year: year)
        return (d, m, year)
    }
}
