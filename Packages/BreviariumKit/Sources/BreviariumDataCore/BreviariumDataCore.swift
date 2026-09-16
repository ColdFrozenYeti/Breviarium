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

    /// `checkoutRoot` is the DO submodule's root (containing `web/www/horas` and
    /// `web/www/Tabulae`).
    public static func build(checkoutRoot: URL) throws -> DataBundle {
        let horasRoot = checkoutRoot.appendingPathComponent("web/www/horas")
        let tabulaeRoot = checkoutRoot.appendingPathComponent("web/www/Tabulae")

        let latin = try OfficeCorpusWalker.walk(
            languageRoot: horasRoot.appendingPathComponent("Latin"),
            topLevelFolders: latinTopLevelFolders,
            applyLatinOrthography: true
        )
        let latinBea = try OfficeCorpusWalker.walk(
            languageRoot: horasRoot.appendingPathComponent("Latin-Bea"),
            topLevelFolders: latinBeaTopLevelFolders,
            applyLatinOrthography: true
        )
        let calendar = try CalendarChainReader.flattenedCalendar(tabulaeRoot: tabulaeRoot)

        return DataBundle(latin: latin, latinBea: latinBea, calendar: calendar)
    }
}
