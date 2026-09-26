import BreviariumKit
import Foundation

/// Everything one Vespers screen needs to render, bundled together so the view doesn't
/// have to know how it was assembled.
struct VespersContent {
    let hour: Hour
    let day: LiturgicalDay
    /// "Ad Vesperas" -- fixed, since Vespers is the only hour this project renders so far
    /// (`CLAUDE.md`: "The alpha is Roman Vespers only").
    let hourTitle: String
    /// e.g. "Dies 16 septembris 2026" (`LatinDateLine`).
    let dateLine: String
    /// e.g. "16-Sep-26" -- the footer's short date, in chrome (English), not Latin.
    let shortDate: String
}

/// Loads the bundled data file once and assembles a `VespersContent` for a given date.
/// Every liturgical decision (occurrence, precedence, the `tempore`/`die` conditional
/// context, psalm/antiphon selection, English pairing) happens inside `BreviariumKit`
/// calls; this only wires `Bundle`/`Date` plumbing to them, per `CLAUDE.md`'s "no
/// liturgical logic in the app target".
@MainActor
final class OfficeDataStore {
    private let latinCorpus: OfficeCorpus?
    /// The Latin corpus for each psalter (`DataBundle.makeLatinCorpus(psalter:)`).
    private let latinCorpora: [Psalter: OfficeCorpus]
    private let englishCorpus: OfficeCorpus?
    private let sanctoralCalendar: SanctoralCalendar?
    private var colorCache: [Int: [Int: CalendarColor]] = [:]

    /// What happened while loading the bundle, for the fallback UI to show verbatim --
    /// temporary, diagnostic-only scaffolding while the bundling pipeline is still being
    /// shaken out (`docs/PLAN.md`'s M5 status), not a user-facing error design.
    private(set) var loadDiagnostic = "loaded"

    /// Always "Rubrics 1960 - 1960" for now — `CLAUDE.md`'s "Ritus: Romanus / Ambrosianus"
    /// setting and the Ambrosian rite provider both stay unimplemented until a later
    /// milestone.
    private let rubrica = "Rubrics 1960 - 1960"

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Fixed locale/timezone: this is chrome text, not something that should drift
        // with the device's region settings (CLAUDE.md's footer example is "16-Sep-26").
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "dd-MMM-yy"
        return formatter
    }()

    init() {
        guard let url = Bundle.main.url(forResource: "breviarium-data", withExtension: "json") else {
            latinCorpus = nil
            latinCorpora = [:]
            englishCorpus = nil
            sanctoralCalendar = nil
            loadDiagnostic = "resource breviarium-data.json not found in Bundle.main"
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            latinCorpus = nil
            latinCorpora = [:]
            englishCorpus = nil
            sanctoralCalendar = nil
            loadDiagnostic = "could not read data at \(url.path)"
            return
        }
        do {
            let bundle = try JSONDecoder().decode(DataBundle.self, from: data)
            let corpora = Dictionary(uniqueKeysWithValues: Psalter.allCases.map { ($0, bundle.makeLatinCorpus(psalter: $0)) })
            latinCorpora = corpora
            latinCorpus = corpora[.vulgate]
            englishCorpus = bundle.makeEnglishCorpus()
            sanctoralCalendar = bundle.makeSanctoralCalendar()
        } catch {
            latinCorpus = nil
            latinCorpora = [:]
            englishCorpus = nil
            sanctoralCalendar = nil
            loadDiagnostic = "decode failed: \(error)"
        }
    }

    /// Same as `content(for:day:month:year:…)`, for Vespers (kept for existing callers).
    func vespersContent(day: Int, month: Int, year: Int, priest: Bool, psalter: Psalter = .vulgate, english: Bool = false) -> VespersContent? {
        content(for: .vesperae, day: day, month: month, year: year, priest: priest, psalter: psalter, english: english)
    }

    /// One hour of the office for an explicit day/month/year (Beta 2: any day hour).
    /// Explicit integers rather than a `Date`, so a fixed snapshot date can't land on the
    /// wrong day through a timezone (`BreviariumApp`'s `BREVIARIUM_SNAPSHOT_DATE`). `nil`
    /// when the bundled data failed to load, or the date can't be resolved to an office.
    func content(
        for canonicalHour: CanonicalHour, day: Int, month: Int, year: Int, priest: Bool, psalter: Psalter = .vulgate, english: Bool = false,
        officium: Officium = .diei
    ) -> VespersContent? {
        guard let latinCorpus = latinCorpora[psalter] ?? latinCorpus, let englishCorpus, let sanctoralCalendar else { return nil }

        // DO evaluates `(sed ad …)` conditionals against the hour (`$hora`).
        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year,
            ad: canonicalHour.doName, rubrica: rubrica,
            corpus: latinCorpus, sanctoralCalendar: sanctoralCalendar
        )
        // English is assembled only when it's shown: the English lookups roughly double
        // the assembly's work.
        let assembler = HourAssembler(
            corpus: latinCorpus, context: context, calendar: sanctoralCalendar, englishCorpus: english ? englishCorpus : nil
        )
        guard let hour = assembler.assemble(canonicalHour, day: day, month: month, year: year, priest: priest, officium: officium) else {
            loadDiagnostic = "assemble(\(canonicalHour)) returned nil for \(year)-\(month)-\(day)"
            return nil
        }

        let calendarEngine = LiturgicalCalendarEngine(corpus: latinCorpus, context: context, sanctoralCalendar: sanctoralCalendar)
        guard let liturgicalDay = calendarEngine.day(for: canonicalHour, day: day, month: month, year: year, officium: officium) else {
            loadDiagnostic = "LiturgicalCalendarEngine.day(for:) returned nil for \(year)-\(month)-\(day)"
            return nil
        }

        let displayDate = Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()

        return VespersContent(
            hour: hour,
            day: liturgicalDay,
            hourTitle: canonicalHour.title,
            dateLine: LatinDateLine.format(day: day, month: month, year: year),
            shortDate: Self.shortDateFormatter.string(from: displayDate)
        )
    }

    /// The Martyrology read on a date (Beta 4): tomorrow's entry, Latin only, the same
    /// under every office. Titled *Martyrologium*, with no rank line.
    func martyrologyContent(day: Int, month: Int, year: Int) -> VespersContent? {
        guard let latinCorpus, let sanctoralCalendar else { return nil }
        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year, ad: "Prima", rubrica: rubrica, corpus: latinCorpus, sanctoralCalendar: sanctoralCalendar
        )
        guard let hour = MartyrologyAssembler(corpus: latinCorpus, context: context, calendar: sanctoralCalendar)
            .assemble(day: day, month: month, year: year),
            var liturgicalDay = LiturgicalCalendarEngine(corpus: latinCorpus, context: context, sanctoralCalendar: sanctoralCalendar)
            .day(day: day, month: month, year: year)
        else {
            loadDiagnostic = "the Martyrology could not be assembled for \(year)-\(month)-\(day)"
            return nil
        }
        liturgicalDay.titleBlock = TitleBlock(classisLine: nil, nameLine: "Martyrologium", commemorationLine: nil)
        let displayDate = Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        return VespersContent(
            hour: hour, day: liturgicalDay, hourTitle: "Martyrologium",
            dateLine: LatinDateLine.format(day: day, month: month, year: year),
            shortDate: Self.shortDateFormatter.string(from: displayDate)
        )
    }

    /// The colour of each day of a month, for the *Jump to date* calendar (Beta 4),
    /// computed once per month.
    func calendarColors(year: Int, month: Int) -> [Int: CalendarColor] {
        let key = year * 100 + month
        if let cached = colorCache[key] { return cached }
        guard let latinCorpus, let sanctoralCalendar else { return [:] }
        var colors: [Int: CalendarColor] = [:]
        var (day, m, y) = (1, month, year)
        while m == month, y == year {
            let context = ConditionalContextBuilder.build(
                day: day, month: m, year: y, ad: "Laudes", rubrica: rubrica, corpus: latinCorpus, sanctoralCalendar: sanctoralCalendar
            )
            colors[day] = LiturgicalCalendarEngine(corpus: latinCorpus, context: context, sanctoralCalendar: sanctoralCalendar)
                .calendarColor(day: day, month: m, year: y)
            (day, m, y) = Computus.addDays(1, day: day, month: m, year: y)
        }
        colorCache[key] = colors
        return colors
    }
}
