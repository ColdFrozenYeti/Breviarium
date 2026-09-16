import Testing
@testable import BreviariumKit

@Test func christmasAndNewYear() {
    #expect(TemporalCycle.weekName(day: 25, month: 12, year: 2026) == "Nat25")
    #expect(TemporalCycle.weekName(day: 31, month: 12, year: 2026) == "Nat31")
    #expect(TemporalCycle.weekName(day: 1, month: 1, year: 2026) == "Nat01")
}

@Test func firstSundayOfAdvent() {
    for year in 2025...2040 {
        let advent1 = Computus.firstSundayOfAdvent(year: year)
        let (day, month) = Computus.date(dayOfYear: advent1, year: year)
        #expect(TemporalCycle.weekName(day: day, month: month, year: year) == "Adv1")
    }
}

@Test func easterSundayItself() {
    for year in 2025...2040 {
        let (day, month) = Computus.easter(year: year)
        #expect(TemporalCycle.weekName(day: day, month: month, year: year) == "Pasc0")
    }
}

@Test func holyWeekAndTriduum() {
    // Ports of horascommon.pl's own named checks: Quad6-4 (Maundy Thursday), Quad6-5
    // (Good Friday), Quad6-6 (Holy Saturday) -- all "Quad6", verified here against
    // Easter offsets rather than the day-of-week suffix (which is a different layer).
    for year in [2025, 2026, 2027, 2035, 2038] {
        let easter = Computus.easter(year: year)
        let easterOrdinal = Computus.dayOfYear(day: easter.day, month: easter.month, year: year)

        for offset in [-1, -2, -3] {    // Holy Saturday, Good Friday, Maundy Thursday.
            let (day, month) = Computus.date(dayOfYear: easterOrdinal + offset, year: year)
            #expect(TemporalCycle.weekName(day: day, month: month, year: year) == "Quad6")
        }
    }
}

@Test func ashWednesday() {
    // horascommon.pl:891-892 identifies Ash Wednesday as "$dayname[0] =~ /Quadp3/ &&
    // $dayofweek == 3" -- Quinquagesima week, Wednesday. Ash Wednesday is 46 days
    // before Easter by the traditional reckoning.
    for year in 2025...2040 {
        let easter = Computus.easter(year: year)
        let easterOrdinal = Computus.dayOfYear(day: easter.day, month: easter.month, year: year)
        let (day, month) = Computus.date(dayOfYear: easterOrdinal - 46, year: year)

        #expect(TemporalCycle.weekName(day: day, month: month, year: year) == "Quadp3")
        #expect(Computus.dayOfWeek(day: day, month: month, year: year) == 3)
    }
}

@Test func preLentenSundays() {
    // Septuagesima (-63), Sexagesima (-56), Quinquagesima (-49) Sundays.
    for year in 2025...2040 {
        let easter = Computus.easter(year: year)
        let easterOrdinal = Computus.dayOfYear(day: easter.day, month: easter.month, year: year)

        let septuagesima = Computus.date(dayOfYear: easterOrdinal - 63, year: year)
        let sexagesima = Computus.date(dayOfYear: easterOrdinal - 56, year: year)
        let quinquagesima = Computus.date(dayOfYear: easterOrdinal - 49, year: year)

        #expect(TemporalCycle.weekName(day: septuagesima.day, month: septuagesima.month, year: year) == "Quadp1")
        #expect(TemporalCycle.weekName(day: sexagesima.day, month: sexagesima.month, year: year) == "Quadp2")
        #expect(TemporalCycle.weekName(day: quinquagesima.day, month: quinquagesima.month, year: year) == "Quadp3")
    }
}

@Test func pentecostSundayAndItsVigil() {
    // Pentecost is Easter+49; its vigil, the Saturday before, is the last day of the
    // "Pasc6" week (matching horascommon.pl's "Pasc6-6 - I. classis - Vigilia
    // Pentecostes" and "Pasc7" starting fresh on Pentecost Sunday itself).
    for year in 2025...2040 {
        let easter = Computus.easter(year: year)
        let easterOrdinal = Computus.dayOfYear(day: easter.day, month: easter.month, year: year)

        let pentecost = Computus.date(dayOfYear: easterOrdinal + 49, year: year)
        let vigil = Computus.date(dayOfYear: easterOrdinal + 48, year: year)

        #expect(TemporalCycle.weekName(day: pentecost.day, month: pentecost.month, year: year) == "Pasc7")
        #expect(TemporalCycle.weekName(day: vigil.day, month: vigil.month, year: year) == "Pasc6")
        #expect(Computus.dayOfWeek(day: vigil.day, month: vigil.month, year: year) == 6)
    }
}

@Test func tomorrowFlagShiftsByOneDay() {
    #expect(TemporalCycle.weekName(day: 24, month: 12, year: 2026, tomorrow: true) == "Nat25")
    // "Nat32" is a faithful port, not a claim it's meaningful: Date.pm's own $tDay is
    // just $day + 1 with no month-length awareness, so Dec 31 + tomorrow literally
    // produces day 32. Locking this in rather than "fixing" it, since matching DO's
    // real behaviour (however sharp-edged) is the point -- M4's oracle diffing is what
    // gets to say whether this ever actually matters in practice.
    #expect(TemporalCycle.weekName(day: 31, month: 12, year: 2026, tomorrow: true) == "Nat32")
}
