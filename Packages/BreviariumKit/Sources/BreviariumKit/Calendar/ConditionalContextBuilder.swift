import Foundation

extension TemporalCycle {
    /// Ports `get_tempus_id()` (`SetupString.pl:164-216`) — the coarse liturgical season
    /// name DO's own `(tempore ...)` conditionals test against (e.g. `"Adventus"`,
    /// `"post Pentecosten"`), distinct from `weekName` itself (`"Adv3"`). Tests `weekName`
    /// directly, exactly as DO tests `$dayname[0]` (no winning-office lookup involved).
    ///
    /// **Not ported**: DO's `$oct_or_nov` guard on the final `post Pentecosten` branch,
    /// which comes from `monthday()` (`SetupString.pl:748`), a separate liturgical-year
    /// ordinal encoding this project doesn't otherwise need. It only ever distinguishes
    /// "post Pentecosten" from "post Pentecosten in hieme" in the last two Pentecost
    /// weeks of the year, and DO's own comment marks the "in hieme"/"post partum"/etc.
    /// augmentations as being for **GABC chant-score selection**, not text conditionals —
    /// so `oct_or_nov` is always treated as `false` here (the common case) until a real
    /// oracle fixture shows a text difference that depends on it.
    public static func tempusID(weekName: String, rubrica: String, month: Int, day: Int, dayOfWeek: Int, isVespersOrCompline: Bool) -> String {
        let w = weekName
        let vespOrComp = isVespersOrCompline

        func digitsAfter(_ prefix: String) -> Int? {
            guard w.hasPrefix(prefix) else { return nil }
            let rest = w.dropFirst(prefix.count)
            return Int(rest.prefix { $0.isNumber })
        }

        if w.hasPrefix("Adv") { return "Adventus" }

        if w.hasPrefix("Nat") {
            return (month == 1 && (day >= 6 || (day == 5 && vespOrComp))) ? "Epiphaniæ" : "Nativitatis"
        }

        if w.hasPrefix("Epi") {
            if month == 1 && day <= 13 { return "Epiphaniæ" }
            if month == 1 || (month == 2 && (day == 1 || (day == 2 && !vespOrComp))) { return "post Epiphaniam post partum" }
            if month == 2 { return "post Epiphaniam" }
            return "post Pentecosten in hieme"
        }

        if let n = digitsAfter("Quadp"), n < 3 || dayOfWeek < 3 {
            if month == 1 || (month == 2 && (day == 1 || (day == 2 && !vespOrComp))) { return "Septuagesimæ post partum" }
            return "Septuagesimæ"
        }
        if let n = digitsAfter("Quad") {
            return n < 5 ? "Quadragesimæ" : "Passionis"
        }
        if w.hasPrefix("Quad") { return "Passionis" }

        if w.hasPrefix("Pasc0") {
            return (vespOrComp && dayOfWeek == 6) ? "Vigilia Paschalis" : "Octava Paschæ"
        }
        if let n = digitsAfter("Pasc") {
            if n < 5 || (n == 5 && (dayOfWeek < 3 || (!vespOrComp && dayOfWeek == 3))) { return "post Octavam Paschæ" }
            // DO tests this against $dayname[0], which (unlike the bare `weekName` this
            // function otherwise takes) already carries the "-<day-of-week>" suffix --
            // reconstruct it just for this one suffix-sensitive check.
            if n == 6, dayOfWeek == 5 || dayOfWeek == 6 { return "post Octavam Ascensionis" }
            if n < 7 { return "Octava Ascensionis" }
            return "Octava Pentecostes"
        }

        if w.hasPrefix("Pent01") && dayOfWeek == 4 { return "Corpus Christi post Pentecosten" }
        let isPreOrPostVaticanII = rubrica.range(of: "19(?:55|6)", options: .regularExpression) != nil
        if let n = digitsAfter("Pent0"),
           ((n == 1 && dayOfWeek > 4 && !(dayOfWeek == 6 && vespOrComp))
            || (n == 2 && (dayOfWeek < 5 || (dayOfWeek == 6 && vespOrComp)))),
           !isPreOrPostVaticanII {
            return "Octava Corpus Christi post Pentecosten"
        }
        if w.hasPrefix("Pent02") && dayOfWeek == 5 && !rubrica.contains("1570") {
            return "SSmi Cordis post Pentecosten"
        }
        if let n = digitsAfter("Pent0"),
           ((n == 2 && dayOfWeek > 5 && !(dayOfWeek == 6 && vespOrComp))
            || (n == 3 && (dayOfWeek < 6 || (dayOfWeek == 6 && vespOrComp)))),
           rubrica.range(of: "Divino", options: .caseInsensitive) != nil {
            return "Octava SSmi Cordis post Pentecosten"
        }
        if w.hasPrefix("Pent") { return "post Pentecosten" }    // oct_or_nov always treated as false -- see doc comment.

        return "post Pentecosten in hieme"
    }
}

/// Builds the `ConditionalContext` DivinumOfficium would use to render a given hour on a
/// given date, mirroring its own two-pass design: `[Rank]`/`[Rule]` lookups (used to
/// decide which office wins occurrence) only ever test `rubrica`
/// (`SetupString.pl`'s `%subjects`, confirmed by reading every `(sed rubrica ...)`
/// clause this project's fixtures exercise), so `Occurrence` can run with a placeholder
/// for every other field; `tempore`/`die` are then computed from the winning office and
/// the date, exactly as DO computes them *after* `occurrence()` runs, never before.
public enum ConditionalContextBuilder {

    /// - Parameters:
    ///   - ad: the hour name, lowercase (e.g. `"vesperas"`), used both as the context's
    ///     own `ad` field and to decide DO's `$vesp_or_comp` flag.
    ///   - rubrica: the rubrics version string, e.g. `"Rubrics 1960 - 1960"`.
    public static func build(
        day: Int, month: Int, year: Int,
        ad: String,
        rubrica: String,
        corpus: OfficeCorpus,
        sanctoralCalendar: SanctoralCalendar
    ) -> ConditionalContext {
        let dayOfWeek = Computus.dayOfWeek(day: day, month: month, year: year)
        let weekName = TemporalCycle.weekName(day: day, month: month, year: year)
        let isVespersOrCompline = ad.range(of: "vesper", options: .caseInsensitive) != nil
            || ad.range(of: "complet", options: .caseInsensitive) != nil

        // Bootstrap context: only `rubrica` is needed to resolve [Rank]/[Rule], so every
        // other field can be a placeholder for this first pass.
        let bootstrapContext = ConditionalContext(rubrica: rubrica, tempore: "", feria: dayOfWeek + 1, ad: ad, mense: month)
        let occurrenceEngine = Occurrence(corpus: corpus, context: bootstrapContext, calendar: sanctoralCalendar)
        let occurrence = occurrenceEngine.resolve(day: day, month: month, year: year)

        let resolver = SectionResolver(corpus: corpus, context: bootstrapContext)
        var officeTitle = ""
        var rule = ""
        var winningKey = ""
        if let occurrence {
            officeTitle = resolver.resolve(path: occurrence.winningPath, section: "Officium")
            rule = resolver.resolve(path: occurrence.winningPath, section: "Rule")
            winningKey = String(occurrence.winningPath.split(separator: "/").last ?? "")
        }
        let temporalKey = String(Occurrence.temporalPath(day: day, month: month, year: year).split(separator: "/").last ?? "")

        let tempore = TemporalCycle.tempusID(
            weekName: weekName, rubrica: rubrica, month: month, day: day, dayOfWeek: dayOfWeek, isVespersOrCompline: isVespersOrCompline
        )
        let die = dayName(
            day: day, month: month, year: year, dayOfWeek: dayOfWeek, isVespersOrCompline: isVespersOrCompline,
            winningKey: winningKey, temporalKey: temporalKey, officeTitle: officeTitle, rule: rule
        )

        return ConditionalContext(
            rubrica: rubrica,
            tempore: tempore,
            die: die,
            feria: dayOfWeek + 1,
            // `commune`/`votiva` need commemoration/votive-office assembly this project
            // hasn't built yet (Occurrence's own doc comment already flags commemoration
            // as out of scope) -- left empty rather than guessed. Flagged, not silent:
            // no oracle fixture exercised this session has needed either field so far.
            commune: "",
            votiva: "",
            officio: officeTitle,
            ad: ad,
            mense: month
        )
    }

    /// Ports `get_dayname_for_condition()` (`SetupString.pl:219-252`) for the branches
    /// this project can actually evaluate. `winningKey`/`temporalKey` are the winning/
    /// temporal file's bare name (e.g. `"Quad6-4"`, `"10-DU"`), matching DO's own
    /// `$winner`/`$dayname[0]`.
    ///
    /// Three of DO's own branches (`'in Cœna Domini'`, `'in Parasceve'`, `'Sabbato
    /// Sancto'`, and the duplicate `'post Epi1-0'`) are dead code in the real Perl --
    /// each is already caught by an earlier, broader branch in the same `if`/`elsif`
    /// chain (`'Tridui Sacri'` matches all of `Quad6-[456]`; `'post Dominicam infra
    /// Octavam Epiphaniæ'` matches the same `Epi1-[1-6]` regex) -- so they're skipped
    /// here too, matching real behaviour rather than the unreachable source lines.
    ///
    /// **Not ported**: `'regis DNJC'`'s `$commemoratio` half (no commemoration data
    /// yet -- same gap as `commune`/`votiva` above) and `'doctorum'`'s exact `$dayname[1]`/
    /// `$dayname[2]` split (approximated here as "the winning office's title contains
    /// 'Doctor'", which is the same substring DO's own regex tests for, just against a
    /// less precisely-scoped string).
    private static func dayName(
        day: Int, month: Int, year: Int, dayOfWeek: Int, isVespersOrCompline: Bool,
        winningKey: String, temporalKey: String, officeTitle: String, rule: String
    ) -> String {
        if month == 1 && (day == 6 || (day == 5 && isVespersOrCompline)) { return "Epiphaniæ" }
        if month == 1 && (day == 13 || (day == 12 && isVespersOrCompline)) { return "Baptismatis Domini" }
        if winningKey.range(of: #"Quad6-[456]"#, options: .regularExpression) != nil { return "Tridui Sacri" }
        if winningKey.range(of: "Pasc0-0", options: .regularExpression) != nil && isVespersOrCompline && dayOfWeek == 6 {
            return "Vigilia Paschalis"
        }
        if winningKey.contains("10-DU") { return "regis DNJC" }
        if month == 11 {
            let nov1Weekday = Computus.dayOfWeek(day: 1, month: 11, year: year)
            if day == 2 || (day == 3 && dayOfWeek == 1) || (day == 1 && nov1Weekday != 6 && isVespersOrCompline) {
                return "Omnium Defunctorum"
            }
            if day == 3 { return "Malachiae" }
            if day == 4 { return "Caroli" }
        }
        if month == 12 {
            if day == 6 { return "Nicolai" }
            if day == 28 { return "Nat28" }
            if day == 29 { return "Nat29" }
        }
        if officeTitle.range(of: "Doctor", options: .caseInsensitive) != nil { return "doctorum" }
        if month == 8 && (day == 6 || (day == 5 && isVespersOrCompline)) { return "transfigurationis" }
        if winningKey.range(of: #"09-15$|09-DT|Quad5-5$"#, options: .regularExpression) != nil { return "septem doloris" }
        if winningKey.contains("12-25") { return "Nativitatis" }
        if temporalKey.range(of: #"Epi1-[1-6]"#, options: .regularExpression) != nil { return "post Dominicam infra Octavam Epiphaniæ" }
        if winningKey.range(of: #"08-20|00-VB"#, options: .regularExpression) != nil { return "Bernardi" }
        if rule.range(of: "3 lectio", options: .caseInsensitive) != nil { return "3 lectionum" }
        return ""
    }
}
