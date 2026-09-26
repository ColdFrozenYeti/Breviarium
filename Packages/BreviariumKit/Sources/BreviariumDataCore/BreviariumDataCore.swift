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
    public static let latinTopLevelFolders: Set<String> = ["Tempora", "Sancti", "Commune", "Psalterium"]

    /// `Latin-Bea/` contains only a `Psalterium/` overlay (`do-format.md`'s Psalter
    /// option finding).
    public static let latinBeaTopLevelFolders: Set<String> = ["Psalterium"]

    /// `English/` mirrors `Latin/`'s own top-level layout exactly (confirmed: `Tempora`,
    /// `Sancti`, `Commune`, `Psalterium` all present, plus the same excluded
    /// Monastic/Cistercian/Dominican siblings and non-office folders) — same subset.
    public static let englishTopLevelFolders: Set<String> = ["Tempora", "Sancti", "Commune", "Psalterium"]

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
        )
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
        )
        english += try OfficeCorpusWalker.referencedSiblings(
            languageRoot: horasRoot.appendingPathComponent("English"), of: english, applyLatinOrthography: false
        )
        english += try OfficeCorpusWalker.walk(
            languageRoot: horasRoot, topLevelFolders: ordinariumTopLevelFolders, applyLatinOrthography: false
        )
        let calendar = try CalendarChainReader.flattenedCalendar(tabulaeRoot: tabulaeRoot)
        let transferTable = try TransferTableReader.readAll(transferRoot: tabulaeRoot.appendingPathComponent("Transfer"))
        let temporaRedirect = try TemporaRedirectReader.read(temporaRoot: tabulaeRoot.appendingPathComponent("Tempora"))

        return DataBundle(
            latin: latin, latinBea: latinBea, english: english, calendar: calendar,
            transferTable: transferTable, temporaRedirect: temporaRedirect
        )
    }
}
