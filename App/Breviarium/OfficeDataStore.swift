import BreviariumKit
import Foundation

/// Loads the bundled data file once and assembles an `Hour` for a given date. Every
/// liturgical decision (occurrence, precedence, the `tempore`/`die` conditional context,
/// psalm/antiphon selection, English pairing) happens inside `BreviariumKit` calls; this
/// only wires `Bundle`/`Date` plumbing to them, per `CLAUDE.md`'s "no liturgical logic in
/// the app target".
@MainActor
final class OfficeDataStore {
    private let latinCorpus: OfficeCorpus?
    private let englishCorpus: OfficeCorpus?
    private let sanctoralCalendar: SanctoralCalendar?

    /// Always "Rubrics 1960 - 1960" for now — `CLAUDE.md`'s "Ritus: Romanus / Ambrosianus"
    /// setting and the Ambrosian rite provider both stay unimplemented until a later
    /// milestone.
    private let rubrica = "Rubrics 1960 - 1960"

    init() {
        guard
            let url = Bundle.main.url(forResource: "breviarium-data", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let bundle = try? JSONDecoder().decode(DataBundle.self, from: data)
        else {
            latinCorpus = nil
            englishCorpus = nil
            sanctoralCalendar = nil
            return
        }
        latinCorpus = bundle.makeLatinCorpus()
        englishCorpus = bundle.makeEnglishCorpus()
        sanctoralCalendar = SanctoralCalendar(entries: bundle.calendar)
    }

    /// Roman Vespers for `date`, in the Gregorian calendar's own day/month/year (this
    /// project targets one person in one timezone, so there is no timezone parameter to
    /// thread through). `nil` when the bundled data failed to load or decode.
    func vespers(on date: Date, priest: Bool, gregorianCalendar: Calendar = Calendar(identifier: .gregorian)) -> Hour? {
        guard let latinCorpus, let englishCorpus, let sanctoralCalendar else { return nil }
        let components = gregorianCalendar.dateComponents([.day, .month, .year], from: date)
        guard let day = components.day, let month = components.month, let year = components.year else { return nil }

        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year,
            ad: "vesperas", rubrica: rubrica,
            corpus: latinCorpus, sanctoralCalendar: sanctoralCalendar
        )
        let assembler = HourAssembler(corpus: latinCorpus, context: context, calendar: sanctoralCalendar, englishCorpus: englishCorpus)
        return assembler.assembleVespers(day: day, month: month, year: year, priest: priest)
    }
}
