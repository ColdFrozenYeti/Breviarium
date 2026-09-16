import Testing
@testable import BreviariumKit

// Ported case-for-case from DO's own t/DivinumOfficium/LiturgicalColor.t and Main.t,
// with DO's internal token names remapped to real colours (black->white, grey->black,
// blue/red/green/purple->blue/red/green/violet -- see LiturgicalColor.swift's doc
// comment). These are acceptance-style checks against real day titles pulled from the
// actual shipped data, covering every part of the 1960-rubrics liturgical year, plus a
// second group pinning down the regex branch-ordering/case-sensitivity mechanics with
// synthetic strings.

private typealias C = LiturgicalColorClassifier

// MARK: - Real titles across the liturgical year (LiturgicalColor.t)

@Test func adventIsViolet() {
    #expect(C.classify(title: "Dominica I Adventus") == .violet)
}

@Test func christmastideIsWhiteExceptMartyrsWithinIt() {
    #expect(C.classify(title: "In Nativitate Domini") == .white)
    #expect(C.classify(title: "Dominica infra Octavam Nativitatis") == .white)
    // 26 Dec, within the Octave of Christmas: a martyr's feast overrides the season's
    // own white.
    #expect(C.classify(title: "S. Stephani Protomartyris") == .red)
}

@Test func newYearsDayBothHistoricalTitlesAreWhite() {
    #expect(C.classify(title: "In Circumcisione Domini") == .white)             // pre-1960 title
    #expect(C.classify(title: "Die Octavæ Nativitatis Domini") == .white)       // 1960-rubrics title
}

@Test func vigilOfEpiphanyIsWhite() {
    #expect(C.classify(title: "In Vigilia Epiphaniæ") == .white)
}

@Test func holyFamilyIsWhiteDespiteMentioningMary() {
    // A real-data near-miss for the blue Marian pattern: "Sanctae Familiae" isn't
    // immediately followed by " Mari".
    #expect(C.classify(title: "Sanctæ Familiæ Jesu Mariæ Joseph") == .white)
}

@Test func octaveDayOfEpiphanyStaysWhiteNotYetGreen() {
    #expect(C.classify(title: "In Octava Epiphaniæ") == .white)
}

@Test func ordinarySundayAfterEpiphanyIsGreen() {
    #expect(C.classify(title: "Dominica II post Epiphaniam") == .green)
}

@Test func septuagesimaLentEmberDaysAreViolet() {
    #expect(C.classify(title: "Dominica in Septuagesima") == .violet)
    #expect(C.classify(title: "Dominica I in Quadragesima") == .violet)
    #expect(C.classify(title: "Feria Quarta Quattuor Temporum Septembris") == .violet)
}

@Test func passiontideAndHolyWeekAreViolet() {
    #expect(C.classify(title: "Dominica de Passione") == .violet)
    #expect(C.classify(title: "Dominica I Passionis") == .violet)
    #expect(C.classify(title: "Dominica in Palmis") == .violet)
    #expect(C.classify(title: "Dominica II Passionis seu in Palmis") == .violet)
    #expect(C.classify(title: "Feria Secunda in Rogationibus") == .violet)
}

@Test func eveOfAscensionBothHistoricalTitles() {
    // Pre-1960: still a Rogation Day, violet. 1960-rubrics: the Ascension Vigil proper, white.
    #expect(C.classify(title: "Feria Quarta in Rogationibus in Vigilia Ascensionis") == .violet)
    #expect(C.classify(title: "In Vigilia Ascensionis") == .white)
}

@Test func holyThursdayIsWhite() {
    #expect(C.classify(title: "Feria Quinta in Cena Domini") == .white)
}

@Test func goodFridayBothHistoricalTitlesAreBlack() {
    #expect(C.classify(title: "Feria Sexta in Parasceve") == .black)                        // pre-1960/1955 title
    #expect(C.classify(title: "Feria Sexta in Passione et Morte Domini") == .black)          // 1955/1960-rubrics title
}

@Test func holySaturdayBeforeTheVigilIsViolet() {
    #expect(C.classify(title: "Sabbato Sancto") == .violet)
}

@Test func eastertideIsWhite() {
    #expect(C.classify(title: "Die II infra octavam Paschæ") == .white)
    // Easter Sunday's real title says "Resurrectionis", not "Pascha" -- reached via the
    // default fallback, not the "Pasch" keyword.
    #expect(C.classify(title: "Dominica Resurrectionis") == .white)
    #expect(C.classify(title: "Dominica in Albis in Octava Paschæ") == .white)
    #expect(C.classify(title: "Dominica III post Pascha") == .white)
    #expect(C.classify(title: "Dominica infra Octavam Ascensionis") == .white)
}

@Test func pentecostIsRed() {
    #expect(C.classify(title: "Sabbato in Vigilia Pentecostes") == .red)
    #expect(C.classify(title: "Dominica Pentecostes") == .red)
}

@Test func timeAfterPentecostFeastsOfTheLordAreWhite() {
    #expect(C.classify(title: "Dominica Sanctissimæ Trinitatis") == .white)
    #expect(C.classify(title: "Festum Sanctissimi Corporis Christi") == .white)
    // A Sunday within the Octave of Corpus Christi keeps that white octave, not the
    // ordinary green -- exactly the real case green's negative lookahead exists for.
    #expect(C.classify(title: "Dominica II Post Pentecosten infra Octavam Corporis Christi") == .white)
    #expect(C.classify(title: "Sacratissimi Cordis Domini Nostri Jesu Christi") == .white)
    #expect(C.classify(title: "Domini Nostri Jesu Christi Regis") == .white)
}

@Test func ordinarySundaysAfterPentecostAreGreen() {
    #expect(C.classify(title: "Dominica X Post Pentecosten") == .green)
    #expect(C.classify(title: "Dominica XXIV et Ultima Post Pentecosten") == .green)
}

@Test func marianFeastsAreBlue() {
    #expect(C.classify(title: "In Purificatione Beatæ Mariæ Virginis") == .blue)
    #expect(C.classify(title: "In Annuntiatione Beatæ Mariæ Virginis") == .blue)
    #expect(C.classify(title: "In Assumptione Beatæ Mariæ Virginis") == .blue)
    #expect(C.classify(title: "Assumptio BeatBeatæ Mariæ Mariæ Virginis") == .blue)
    #expect(C.classify(title: "In Conceptione Immaculata Beatæ Mariæ Virginis") == .blue)
    #expect(C.classify(title: "In Nativitate Beatæ Mariæ Virginis") == .blue)
    #expect(C.classify(title: "Beatæ Mariæ Virginis a Rosario") == .blue)
}

@Test func redFeastsMartyrsApostlesTheHolyCross() {
    #expect(C.classify(title: "In Exaltatione Sanctæ Crucis") == .red)
    #expect(C.classify(title: "SS. Apostolorum Petri et Pauli") == .red)
    #expect(C.classify(title: "S. Laurentii Martyris") == .red)
    #expect(C.classify(title: "Ss. Fabiani et Sebastiani Martyrum") == .red)
    #expect(C.classify(title: "S. Marci Evangelistæ") == .red)
}

@Test func whiteFeastsThatAreRealDataNearMissesForBlue() {
    #expect(C.classify(title: "In Nativitate S. Joannis Baptistæ") == .white)
    #expect(C.classify(title: "S. Joseph Sponsi B.M.V. Confessoris") == .white)
    #expect(C.classify(title: "S. Francisci Confessoris") == .white)
    #expect(C.classify(title: "S. Joseph Opificis") == .white)    // 1960-rubrics-specific feast
    #expect(C.classify(title: "Sanctissimi Nominis Jesu") == .white)
    #expect(C.classify(title: "Omnium Sanctorum") == .white)
}

@Test func allSoulsIsBlack() {
    #expect(C.classify(title: "In Commemoratione Omnium Fidelium Defunctorum") == .black)
}

// MARK: - Regex mechanics: branch order, case sensitivity, orthography (Main.t)

@Test func groupA_oneRepresentativeMatchPerBranch() {
    #expect(C.classify(title: "In Nativitate Domini") == .white)    // no keyword matched, default
    #expect(C.classify(title: "Beatae Mariae") == .blue)
    #expect(C.classify(title: "Sanctæ Mariæ") == .blue)             // ae-ligature spelling also recognised
    #expect(C.classify(title: "Officium Defunctorum") == .black)
    #expect(C.classify(title: "In Vigilia Ascensionis Domini") == .white)    // anchored
    #expect(C.classify(title: "Dominica Septuagesima") == .violet)          // "gesim"
    #expect(C.classify(title: "In Dedicatione Ecclesiae") == .white)
    #expect(C.classify(title: "In Festo Pentecosten") == .green)
    // Reachable only via the final red branch's "Innocentium" alternative.
    #expect(C.classify(title: "In Festo Sanctorum Innocentium") == .red)
}

@Test func groupB_branchGuardsAndExceptions() {
    // Blue's Marian pattern is suppressed for a Vigil; falls through to purple's Vigilia.
    #expect(C.classify(title: "In Vigilia Assumptionis Beatae Mariae Virginis") == .violet)
    // Violet's Advent keyword is suppressed by "commemoratione".
    #expect(C.classify(title: "In Commemoratione Adventus Domini") == .white)
    // Violet's Rogation keyword is suppressed by "votivum".
    #expect(C.classify(title: "In festo Rogationis votivum") == .white)
    // Green's negative lookahead only looks forward: "infra octavam" following excludes it...
    #expect(C.classify(title: "In Pentecosten infra octavam") == .white)
    // ...but preceding text does not exclude it.
    #expect(C.classify(title: "Dominica infra octavam Pentecosten") == .green)
}

@Test func groupC_caseSensitivityAndOrthographyQuirks() {
    // Blue's pattern is case-sensitive: all-lowercase falls through.
    #expect(C.classify(title: "beatae mariae") == .white)
    // The anchored white Vigil pattern is case-sensitive too; lowercase falls to violet.
    #expect(C.classify(title: "in vigilia ascensionis") == .violet)
    // Violet's Holy Week pattern only recognises the ae-ligature spelling.
    #expect(C.classify(title: "Feria II Hebdomadæ Sanctæ") == .violet)
    #expect(C.classify(title: "Feria II Hebdomadae Sanctae") == .white)    // plain digraph not recognised
}

@Test func groupD_priorityBetweenBranchesThatCouldBothMatch() {
    // A Marian martyr is blue, not red: blue is checked first.
    #expect(C.classify(title: "In Festo Sanctae Mariae Martyris") == .blue)
    // Our Lady of Sorrows is blue, not violet: blue is checked before violet.
    #expect(C.classify(title: "Septem Dolorum Beatae Mariae Virginis") == .blue)
    // Red's specific "Quattuor Temporum Pentecostes" beats violet's bare "Quattuor"...
    #expect(C.classify(title: "Feria IV Quattuor Temporum Pentecostes") == .red)
    // ...but a bare "Quattuor" with no "Pentecostes" falls through to violet.
    #expect(C.classify(title: "Quattuor Temporum Septembris") == .violet)
    // Red's "Decollatione" beats white's "oann".
    #expect(C.classify(title: "In Decollatione S. Ioannis Baptistae") == .red)
    // Black's "Parasceve" beats violet's "Passion".
    #expect(C.classify(title: "Passionis tempore in Parasceve") == .black)
    // White's "Cathedra" beats red's "Apostol".
    #expect(C.classify(title: "In Cathedra S. Petri Apostoli") == .white)
    // Green's "Pentecosten" (n-ending) and red's "Pentecostes" (s-ending) never overlap.
    #expect(C.classify(title: "Dominica infra octavam Pentecostes") == .red)
}
