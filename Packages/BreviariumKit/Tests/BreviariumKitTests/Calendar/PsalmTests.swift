import Testing
@testable import BreviariumKit

// Direct feedback found via a UI walkthrough screenshot (24 February 2026's Vespers
// psalmody): a real fragment of `Latin-Bea/Psalterium/Psalmorum/Psalm115.txt` --
// "115:14 Vota mea Dómino reddam coram omni pópulo ejus. * (15) Pretiósa est in óculis
// Dómini mors sanctórum ejus." -- rendered its own inline "(15)" Vulgate-numbering
// cross-reference as literal on-screen text. `horasscripts.pl:397-407` confirms DO
// treats this the same way as the verse's own leading reference number (both wrapped in
// the `/:...:/ ` small-font-footnote convention) -- and this app already never displays
// that leading reference, so parity means dropping this inline one too, not showing it.

@Test func parseVersesDropsAnInlineSubVerseAnnotation() {
    let verses = Psalm.parseVerses([
        "115:14 Vota mea Dómino reddam coram omni pópulo ejus. * (15) Pretiósa est in óculis Dómini mors sanctórum ejus.",
    ])
    #expect(verses.count == 1)
    #expect(verses[0].secondHalf == "Pretiósa est in óculis Dómini mors sanctórum ejus.")
    #expect(!verses[0].firstHalf.contains("("))
    #expect(!verses[0].secondHalf.contains("("))
}

@Test func parseVersesDropsALetteredInlineSubVerseAnnotation() {
    // Real fragment, same file: a lettered half-verse boundary can carry the annotation too.
    let verses = Psalm.parseVerses([
        "115:16b Solvísti víncula mea. * (17) Tibi sacrificábo sacrifícium laudis, et nomen Dómini invocábo.",
    ])
    #expect(verses[0].secondHalf == "Tibi sacrificábo sacrifícium laudis, et nomen Dómini invocábo.")
}

// Found via a full 2025-2040 content audit and confirmed against the real fixture for
// 19 January 2026: DO's own real rendering strips a Bea-only "a"/"b" sub-verse letter
// from the *displayed* verse reference (`horasscripts.pl:400-401`'s "remove subverse
// letter", gated by `$noinnumbers`) -- a "115:16a"/"115:16b" pair both show as plain
// "115:16" on the real page, not distinguished by letter, even though they stay two
// separate lines.

@Test func parseVersesStripsTheSubVerseLetterFromTheDisplayedReference() {
    let verses = Psalm.parseVerses([
        "115:16a O Dómine, ego servus tuus sum, * ego servus tuus, fílius ancíllæ tuæ:",
        "115:16b Solvísti víncula mea. * (17) Tibi sacrificábo sacrifícium laudis, et nomen Dómini invocábo.",
    ])
    #expect(verses.map(\.reference) == ["115:16", "115:16"])
}

@Test func parseVersesLeavesAnOrdinaryUnletteredReferenceUntouched() {
    let verses = Psalm.parseVerses(["109:1 Dixit Dóminus Dómino meo: * Sede a dextris meis."])
    #expect(verses[0].reference == "109:1")
}
