import Testing
@testable import BreviariumKit

@Test func easterKnownDates() {
    // Well-documented anchor dates for verifying a computus implementation.
    #expect(Computus.easter(year: 1900) == (15, 4))    // 15 April 1900
    #expect(Computus.easter(year: 2000) == (23, 4))    // 23 April 2000
    #expect(Computus.easter(year: 2024) == (31, 3))    // 31 March 2024
    #expect(Computus.easter(year: 2025) == (20, 4))    // 20 April 2025
    // The latest possible Gregorian Easter (25 April), a famous computus edge case,
    // also named in CLAUDE.md's testing section as "the latest Easter (2038)".
    #expect(Computus.easter(year: 2038) == (25, 4))
}

@Test func easterIsAlwaysWithinItsCanonicalRange() {
    // Easter always falls between 22 March and 25 April inclusive.
    for year in 2000...2100 {
        let (day, month) = Computus.easter(year: year)
        let dayOfYear = Computus.dayOfYear(day: day, month: month, year: year)
        let earliestPossible = Computus.dayOfYear(day: 22, month: 3, year: year)
        let latestPossible = Computus.dayOfYear(day: 25, month: 4, year: year)
        #expect(dayOfYear >= earliestPossible)
        #expect(dayOfYear <= latestPossible)
    }
}

@Test func easterIsAlwaysASunday() {
    for year in 2000...2100 {
        let (day, month) = Computus.easter(year: year)
        #expect(Computus.dayOfWeek(day: day, month: month, year: year) == 0)
    }
}

@Test func leapYearRule() {
    #expect(Computus.isLeapYear(2000))     // divisible by 400
    #expect(!Computus.isLeapYear(1900))    // divisible by 100, not 400
    #expect(Computus.isLeapYear(2024))
    #expect(!Computus.isLeapYear(2023))
    #expect(Computus.isLeapYear(2028))
}

@Test func dayOfWeekKnownDates() {
    // 16 September 2026, CLAUDE.md's own worked example date, was a Wednesday.
    #expect(Computus.dayOfWeek(day: 16, month: 9, year: 2026) == 3)    // 0=Sun...3=Wed
    // 1 January 2000 was a Saturday.
    #expect(Computus.dayOfWeek(day: 1, month: 1, year: 2000) == 6)
}

@Test func dayOfYearRoundTrips() {
    for (day, month, year) in [(1, 1, 2025), (31, 12, 2025), (29, 2, 2024), (1, 3, 2025)] {
        let ordinal = Computus.dayOfYear(day: day, month: month, year: year)
        let roundTripped = Computus.date(dayOfYear: ordinal, year: year)
        #expect(roundTripped == (day, month))
    }
}

@Test func dayOfYearAccountsForLeapDay() {
    // Without accounting for the leap day, 1 March would be day 60 in every year;
    // in a leap year it must be day 61.
    #expect(Computus.dayOfYear(day: 1, month: 3, year: 2024) == 61)    // leap year
    #expect(Computus.dayOfYear(day: 1, month: 3, year: 2025) == 60)    // non-leap year
}

@Test func firstSundayOfAdventIsAlwaysBetweenNov27AndDec3() {
    for year in 2000...2100 {
        let advent1 = Computus.firstSundayOfAdvent(year: year)
        let (day, month) = Computus.date(dayOfYear: advent1, year: year)
        #expect(month == 11 || month == 12)
        if month == 11 { #expect(day >= 27) }
        if month == 12 { #expect(day <= 3) }
        #expect(Computus.dayOfWeek(day: day, month: month, year: year) == 0)
    }
}

@Test func addDaysHandlesYearBoundaries() {
    #expect(Computus.addDays(1, day: 31, month: 12, year: 2025) == (1, 1, 2026))
    #expect(Computus.addDays(-1, day: 1, month: 1, year: 2026) == (31, 12, 2025))
    #expect(Computus.addDays(1, day: 28, month: 2, year: 2024) == (29, 2, 2024))    // leap day
    #expect(Computus.addDays(1, day: 28, month: 2, year: 2025) == (1, 3, 2025))     // no leap day
    #expect(Computus.addDays(0, day: 15, month: 6, year: 2025) == (15, 6, 2025))
}
