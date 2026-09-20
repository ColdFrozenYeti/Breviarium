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

@Test func flexaDaggerIsStrippedEntirely() {
    // Psalm110.txt's own "110:9 Redemptiónem misit pópulo suo, † státuit in ætérnum
    // fœdus suum; * sanctum et venerábile est nomen ejus." -- ports
    // `horasscripts.pl`'s own `s/†\s*//g if $noflexa` (Breviarium Romanum style),
    // confirmed against the real fixture for 4 January 2025: no "†" survives, and the
    // surrounding spacing collapses to a single space, not a double one.
    let input = "110:9 Redemptiónem misit pópulo suo, † státuit in ætérnum fœdus suum; * sanctum et venerábile est nomen ejus."
    let expected = "110:9 Redemptiónem misit pópulo suo, státuit in ætérnum fœdus suum; * sanctum et venerábile est nomen eius."
    #expect(LatinOrthography.normalize(input) == expected)
}

@Test func daggerAfterAVerseNumberIsLeftAloneNotConvertedLikeARawFlexaMark() {
    // `HourAssembler`'s own *inserted* "‡" (the antiphon-quotes-a-whole-verse rule)
    // marks the start of the *next* verse, right after its bare verse number -- no
    // punctuation before it, unlike a genuine raw source "‡" (always mid-sentence,
    // preceded by a comma/semicolon/colon). Confirmed this distinction matters for
    // real: applying the unscoped conversion to a real DO fixture (which can
    // legitimately contain this kind of "‡", e.g. "132:2 ‡ Sicut óleum óptimum in
    // cápite, * quod défluit...") wrongly moved the "*", corrupting a fixture
    // comparison that was otherwise correct.
    let input = "132:2 ‡ Sicut óleum óptimum in cápite, * quod défluit in barbam, barbam Aaron,"
    #expect(LatinOrthography.normalize(input) == input)
}

@Test func rawFlexaMarkerMovesTheAsteriskToItself() {
    // Psalm144.txt's own "144:19 Voluntátem timéntium se fáciet, ‡ et clamórem eórum
    // áudiet, * et salvábit eos." -- ports `horasscripts.pl`'s own
    // `s/‡\s+(.*?)\*\s*/* $1/g if $noflexa`, confirmed against the real fixture for
    // 18 January 2026: the "*" moves to where "‡" was, and the verse's own later "*"
    // is gone.
    let input = "144:19 Voluntátem timéntium se fáciet, ‡ et clamórem eórum áudiet, * et salvábit eos."
    let expected = "144:19 Voluntátem timéntium se fáciet, * et clamórem eórum áudiet, et salvábit eos."
    #expect(LatinOrthography.normalize(input) == expected)
}
