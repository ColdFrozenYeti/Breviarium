import Testing
@testable import BreviariumKit

@Test func formatsTheReferenceExampleDate() {
    #expect(LatinDateLine.format(day: 16, month: 9, year: 2026) == "Dies 16 septembris 2026")
}

@Test func formatsEveryMonthGenitiveCorrectly() {
    #expect(LatinDateLine.format(day: 1, month: 1, year: 2026) == "Dies 1 ianuarii 2026")
    #expect(LatinDateLine.format(day: 1, month: 2, year: 2026) == "Dies 1 februarii 2026")
    #expect(LatinDateLine.format(day: 1, month: 3, year: 2026) == "Dies 1 martii 2026")
    #expect(LatinDateLine.format(day: 1, month: 4, year: 2026) == "Dies 1 aprilis 2026")
    #expect(LatinDateLine.format(day: 1, month: 5, year: 2026) == "Dies 1 maii 2026")
    #expect(LatinDateLine.format(day: 1, month: 6, year: 2026) == "Dies 1 iunii 2026")
    #expect(LatinDateLine.format(day: 1, month: 7, year: 2026) == "Dies 1 iulii 2026")
    #expect(LatinDateLine.format(day: 1, month: 8, year: 2026) == "Dies 1 augusti 2026")
    #expect(LatinDateLine.format(day: 1, month: 10, year: 2026) == "Dies 1 octobris 2026")
    #expect(LatinDateLine.format(day: 1, month: 11, year: 2026) == "Dies 1 novembris 2026")
    #expect(LatinDateLine.format(day: 1, month: 12, year: 2026) == "Dies 1 decembris 2026")
}
