import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 4: the colour dot of the *Jump to date* calendar, one date for every colour and
// for each of the calendar's two changes to DO's colour (Our Lady's feasts white, Gaudete
// and Laetare rose).

private func calendarColor(_ day: Int, _ month: Int, _ year: Int) -> CalendarColor? {
    guard let bundle = RealCorpus.bundle else { return nil }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "Laudes", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    return LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: calendar).calendarColor(day: day, month: month, year: year)
}

@Test(arguments: [
    (16, 9, 2026, CalendarColor.red),        // Ss. Cornelius and Cyprian, Martyrs
    (5, 4, 2026, .white),                    // Easter Sunday
    (24, 5, 2026, .red),                     // Pentecost
    (21, 6, 2026, .green),                   // a Sunday after Pentecost
    (18, 2, 2026, .violet),                  // Ash Wednesday
    (3, 4, 2026, .black),                    // Good Friday
    (2, 11, 2026, .black),                   // All Souls
    (8, 12, 2026, .white),                   // the Immaculate Conception (DO's blue)
    (15, 8, 2026, .white),                   // the Assumption (DO's blue)
    (13, 12, 2026, .rose),                   // Gaudete Sunday
    (15, 3, 2026, .rose),                    // Laetare Sunday
    (6, 12, 2026, .violet),                  // the 2nd Sunday of Advent
    (1, 11, 2026, .white),                   // All Saints
    (29, 6, 2026, .red),                     // Ss. Peter and Paul
])
func calendarColorOfTheDay(_ day: Int, _ month: Int, _ year: Int, _ expected: CalendarColor) {
    guard RealCorpus.bundle != nil else { return }
    #expect(calendarColor(day, month, year) == expected, "\(year)-\(month)-\(day)")
}
