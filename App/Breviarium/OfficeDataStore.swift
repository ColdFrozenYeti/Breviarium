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
    private let englishCorpus: OfficeCorpus?
    private let sanctoralCalendar: SanctoralCalendar?

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
            englishCorpus = nil
            sanctoralCalendar = nil
            loadDiagnostic = "resource breviarium-data.json not found in Bundle.main"
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            latinCorpus = nil
            englishCorpus = nil
            sanctoralCalendar = nil
            loadDiagnostic = "could not read data at \(url.path)"
            return
        }
        do {
            let bundle = try JSONDecoder().decode(DataBundle.self, from: data)
            latinCorpus = bundle.makeLatinCorpus()
            englishCorpus = bundle.makeEnglishCorpus()
            sanctoralCalendar = bundle.makeSanctoralCalendar()
        } catch {
            latinCorpus = nil
            englishCorpus = nil
            sanctoralCalendar = nil
            loadDiagnostic = "decode failed: \(error)"
        }
    }

    /// Roman Vespers for `date`, in the given calendar's own day/month/year (defaults to
    /// the device's local Gregorian calendar, since "what day is it" for a real user
    /// means their own local day boundary, not UTC's). `nil` when the bundled data
    /// failed to load/decode, or the date can't be resolved to an office at all.
    func vespersContent(on date: Date, priest: Bool, calendar: Calendar = Calendar(identifier: .gregorian)) -> VespersContent? {
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        guard let day = components.day, let month = components.month, let year = components.year else { return nil }
        return vespersContent(day: day, month: month, year: year, priest: priest)
    }

    /// Same as `vespersContent(on:priest:calendar:)`, but by explicit day/month/year --
    /// used for deterministic snapshot testing (`BreviariumApp`'s `BREVIARIUM_SNAPSHOT_DATE`),
    /// where round-tripping a fixed date through a `Date`/`Calendar` conversion would
    /// otherwise risk landing on the wrong day depending on the device's timezone.
    func vespersContent(day: Int, month: Int, year: Int, priest: Bool) -> VespersContent? {
        guard let latinCorpus, let englishCorpus, let sanctoralCalendar else { return nil }

        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year,
            ad: "vesperas", rubrica: rubrica,
            corpus: latinCorpus, sanctoralCalendar: sanctoralCalendar
        )
        let assembler = HourAssembler(corpus: latinCorpus, context: context, calendar: sanctoralCalendar, englishCorpus: englishCorpus)
        guard let hour = assembler.assembleVespers(day: day, month: month, year: year, priest: priest) else {
            loadDiagnostic = "assembleVespers returned nil for \(year)-\(month)-\(day)"
            return nil
        }

        let calendarEngine = LiturgicalCalendarEngine(corpus: latinCorpus, context: context, sanctoralCalendar: sanctoralCalendar)
        guard let liturgicalDay = calendarEngine.day(day: day, month: month, year: year) else {
            loadDiagnostic = "LiturgicalCalendarEngine.day returned nil for \(year)-\(month)-\(day)"
            return nil
        }

        let displayDate = Self.utcCalendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()

        return VespersContent(
            hour: hour,
            day: liturgicalDay,
            hourTitle: "Ad Vesperas",
            dateLine: LatinDateLine.format(day: day, month: month, year: year),
            shortDate: Self.shortDateFormatter.string(from: displayDate)
        )
    }
}
