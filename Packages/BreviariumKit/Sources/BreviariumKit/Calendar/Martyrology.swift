import Foundation

/// The Roman Martyrology (Beta 4), a separate "hour" in the picker (decided 2026-09-24).
/// Ports DO's `martyrologium` (`specials/specprima.pl:137-200`), which it reads at Prime:
/// the entry is the **next day's** (it is read on the eve, decided 2026-09-26), from
/// `Martyrologium1960/MM-DD.txt`, announced with that day's date in the Roman calendar,
/// the moon's age and the year, then its movable entry (`Mobile.txt`), the day's entries,
/// and the conclusion (`Conclmart`). Latin only (decision 3).
public struct MartyrologyAssembler {
    public let corpus: OfficeCorpus
    public let context: ConditionalContext
    public let calendar: SanctoralCalendar

    public init(corpus: OfficeCorpus, context: ConditionalContext, calendar: SanctoralCalendar) {
        self.corpus = corpus
        self.context = context
        self.calendar = calendar
    }

    static let folder = "Martyrologium1960"

    /// The Martyrology read on `day`/`month`/`year`: one `.martyrologium` section. On the
    /// three days of the Triduum, whose rule omits it, DO shows *Martyrologium{omittitur}*;
    /// the section then holds that rubric alone.
    public func assemble(day: Int, month: Int, year: Int) -> Hour? {
        let resolver = SectionResolver(corpus: corpus, context: context)
        guard let office = Occurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: day, month: month, year: year)
        else { return nil }
        if Self.isOmitted(office: office.winningPath, resolver: resolver) {
            return Hour(sections: [Section(kind: .martyrologium, units: [.rubric("Martyrologium omittitur.", english: nil)])])
        }

        // `nextday` (`Date.pm:161-173`): tomorrow's `get_sday` key, so 24 February of a
        // leap year reads `02-29`.
        let tomorrow = Computus.addDays(1, day: day, month: month, year: year)
        let key = Computus.sanctoralKey(day: tomorrow.day, month: tomorrow.month, year: tomorrow.year)
        let path = "\(Self.folder)/\(key)"
        guard resolver.sectionExists(path: path, section: RawSectionParser.wholeFileSectionName) else { return nil }
        var lines = resolver.resolve(path: path, section: RawSectionParser.wholeFileSectionName)
            .split(separator: "\n", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        while lines.last?.isEmpty == true { lines.removeLast() }
        guard !lines.isEmpty else { return nil }

        // `_luna` is called with the key's month and day, and the year of tomorrow.
        let parts = key.split(separator: "-").compactMap { Int($0) }
        let lunaYear = parts == [1, 1] ? year + 1 : year
        lines[0] += " " + Self.luna(month: parts[0], day: parts[1], year: lunaYear)

        // The first `_` takes the movable entry; the other `_` lines go.
        let mobile = mobileEntry(day: day, month: month, year: year, office: office, resolver: resolver)
        var usedMobile = false
        var units: [Unit] = []
        for line in lines where !line.isEmpty {
            if line == "_" {
                if !usedMobile, let mobile {
                    units.append(.prose(mobile.replacingOccurrences(
                        of: #"/:\s*(.*?)\s*:/"#, with: String(InlineRubrics.start) + "$1" + String(InlineRubrics.end), options: .regularExpression
                    ), english: nil))
                }
                usedMobile = true
            } else if line.hasPrefix("/:") {
                let text = line.replacingOccurrences(of: #"^/:\s*|\s*:/$"#, with: "", options: .regularExpression)
                units.append(.rubric(text, english: nil))
            } else {
                // An inline direction (Christmas: *Hic vox elevatur, et omnes genua
                // flectunt*) is a red rubric inside the text (decision 5).
                let marked = line.replacingOccurrences(
                    of: #"/:\s*(.*?)\s*:/"#, with: String(InlineRubrics.start) + "$1" + String(InlineRubrics.end), options: .regularExpression
                )
                units.append(.prose(marked, english: nil))
            }
        }

        // `Conclmart`: "Et álibi aliórum plurimórum …" and *Deo grátias*.
        let conclusion = resolver.resolve(path: SectionResolver.prayersPath, section: "Conclmart")
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let versicle = conclusion.first { $0.hasPrefix("V.") }.map(DOMarkers.stripLineLabel)
        let response = conclusion.first { $0.hasPrefix("R.") }.map(DOMarkers.stripLineLabel)
        if let versicle, let response {
            units.append(.versicleResponse(versicle: versicle, response: response))
        }
        return Hour(sections: [Section(kind: .martyrologium, units: units)])
    }

    /// `specials.pl:83-96`: the office's rule omits it ("Omit … Martyrologium", the
    /// Triduum's).
    static func isOmitted(office: String, resolver: SectionResolver) -> Bool {
        guard resolver.sectionExists(path: office, section: "Rule") else { return false }
        return resolver.resolve(path: office, section: "Rule")
            .range(of: #"Omit.*? Martyrologium"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// `specprima.pl:152-159`: the entry for a movable feast, keyed by tomorrow's week and
    /// today's weekday plus one; Christ the King on the last Saturday of October; the
    /// Commemoration of All Souls when the day's office is theirs.
    func mobileEntry(day: Int, month: Int, year: Int, office: OccurrenceResult, resolver: SectionResolver) -> String? {
        let dayOfWeek = Computus.dayOfWeek(day: day, month: month, year: year)
        var key = TemporalCycle.weekName(day: day, month: month, year: year, tomorrow: true) + "-\((dayOfWeek + 1) % 7)"
        if month == 10, dayOfWeek == 6, day > 23, day < 31 { key = "10-DU" }
        let commune = office.winningRank.communeReference.lowercased()
        if commune.hasPrefix("ex"), commune.contains("c9") { key = "Defuncti" }
        let path = "\(Self.folder)/Mobile"
        guard resolver.sectionExists(path: path, section: key) else { return nil }
        let text = resolver.resolve(path: path, section: key).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    // MARK: - The moon's age (`specprima.pl:202-300`)

    private static let ordinals = [
        "prima", "secúnda", "tértia", "quarta", "quinta", "sexta", "séptima", "octáva", "nona", "décima", "undécima",
        "duodécima", "tértia décima", "quarta décima", "quinta décima", "sexta décima", "décima séptima",
        "duodevicésima", "undevicésima", "vicésima", "vicésima prima", "vicésima secúnda", "vicésima tértia",
        "vicésima quarta", "vicésima quinta", "vicésima sexta", "vicésima séptima", "vicésima octáva",
        "vicésima nona", "tricésima",
    ]

    /// `_luna` in Latin: "Luna quinta. Anno Dómini 2026".
    static func luna(month: Int, day: Int, year: Int) -> String {
        "Luna \(ordinals[lunaDay(month: month, day: day, year: year) - 1]). Anno Dómini \(year)"
    }

    /// `_luna_table`: the moon's age for a day of the year and the year's Martyrology
    /// letter, as the tables printed in the Martyrology give it.
    static func lunaTable(yday: Int, letter: Character) -> Int {
        let letters = Array("abcdefghiklmnpqrstuABCDERFGHMNP")
        let position = (letters.firstIndex(of: letter) ?? -1) + 1
        let afterFirst = (yday - 35) % 59
        let length = yday < 36 ? 30 : ((afterFirst == 0 ? 59 : afterFirst) < 29 ? 29 : 30)
        var i = yday % 59 < 36 ? position : position - 1
        if yday % 59 < 36 {
            if position > 25 { i -= 1 }
            if position == 25, yday % 59 == 35 { i += 1 }
        } else if position > 25 {
            i -= 2
        }
        if yday > 58 {
            if position > 25, yday % 59 < 5 { i -= 1 }
            if position == 26, yday % 59 == 5 { i -= 1 }
        }
        return (i - 1 + yday % 59) % length + 1
    }

    /// `_luna_day`: the golden number's letter (1900-2199), then the table. `month`/`day`
    /// are a `get_sday` key's, so 24 February of a leap year comes as the 29th.
    static func lunaDay(month: Int, day: Int, year: Int) -> Int {
        let lettersForGoldenNumber = Array("NkBbnEerHhuPlCcpRfs")
        let goldenNumber = year % 19 + 1
        let letter = lettersForGoldenNumber[goldenNumber - 1]
        let leap = Computus.isLeapYear(year)
        let monthStarts = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        var yday = monthStarts[month - 1] + day + (month > 2 && leap ? 1 : 0)
        if leap, month > 2 || (month == 2 && day > 23) { yday -= 1 }
        var luna = lunaTable(yday: yday, letter: letter)
        if goldenNumber == 1, month == 1, letter != "P", day + lunaTable(yday: 1, letter: letter) < 32 { luna -= 1 }
        return luna
    }
}
