import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

/// Assembles a real Vespers against the actual pinned Divinum Officium checkout --
/// deliberately distinct from every other test in this package, which builds synthetic
/// in-memory fixtures. Worth keeping precisely because it isn't synthetic: building
/// `HourAssembler` against real data (not hand-crafted fixtures that only ever exercise
/// what the fixture's author already assumed) surfaced three real bugs in one session
/// -- `OfficeRank` rejecting a trailing newline in a resolved `[Rank]` field,
/// `ScriptMacros` querying `Prayers.txt`'s `"Deus in adjutorium"` header by its literal
/// (pre-orthography-normalisation) spelling, and `SectionResolver` not handling a
/// `$Name.` macro line's sentence-final period -- none of which any synthetic fixture
/// had reason to expose, since a fixture's author naturally writes both the query and
/// the corresponding data consistently. Not a substitute for `Tests/OracleTests`
/// (not yet built) -- this only proves assembly doesn't crash and produces plausible
/// structure for one real, hand-verifiable date, not correctness against DO's own
/// rendered output.
@Test func assemblesRealVespersFor16September2026WithoutError() throws {
    let checkoutRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("data/divinum-officium")
    guard FileManager.default.fileExists(atPath: checkoutRoot.path) else {
        // Submodule not checked out (e.g. a clone without `git submodule update --init`) --
        // skip rather than fail, matching this repo's own CI setup step's expectations.
        return
    }

    let bundle = try BreviariumDataPipeline.build(checkoutRoot: checkoutRoot)
    let corpus = bundle.makeLatinCorpus()
    // "Rubrics 1960 - 1960", 16 September 2026 -- CLAUDE.md's own worked example
    // (Ss. Cornelii Papæ et Cypriani, III. classis, a Wednesday).
    let context = ConditionalContext(rubrica: "Rubrics 1960 - 1960", tempore: "post Pentecosten", feria: 4, ad: "vesperas", mense: 9)
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable))

    let hour = try #require(assembler.assembleVespers(day: 16, month: 9, year: 2026, priest: false))

    let introductio = try #require(hour.sections.first { $0.kind == .introductio })
    #expect(
        introductio.units.contains(
            .versicleResponse(versicle: "Deus + in adiutórium meum inténde.", response: "Dómine, ad adiuvándum me festína.")
        )
    )
    // J-to-I orthography must have already run (this is real, unmodified corpus text).
    #expect(!introductio.units.contains { if case .prose(let text, _) = $0 { return text.contains("Jesu") } else { return false } })

    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    #expect(canticum.units.contains { if case .antiphon = $0 { return true } else { return false } })
    #expect(canticum.units.contains { if case .verse(let ref, _, _, _, _) = $0 { return ref.hasPrefix("1:") } else { return false } })

    let oratio = try #require(hour.sections.first { $0.kind == .oratio })
    let collectText = oratio.units.compactMap { if case .prose(let text, _) = $0 { return text } else { return nil } }
        .joined(separator: " ")
    #expect(collectText.contains("Iesum Christum"))    // The $Per Dominum ending, I-spelled.
    #expect(!collectText.contains("is missing!"))      // No unresolved @/$/& reference leaked through.

    let conclusio = try #require(hour.sections.first { $0.kind == .conclusio })
    #expect(
        conclusio.units.contains(
            .versicleResponse(versicle: "Dómine, exáudi oratiónem meam.", response: "Et clamor meus ad te véniat.")
        )
    )

    // English corpus wiring: real DO English text, no orthography normalisation run on
    // it ("Deus in adjutorium" keeps its "j" -- English is never J-to-I transformed).
    let englishResolver = SectionResolver(corpus: bundle.makeEnglishCorpus(), context: context)
    let englishDeusInAdiutorium = englishResolver.resolve(path: SectionResolver.prayersPath, section: "Deus in adjutorium")
    #expect(englishDeusInAdiutorium.contains("O God, + come to my assistance"))
}
