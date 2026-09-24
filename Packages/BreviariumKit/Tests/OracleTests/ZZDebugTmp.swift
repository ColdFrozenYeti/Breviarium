import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore
import Foundation

@Test func zzDebugDump() throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let spec = ProcessInfo.processInfo.environment["DBG_DATES"] ?? "2026-12-21"
    for d in spec.split(separator: ",") {
        let p = d.split(separator: "-").map { Int($0)! }
        let context = ConditionalContextBuilder.build(day: p[2], month: p[1], year: p[0], ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar)
        let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
        let hour = assembler.assembleVespers(day: p[2], month: p[1], year: p[0], priest: false)!
        let c = Concurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: p[2], month: p[1], year: p[0])!
        print("=== \(d) firstV=\(c.isFirstVespersOfTomorrow) winner=\(c.vespersOffice.winningPath) \(c.vespersOffice.winningRank.title) \(c.vespersOffice.winningRank.numericPrecedence)")
        for m in Commemorations(corpus: corpus, context: context, calendar: calendar).resolve(day: p[2], month: p[1], year: p[0]) {
            print("  comm: \(m.path) \(m.rank.title) \(m.rank.numericPrecedence) ind=\(m.ind)")
        }
        let sections = (ProcessInfo.processInfo.environment["DBG_SECTIONS"] ?? "oratio").split(separator: ",").map(String.init)
        for s in hour.sections where sections.contains(s.kind.rawValue) {
            print("  [\(s.kind.rawValue)]")
            for u in s.units { print("    \(u)".prefix(200)) }
        }
    }
}
