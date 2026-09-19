import Testing
@testable import BreviariumKit

// `SanctoralCalendar.candidates(...)`'s transfer-table behaviour, exercised with small
// literal tables rather than the real checkout -- the real end-to-end cases (the
// Annunciation transferred in 2027/2029/2035, St Joseph in 2035) are covered against the
// real oracle fixtures in `Tests/OracleTests`; these confirm the merge mechanics alone.

@Test func candidatesUsesTheNumericEasterFileWhenPresent() {
    // 2027's Easter is 28 March -- Tabulae/Transfer/328.txt's own header confirms this
    // year takes dominical letter "c" (rule 7). A numeric-file entry for the same target
    // date must win over a letter-file one (Directorium.pm's own letter-then-numeric
    // push order -- a later push overwrites the hash).
    let calendar = SanctoralCalendar(
        entries: [:],
        transferTable: [
            "c": ["04-05": "99-99"],
            "328": ["04-05": "03-25~04-05"],
        ]
    )
    #expect(calendar.candidates(day: 5, month: 4, year: 2027) == ["03-25", "04-05"])
}

@Test func candidatesFallsBackToTheLetterFileWhenNoNumericEntryExists() {
    // Real line, b.txt: "07-16=07-16sab;;1960 Newcal" -- Tabulae/Transfer/327.txt's own
    // header ("prev: 2016") confirms 2016 (Easter 27 March) takes letter "b".
    let calendar = SanctoralCalendar(entries: [:], transferTable: ["b": ["07-16": "07-16sab"]])
    #expect(calendar.candidates(day: 16, month: 7, year: 2016) == ["07-16sab"])
}

@Test func candidatesFallsThroughToTheOrdinaryCalendarWhenNoTransferMatchesThisDate() {
    let calendar = SanctoralCalendar(
        entries: ["04-05": "04-05"],
        transferTable: ["328": ["03-30": "03-25"]]    // a different target date
    )
    #expect(calendar.candidates(day: 5, month: 4, year: 2027) == ["04-05"])
}

@Test func candidatesIgnoresATemporaReferencingTransferSource() {
    // Real line, a.txt: "01-02=Tempora/Nat2-0;;...1960...". `candidates()`'s own
    // contract is Sancti-side references only -- see `TransferResolver`'s doc comment
    // for why a Tempora-side transfer isn't applied here. 2000 (Easter 23 April) takes
    // letter "a".
    let calendar = SanctoralCalendar(entries: ["01-02": "01-02"], transferTable: ["a": ["01-02": "Tempora/Nat2-0"]])
    #expect(calendar.candidates(day: 2, month: 1, year: 2000) == ["01-02"])
}

@Test func candidatesIgnoresAnXXPlaceholderTransferSource() {
    // Real line, b.txt: "08-14=X-X;;1960 M1963" -- the Vigil of the Assumption has no
    // Sanctoral office at all under 1960. Falls through to the ordinary (here: also
    // empty) Kalendaria lookup rather than trying to render "X-X" as a candidate.
    let calendar = SanctoralCalendar(entries: [:], transferTable: ["b": ["08-14": "X-X"]])
    #expect(calendar.candidates(day: 14, month: 8, year: 2016).isEmpty)
}

@Test func candidatesReturnsEmptyWhenNoTransferTableIsConfigured() {
    // Every pre-existing call site constructs `SanctoralCalendar` with no transfer
    // table at all -- confirms the default stays a pure no-op, unchanged behaviour.
    let calendar = SanctoralCalendar(entries: ["09-16": "09-16"])
    #expect(calendar.candidates(day: 16, month: 9, year: 2026) == ["09-16"])
}
