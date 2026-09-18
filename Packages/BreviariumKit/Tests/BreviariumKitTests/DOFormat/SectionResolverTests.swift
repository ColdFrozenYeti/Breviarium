import Testing
@testable import BreviariumKit

private func vesperaContext(rubrica: String = "Rubrics 1960 - 1960") -> ConditionalContext {
    ConditionalContext(rubrica: rubrica, tempore: "Adventus", feria: 1, ad: "vesperas", mense: 12)
}

@Test func resolvesPlainUnconditionedSection() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Sancti/01-18r.txt", sections: [
            RawSection(name: "Oratio", condition: "", body: ["Da, quaesumus, omnipotens Deus."])
        ])
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/01-18r.txt", section: "Oratio") == "Da, quaesumus, omnipotens Deus.")
}

@Test func resolvePsalmTextDoesNotLoseTheFirstVerseAfterALeadingTitleComment() {
    // Real bug, found via the bilingual oracle fixture for 16 September 2026:
    // Psalm232.txt's own leading "(Canticum B. Mariæ Virginis * Luc. 1:46-55)"
    // title-comment line -- passed through the *general* `resolve()` (which runs
    // ConditionalLineProcessor) -- gets misparsed as a `(condition)` clause with a
    // false, unrecognised "condition" and a default forward scope of one line,
    // silently swallowing the psalm's own first verse. `resolvePsalmText` (which
    // psalm/canticle lookups must use instead) reads the raw body directly, matching
    // DO's own real behaviour of never running psalm/canticle files through
    // conditional-line processing at all (`horasscripts.pl:552`'s plain `do_read`).
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Psalterium/Psalmorum/Psalm232.txt", sections: [
            RawSection(name: RawSectionParser.wholeFileSectionName, condition: "", body: [
                "(Canticum B. Mariæ Virginis * Luc. 1:46-55)",
                "1:46 Magnificat * anima mea Dominum.",
                "1:47 Et exsultavit spiritus meus * in Deo salvatore meo.",
            ])
        ])
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    let resolvedGenerically = resolver.resolve(path: "Psalterium/Psalmorum/Psalm232", section: RawSectionParser.wholeFileSectionName)
    #expect(!resolvedGenerically.contains("1:46"), "documents the bug: the general resolver path does lose \"1:46\"")

    let resolvedAsPsalmText = resolver.resolvePsalmText(path: "Psalterium/Psalmorum/Psalm232", section: RawSectionParser.wholeFileSectionName)
    #expect(resolvedAsPsalmText.contains("1:46 Magnificat * anima mea Dominum."))
    #expect(resolvedAsPsalmText.contains("1:47 Et exsultavit spiritus meus * in Deo salvatore meo."))
}

@Test func resolvesTheRubricaSigilFromRubricaeTxtWithNoPrefixInTheLookupKey() {
    // $rubrica Secreto looks up the bare name "Secreto" in Rubricae.txt -- confirmed
    // against the real file's own header naming ("[Pater secreto]", no "rubrica " prefix).
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Ordinarium/Vespera.txt", sections: [
            RawSection(name: "Incipit", condition: "", body: ["$rubrica Secreto"])
        ]),
        RawOfficeFile(path: "Psalterium/Common/Rubricae.txt", sections: [
            RawSection(name: "Secreto", condition: "", body: ["Deinde dicuntur secreto."])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Ordinarium/Vespera.txt", section: "Incipit") == "Deinde dicuntur secreto.")
}

@Test func resolvesThePrecesSigilFromPrecesTxtWithThePrefixRetainedInTheLookupKey() {
    // $Preces feriales Vespera looks up "Preces feriales Vespera" (prefix retained) in
    // Preces.txt -- confirmed against the real file's own header naming ("[Preces
    // feriales Vespera]"), and against tracing why that section's own body can safely
    // name itself ($Preces feriales Vespera would recurse if this dispatched back to
    // the same $Name/Prayers.txt path instead of this separate one).
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Ordinarium/Vespera.txt", sections: [
            RawSection(name: "Preces Feriales", condition: "", body: ["$Preces feriales Vespera"])
        ]),
        RawOfficeFile(path: "Psalterium/Special/Preces.txt", sections: [
            RawSection(name: "Preces feriales Vespera", condition: "", body: ["V. Ego dixi.", "R. Sana animam meam."])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Ordinarium/Vespera.txt", section: "Preces Feriales") == "V. Ego dixi.\nR. Sana animam meam.")
}

@Test func resolveRankFillsTitleFromOfficiumWhenOfficiumExists() {
    // Real DO Tempora/Sancti files leave [Rank]'s leading field empty on disk (do-format.md)
    // -- SetupString.pl's own safeguard substitution fills it from [Officium] at load time.
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Epi1-6.txt", sections: [
            RawSection(name: "Officium", condition: "", body: ["Feria VI infra Hebdomadam I post Epiphaniam"]),
            RawSection(name: "Rank", condition: "", body: [";;Feria;;1"]),
        ])
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(
        resolver.resolveRank(path: "Tempora/Epi1-6.txt")
            == "Feria VI infra Hebdomadam I post Epiphaniam;;Feria;;1"
    )
}

@Test func resolveRankLeavesTitleAloneWithoutAnOfficiumSection() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Epi1-6.txt", sections: [
            RawSection(name: "Rank", condition: "", body: [";;Feria;;1"])
        ])
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolveRank(path: "Tempora/Epi1-6.txt") == ";;Feria;;1")
}

@Test func resolvesCrossFileInclusion() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Sancti/01-18r.txt", sections: [
            RawSection(name: "Hymnus Vespera", condition: "", body: ["@Sancti/02-22:Hymnus Vespera"])
        ]),
        RawOfficeFile(path: "Sancti/02-22.txt", sections: [
            RawSection(name: "Hymnus Vespera", condition: "", body: ["Iste confessor Domini sacratus."])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/01-18r.txt", section: "Hymnus Vespera") == "Iste confessor Domini sacratus.")
}

@Test func resolvesPrayerMacro() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Adv1-0.txt", sections: [
            RawSection(name: "Oratio", condition: "", body: ["Excita, quaesumus, Domine.", "$Per Dominum"])
        ]),
        RawOfficeFile(path: SectionResolver.prayersPath, sections: [
            RawSection(name: "Per Dominum", condition: "", body: [
                "r. Per Dominum nostrum Jesum Christum.", "R. Amen.",
            ])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    let result = resolver.resolve(path: "Tempora/Adv1-0.txt", section: "Oratio")
    #expect(result == "Excita, quaesumus, Domine.\nr. Per Dominum nostrum Jesum Christum.\nR. Amen.")
}

@Test func resolvesAPrayerMacroWithATrailingSentenceFinalPeriod() {
    // Real-world example: Commune/C3.txt's Oratio ends with the literal line
    // "$Per Dominum." (sentence-final period), but Prayers.txt's own header is
    // "[Per Dominum]", no period -- confirmed missing against real bundled data
    // before this fix.
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Commune/C3.txt", sections: [
            RawSection(name: "Oratio", condition: "", body: ["Beatorum Martyrum.", "$Per Dominum."])
        ]),
        RawOfficeFile(path: SectionResolver.prayersPath, sections: [
            RawSection(name: "Per Dominum", condition: "", body: ["r. Per Dominum nostrum Jesum Christum."])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    let result = resolver.resolve(path: "Commune/C3.txt", section: "Oratio")
    #expect(result == "Beatorum Martyrum.\nr. Per Dominum nostrum Jesum Christum.")
}

@Test func pickesLastTrueConditionedVariant() {
    // Mirrors setupstring_parse_file's hash-overwrite semantics: later matching
    // headers win over earlier ones, matching DO's own load-time behaviour.
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Psalterium/Comment.txt", sections: [
            RawSection(name: "Festa", condition: "", body: ["Simplex"]),
            RawSection(name: "Festa", condition: "rubrica 196", body: ["IV. classis"]),
        ])
    ])
    let resolver1960 = SectionResolver(corpus: corpus, context: vesperaContext(rubrica: "Rubrics 1960 - 1960"))
    #expect(resolver1960.resolve(path: "Psalterium/Comment.txt", section: "Festa") == "IV. classis")

    let resolverTrident = SectionResolver(corpus: corpus, context: vesperaContext(rubrica: "Tridentine - 1570"))
    #expect(resolverTrident.resolve(path: "Psalterium/Comment.txt", section: "Festa") == "Simplex")
}

@Test func missingSectionReportsClearly() {
    let corpus = InMemoryOfficeCorpus(files: [])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/99-99.txt", section: "Oratio") == "Sancti/99-99.txt:Oratio is missing!")
}

@Test func lineRangeSubstitutionSelectsOnlyThoseLines() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Commune/C3.txt", sections: [
            RawSection(name: "Lectio1", condition: "", body: ["Line one.", "Line two.", "Line three.", "Line four."])
        ]),
        RawOfficeFile(path: "Sancti/06-29.txt", sections: [
            RawSection(name: "Lectio1", condition: "", body: ["@Commune/C3:Lectio1:2-3"])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/06-29.txt", section: "Lectio1") == "Line two.\nLine three.")
}

@Test func negatedLineSelectionExcludesThatRange() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Commune/C3.txt", sections: [
            RawSection(name: "Lectio1", condition: "", body: ["Line one.", "Line two.", "Line three."])
        ]),
        RawOfficeFile(path: "Sancti/06-29.txt", sections: [
            RawSection(name: "Lectio1", condition: "", body: ["@Commune/C3:Lectio1:!2"])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/06-29.txt", section: "Lectio1") == "Line one.\nLine three.")
}
