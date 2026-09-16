import Testing
@testable import BreviariumKit

@Test func jToI_basicWords() {
    #expect(LatinOrthography.normalize("Jesum") == "Iesum")
    #expect(LatinOrthography.normalize("ejus") == "eius")
    #expect(LatinOrthography.normalize("iudicare") == "iudicare")
    #expect(LatinOrthography.normalize("Jerusalem") == "Ierusalem")
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
