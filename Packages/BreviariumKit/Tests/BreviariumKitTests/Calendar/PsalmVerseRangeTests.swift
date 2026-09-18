import Testing
@testable import BreviariumKit

// Direct feedback found via a random-sample visual walkthrough: Friday/Saturday's
// ferial Vespers psalms are split across two of the hour's five slots in
// `Psalmi major.txt` (e.g. "138(1-13)"/"138(14-24)"), and using that string unstripped
// as a file path silently dropped the psalm to zero verses. These tests cover
// `PsalmVerseRange` in isolation, without needing the real DO checkout.

@Test func parseReturnsNilForAnUnsplitPsalmNumber() {
    #expect(PsalmVerseRange.parse("138") == nil)
}

@Test func parseSplitsAPlainNumericRange() throws {
    let (base, range) = try #require(PsalmVerseRange.parse("138(1-13)"))
    #expect(base == "138")
    #expect(range == PsalmVerseRange(startVerse: 1, startLetter: nil, endVerse: 13, endLetter: nil))
}

@Test func parseSplitsAQuotedLetterBoundary() throws {
    // Saturday's own Psalm 144 split -- confirmed real: Psalm144.txt's own verse 13 is
    // itself split into "144:13a"/"144:13b" lines, landing exactly at this boundary.
    let (base1, range1) = try #require(PsalmVerseRange.parse("144(8-'13a')"))
    #expect(base1 == "144")
    #expect(range1 == PsalmVerseRange(startVerse: 8, startLetter: nil, endVerse: 13, endLetter: "a"))

    let (base2, range2) = try #require(PsalmVerseRange.parse("144('13b'-21)"))
    #expect(base2 == "144")
    #expect(range2 == PsalmVerseRange(startVerse: 13, startLetter: "b", endVerse: 21, endLetter: nil))
}

@Test func plainRangeIncludesBothEndpointsAndExcludesOutsideVerses() {
    let range = PsalmVerseRange(startVerse: 1, startLetter: nil, endVerse: 13, endLetter: nil)
    #expect(range.contains(verse: 1, letter: nil))
    #expect(range.contains(verse: 7, letter: nil))
    #expect(range.contains(verse: 13, letter: nil))
    #expect(!range.contains(verse: 14, letter: nil))
    #expect(!range.contains(verse: 0, letter: nil))
}

@Test func letteredBoundarySplitsExactlyAtTheSubVerse() {
    // "144(8-'13a')": verse 13's 'a' half belongs to this range, its 'b' half doesn't.
    let firstHalf = PsalmVerseRange(startVerse: 8, startLetter: nil, endVerse: 13, endLetter: "a")
    #expect(firstHalf.contains(verse: 13, letter: "a"))
    #expect(!firstHalf.contains(verse: 13, letter: "b"))
    #expect(!firstHalf.contains(verse: 14, letter: nil))

    // "144('13b'-21)": the mirror image -- 'b' belongs here, 'a' doesn't.
    let secondHalf = PsalmVerseRange(startVerse: 13, startLetter: "b", endVerse: 21, endLetter: nil)
    #expect(secondHalf.contains(verse: 13, letter: "b"))
    #expect(!secondHalf.contains(verse: 13, letter: "a"))
    #expect(secondHalf.contains(verse: 21, letter: nil))
}

@Test func verseNumberAndLetterParsesAFullReference() {
    let plain = PsalmVerseRange.verseNumberAndLetter(fromReference: "138:13")
    #expect(plain?.verse == 13)
    #expect(plain?.letter == nil)

    let lettered = PsalmVerseRange.verseNumberAndLetter(fromReference: "144:13a")
    #expect(lettered?.verse == 13)
    #expect(lettered?.letter == "a")
}
