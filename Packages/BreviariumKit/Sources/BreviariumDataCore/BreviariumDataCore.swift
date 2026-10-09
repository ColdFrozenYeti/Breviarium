import Foundation
import BreviariumKit

/// The build-time data pipeline: reads the pinned Divinum Officium checkout and produces
/// a `DataBundle` — raw section splitting, J->I orthography, and calendar-chain
/// flattening only (see `docs/PLAN.md`'s 2026-09-16 amendment for why conditional/`@`/`$`
/// resolution deliberately does **not** happen here).
public enum BreviariumDataPipeline {

    /// This project's Roman secular subset of the Latin corpus — excludes the
    /// Monastic/Cistercian/Dominican sibling folders (`*M`/`*Cist`/`*OP`) and non-office
    /// content (`Martyrologium`, `Regula`, `Necrologium`, `Appendix`); see `do-format.md`.
    /// Beta 4 adds `Martyrologium1960`, the 1960 Martyrology (Latin only, decision 3 of
    /// `docs/Beta_4_plan.md`).
    public static let latinTopLevelFolders: Set<String> = [
        "Tempora", "Sancti", "Commune", "Psalterium", "Martyrologium1960",
        // Beta 5: the Dominican office (`docs/rubrics-op1962.md` §2).
        "TemporaOP", "SanctiOP", "CommuneOP", "Regula",
    ]

    /// `Latin-Bea/` contains only a `Psalterium/` overlay (`do-format.md`'s Psalter
    /// option finding).
    public static let latinBeaTopLevelFolders: Set<String> = ["Psalterium"]

    /// `English/` mirrors `Latin/`'s own top-level layout exactly (confirmed: `Tempora`,
    /// `Sancti`, `Commune`, `Psalterium` all present, plus the same excluded
    /// Monastic/Cistercian/Dominican siblings and non-office folders) — same subset.
    public static let englishTopLevelFolders: Set<String> = ["Tempora", "Sancti", "Commune", "Psalterium", "TemporaOP", "Regula"]

    /// `Ordinarium/` (the hour skeletons `HourAssembler` reads, e.g. `Vespera.txt`) sits
    /// directly under `web/www/horas`, a sibling of `Latin`/`Latin-Bea`/`English` rather
    /// than living inside one of them — it's language-neutral scaffolding (`#Name`
    /// section markers, `&`/`$` macro invocations, and a handful of Latin rubric
    /// phrases), read once and shared regardless of which language corpus is in use.
    public static let ordinariumTopLevelFolders: Set<String> = ["Ordinarium"]

    /// `checkoutRoot` is the DO submodule's root (containing `web/www/horas` and
    /// `web/www/Tabulae`).
    public static func build(checkoutRoot: URL) throws -> DataBundle {
        let horasRoot = checkoutRoot.appendingPathComponent("web/www/horas")
        let tabulaeRoot = checkoutRoot.appendingPathComponent("web/www/Tabulae")

        var latin = try OfficeCorpusWalker.walk(
            languageRoot: horasRoot.appendingPathComponent("Latin"),
            topLevelFolders: latinTopLevelFolders,
            applyLatinOrthography: true
        ).filter(Self.isWanted)
        latin += try OfficeCorpusWalker.referencedSiblings(
            languageRoot: horasRoot.appendingPathComponent("Latin"), of: latin, applyLatinOrthography: true
        )
        latin += try OfficeCorpusWalker.walk(
            languageRoot: horasRoot, topLevelFolders: ordinariumTopLevelFolders, applyLatinOrthography: true
        )
        let latinBea = try OfficeCorpusWalker.walk(
            languageRoot: horasRoot.appendingPathComponent("Latin-Bea"),
            topLevelFolders: latinBeaTopLevelFolders,
            applyLatinOrthography: true
        )
        var english = try OfficeCorpusWalker.walk(
            languageRoot: horasRoot.appendingPathComponent("English"),
            topLevelFolders: englishTopLevelFolders,
            applyLatinOrthography: false
        ).filter(Self.isWanted)
        english += try OfficeCorpusWalker.referencedSiblings(
            languageRoot: horasRoot.appendingPathComponent("English"), of: english, applyLatinOrthography: false
        )
        // The other rites' files the Latin borrows (`@TemporaM/Adv1-0:Responsory11` in a
        // Dominican responsory) in English too: DO reads the English file when it exists,
        // as an English office with no file of its own falls back to the Latin one.
        let englishPaths = Set(english.map(\.path))
        english += try OfficeCorpusWalker.files(
            languageRoot: horasRoot.appendingPathComponent("English"),
            paths: latin.map(\.path).filter { !englishPaths.contains($0) && $0.range(of: #"^(Sancti|Tempora|Commune)(M|Cist)/"#, options: .regularExpression) != nil },
            applyLatinOrthography: false
        )
        english += try OfficeCorpusWalker.walk(
            languageRoot: horasRoot, topLevelFolders: ordinariumTopLevelFolders, applyLatinOrthography: false
        )
        // Beta 5: the Mass Gospels for the Dominican Prime (`docs/rubrics-op1962.md` §4).
        let missaRoot = checkoutRoot.appendingPathComponent("web/www/missa")
        latin += try OfficeCorpusWalker.walkMissaGospels(languageRoot: missaRoot.appendingPathComponent("Latin"), applyLatinOrthography: true)
        english += try OfficeCorpusWalker.walkMissaGospels(languageRoot: missaRoot.appendingPathComponent("English"), applyLatinOrthography: false)
        let calendar = try CalendarChainReader.flattenedCalendar(tabulaeRoot: tabulaeRoot)
        let calendarOP = try CalendarChainReader.flattenedCalendar(tabulaeRoot: tabulaeRoot, rite: .dominicanus)
        var transferTable = try TransferTableReader.readAll(transferRoot: tabulaeRoot.appendingPathComponent("Transfer"))
        // The Scripture transfer tables (`Tabulae/Stransfer`, DO's `initiarule`), kept in the
        // same map under an `S:` prefix: `SanctoralCalendar.scriptureTransfer`.
        for (key, table) in try TransferTableReader.readAll(transferRoot: tabulaeRoot.appendingPathComponent("Stransfer")) {
            transferTable["S:" + key] = table
        }
        let temporaRedirect = try TemporaRedirectReader.read(temporaRoot: tabulaeRoot.appendingPathComponent("Tempora"))

        return DataBundle(
            latin: latin, latinBea: latinBea, english: english, calendar: calendar,
            transferTable: transferTable, temporaRedirect: temporaRedirect, calendarOP: calendarOP,
            ambrosian: try ambrosian(root: checkoutRoot.deletingLastPathComponent().appendingPathComponent("ambrosian"))
        )
    }

    /// Beta 6: `data/ambrosian/` (beside the DO checkout), the Ambrosian rite's own
    /// sources: Compline, its corrections, and the calendar. `nil` if the folder isn't
    /// there.
    static func ambrosian(root: URL) throws -> AmbrosianData? {
        let compline = root.appendingPathComponent("completorium-1957.txt")
        guard FileManager.default.fileExists(atPath: compline.path) else { return nil }
        return try AmbrosianSource.data(
            compline: String(contentsOf: compline, encoding: .utf8),
            corrections: String(contentsOf: root.appendingPathComponent("corrections.txt"), encoding: .utf8),
            calendar: String(contentsOf: root.appendingPathComponent("kalendarium.txt"), encoding: .utf8)
        )
    }

    /// Of `Regula/`, only the Dominican Prime's Rule of St Augustine
    /// (`monastic.pl:624`); the Benedictine Rule's daily readings belong to the Monastic
    /// office, which this app doesn't have.
    static func isWanted(_ file: RawOfficeFile) -> Bool {
        !file.path.hasPrefix("Regula/") || file.path.hasPrefix("Regula/OrdoPraedicatorum")
    }
}
