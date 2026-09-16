import Foundation

/// Names the liturgical season/week a date falls in — DO's own `dayname` scheme, e.g.
/// `"Adv1"` (first week of Advent), `"Quad3"` (third week of Lent), `"Pasc0"` (Easter
/// week itself), `"Pent15"` (fifteenth week after Pentecost). Ports `getweek()`
/// (`Date.pm:20-79`).
///
/// This is only the season/week label. The caller appends `"-<day-of-week>"` to get a
/// full temporal file reference (e.g. `"Adv1-0"` for Advent 1 Sunday) — except for `Nat`
/// weeks, which are numbered by day-of-month directly and never get that suffix. That
/// assembly lives in `LiturgicalDay`/`Occurrence`, matching how `horascommon.pl`'s
/// `occurrence()` builds `$tday` from `getweek()`'s result rather than `getweek()` doing
/// it itself.
public enum TemporalCycle {

    /// `tomorrow`: computes the name for the day *after* `day`/`month`/`year`, matching
    /// `Date.pm`'s own `$tomorrow` flag (used when resolving second Vespers' concurrence
    /// with tomorrow's first Vespers — see `docs/rubrics-1960-vespers.md` §3).
    /// `missa`: only affects the wrapped-around-Pentecost naming right at the end of the
    /// liturgical year; always `false` for this project (Breviarium never renders Mass).
    public static func weekName(day: Int, month: Int, year: Int, tomorrow: Bool = false, missa: Bool = false) -> String {
        var t = Computus.dayOfYear(day: day, month: month, year: year)
        if tomorrow { t += 1 }

        let advent1 = Computus.firstSundayOfAdvent(year: year)
        let christmas = Computus.dayOfYear(day: 25, month: 12, year: year)
        let tDay = tomorrow ? day + 1 : day

        if t >= advent1 {
            if t < christmas {
                let n = 1 + (t - advent1) / 7
                return "Adv\(n)"
            }
            return "Nat\(tDay)"
        }

        let epiphanyWeekday = Computus.dayOfWeek(day: 6, month: 1, year: year)
        let ordtime = 6 + 7 - epiphanyWeekday    // Day-of-year of the Sunday on/after Epiphany.

        if month == 1 && t < ordtime {
            return String(format: "Nat%02d", tDay)
        }

        let easterDate = Computus.easter(year: year)
        let easter = Computus.dayOfYear(day: easterDate.day, month: easterDate.month, year: year)

        if t < easter - 63 {
            let n = (t - ordtime) / 7 + 1
            return "Epi\(n)"
        }
        if t < easter - 56 { return "Quadp1" }    // Septuagesima week.
        if t < easter - 49 { return "Quadp2" }    // Sexagesima week.
        if t < easter - 42 { return "Quadp3" }    // Quinquagesima week.

        if t < easter {
            let n = 1 + (t - (easter - 42)) / 7
            return "Quad\(n)"    // Lent, weeks 1-6 (week 6 is Holy Week).
        }

        if t < easter + 56 {
            let n = (t - easter) / 7
            return "Pasc\(n)"    // Paschaltide, week 0 (Easter week) through week 7.
        }

        let n = (t - (easter + 49)) / 7
        if n < 23 { return String(format: "Pent%02d", n) }

        // Near the end of the liturgical year: fold the remaining weeks back onto
        // resumed Epiphany-numbered propers where the 1960 rubrics call for it --
        // CLAUDE.md's "Sundays after Epiphany resumed after Pentecost" named edge case.
        let weeksUntilAdvent = (advent1 - t + 6) / 7
        if weeksUntilAdvent < 2 { return "Pent24" }
        if n == 23 { return "Pent23" }
        return missa ? "PentEpi\(8 - weeksUntilAdvent)" : "Epi\(8 - weeksUntilAdvent)"
    }
}
