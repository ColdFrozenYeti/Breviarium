import Testing
@testable import BreviariumKit

@Test func jToI_basicWords() {
    #expect(LatinOrthography.normalize("Jesum") == "Iesum")
    #expect(LatinOrthography.normalize("ejus") == "eius")
    #expect(LatinOrthography.normalize("iudicare") == "iudicare")
    #expect(LatinOrthography.normalize("Jerusalem") == "Ierusalem")
}

@Test func normalizeHandlesCRLFLineEndingsLineByLine() {
    // A Windows checkout (CRLF) would otherwise collapse into one "line" (Swift's
    // Character view treats "\r\n" as a single grapheme cluster), silently skipping
    // per-line normalization entirely. Output is always LF-joined regardless of input.
    #expect(LatinOrthography.normalize("Jesum\r\nejus") == "Iesum\neius")
}

@Test func jToI_preservesReferenceDirectiveLines() {
    // &Deus_in_adjutorium is a macro identifier, not prose -- the "j" must survive.
    let text = "&Deus_in_adjutorium"
    #expect(LatinOrthography.normalize(text) == text)
}

@Test func jToI_referenceLineDetectionRequiresSigilFirst() {
    #expect(LatinOrthography.isReferenceDirectiveLine("@Sancti/02-22"))
    #expect(LatinOrthography.isReferenceDirectiveLine("$Per Dominum"))
    #expect(LatinOrthography.isReferenceDirectiveLine("&Gloria"))
    #expect(LatinOrthography.isReferenceDirectiveLine("  &Gloria"))    // leading whitespace tolerated
    #expect(!LatinOrthography.isReferenceDirectiveLine("Jesum in medio @ nobis"))
}

@Test func jToI_multilineBlockMixesProseAndDirectives() {
    let input = "Jesum\n&Deus_in_adjutorium\nejus"
    let expected = "Iesum\n&Deus_in_adjutorium\neius"
    #expect(LatinOrthography.normalize(input) == expected)
}

@Test func eumdemBecomesEundemAfterEr() {
    // `Prayers.txt`'s own `[Per eumdem]` collect-ending macro body -- ports DO's own
    // `spell_var()`'s `s/er eúmdem/er eúndem/g`, confirmed against the real fixture for
    // 4 January 2025 ("Per eúndem Dóminum nostrum...", not "eúmdem").
    let input = "r. Per eúmdem Dóminum nostrum Jesum Christum Fílium tuum, qui tecum vivit."
    let expected = "r. Per eúndem Dóminum nostrum Iesum Christum Fílium tuum, qui tecum vivit."
    #expect(LatinOrthography.normalize(input) == expected)
}

@Test func eumdemUnrelatedToErIsUntouched() {
    // Only the literal "er eúmdem" substring is rewritten -- a bare "eúmdem" without a
    // preceding "er " is left alone (matches DO's own unanchored-but-literal regex).
    #expect(LatinOrthography.normalize("eúmdem") == "eúmdem")
}
