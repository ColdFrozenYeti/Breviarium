import Testing
@testable import BreviariumKit

// Real fragments from `Tabulae/Transfer/325.txt` (Easter falls on 25 March, 2035) and
// `Tabulae/Transfer/b.txt` (the dominical-letter bucket for Easter-falls-28-March years
// like 2027), read directly from the pinned DO checkout during this session.

@Test func parseEntriesKeepsAnExplicitly1960TaggedLine() {
    let entries = TransferResolver.parseEntries("04-02=03-25;;1570 1888 1906 1960 DA M1930 M1963 Newcal")
    #expect(entries["04-02"] == "03-25")
}

@Test func parseEntriesKeepsAUniversalUntaggedLine() {
    let entries = TransferResolver.parseEntries("04-09=03-25")
    #expect(entries["04-09"] == "03-25")
}

@Test func parseEntriesDropsALineNotTaggedFor1960() {
    let entries = TransferResolver.parseEntries("04-01=03-21;;1570 M1930 M1963")
    #expect(entries["04-01"] == nil)
}

@Test func parseEntriesWordBoundaryDoesNotMatch1960InsideM1963() {
    let entries = TransferResolver.parseEntries("04-03=03-19t;;1570 M1963")
    #expect(entries["04-03"] == nil)
}

@Test func parseEntriesSkipsDirgeAndHymnAndCommentLines() {
    let text = """
    #= sunday letter: d, rule number:  1
    dirge1=01-24 02-09 02-16;;1570
    Hy05-18=1;;DA
    03-30=03-25;;1960
    """
    let entries = TransferResolver.parseEntries(text)
    #expect(entries.count == 1)
    #expect(entries["03-30"] == "03-25")
}

@Test func parseEntriesKeepsBothPiecesOfATildeJoinedSource() {
    // Real line, 328.txt (Easter 28 March, e.g. 2027): the Annunciation transfers to
    // 5 April, tilde-joined with a same-day commemoration candidate.
    let entries = TransferResolver.parseEntries("04-05=03-25~04-05;;1888 1906 1960 DA M1963 Newcal")
    #expect(entries["04-05"] == "03-25~04-05")
}

@Test func parseEntriesTreatsATrailingEmptyVersionListAsUniversal() {
    // Real line, Transfer/e.txt (the dominical-letter bucket 2025 falls under): a
    // trailing ";;" with nothing after it is a *present but empty* version list --
    // DO's own real semantics treat this the same as no ";;" at all, not as "doesn't
    // list 1960" (which an empty string would otherwise always fail to match).
    // Confirmed real: without this distinction, this line was silently discarded,
    // leaving the day's real transfer target unapplied. A later same-key line
    // correctly tagged for a different version (not 1960) must still be dropped.
    let text = """
        11-02=11-02oct;;
        11-02=X-X;;CAV
        """
    let entries = TransferResolver.parseEntries(text)
    #expect(entries["11-02"] == "11-02oct")
}
