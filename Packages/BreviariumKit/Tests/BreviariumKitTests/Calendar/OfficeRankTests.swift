import Testing
@testable import BreviariumKit

@Test func parsesRealRankFieldExamples() {
    // Sancti/01-18r.txt (S. Priscae Virginis).
    let simplex = OfficeRank(rankFieldValue: "S. Priscæ Virginis et Martyris;;Simplex;;1.1;;vide C6-1")
    #expect(simplex?.title == "S. Priscæ Virginis et Martyris")
    #expect(simplex?.degreeLabel == "Simplex")
    #expect(simplex?.numericPrecedence == 1.1)
    #expect(simplex?.communeReference == "vide C6-1")

    // Tempora/Nat01.txt (a feria's rank, commune reference points elsewhere).
    let feria = OfficeRank(rankFieldValue: ";;Feria;;1.2;;vide Sancti/01-01")
    #expect(feria?.title == "")
    #expect(feria?.degreeLabel == "Feria")
    #expect(feria?.numericPrecedence == 1.2)
}

@Test func missingOrMalformedRankReturnsNil() {
    #expect(OfficeRank(rankFieldValue: "") == nil)
    #expect(OfficeRank(rankFieldValue: "just one field") == nil)
    #expect(OfficeRank(rankFieldValue: "Title;;Duplex;;notanumber") == nil)
}

@Test func rankWithNoCommuneReferenceDefaultsToEmpty() {
    let rank = OfficeRank(rankFieldValue: "Title;;Duplex majus;;4")
    #expect(rank?.communeReference == "")
}

@Test func rankDisplayName1960CollapsesGradesCorrectly() {
    #expect(RankDisplayName1960.name(for: 0) == "Feria")
    #expect(RankDisplayName1960.name(for: 1.1) == "IV. classis")     // Simplex
    #expect(RankDisplayName1960.name(for: 2) == "III. classis")      // Semiduplex
    #expect(RankDisplayName1960.name(for: 3) == "III. classis")      // Duplex
    #expect(RankDisplayName1960.name(for: 4.9) == "III. classis")    // Duplex majus, fractional nudge
    #expect(RankDisplayName1960.name(for: 5) == "II. classis")       // Duplex II classis
    #expect(RankDisplayName1960.name(for: 6.01) == "I. classis")     // Duplex I classis, fractional nudge
    #expect(RankDisplayName1960.name(for: 7) == "I. classis")        // above
}
