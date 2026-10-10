/// The fixed sample the Theme and Font galleries preview (1.2, `docs/1.2_plan.md` §4):
/// Easter Sunday's antiphon at the *Magnificat* (second Vespers, `Tempora/Pasc0-0`'s
/// `[Ant 3]`, *Et respiciéntes…*), then the canticle's first two verses (the Vulgate's
/// `Psalm232`, verses 46 and 47). It is read from the bundled data, never typed into the
/// app, and is the same on every day: it doesn't follow the date, rite, office, psalter,
/// priest or English settings.
public enum GallerySample {
    static let antiphonPath = "Tempora/Pasc0-0"
    static let antiphonSection = "Ant 3"
    static let canticlePath = "Psalterium/Psalmorum/Psalm232"

    /// The antiphon, then the first two verses; a part missing from `corpus` is left out.
    public static func units(corpus: OfficeCorpus) -> [Unit] {
        // Easter Sunday under the 1960 rubrics; neither section has a conditional in
        // Divinum Officium, so the context only has to be a plausible one.
        let context = ConditionalContext(
            rubrica: "Rubrics 1960 - 1960", tempore: "Octava Paschæ", feria: 1, ad: "vesperas", mense: 4
        )
        let resolver = SectionResolver(corpus: corpus, context: context)
        var units: [Unit] = []
        if resolver.sectionExists(path: antiphonPath, section: antiphonSection) {
            let antiphon = resolver.resolve(path: antiphonPath, section: antiphonSection)
                .split(separator: "\n").map(String.init).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if let antiphon { units.append(.antiphon(antiphon)) }
        }
        guard resolver.sectionExists(path: canticlePath, section: RawSectionParser.wholeFileSectionName) else { return units }
        let text = resolver.resolvePsalmText(path: canticlePath, section: RawSectionParser.wholeFileSectionName)
        let verses = Psalm.parseVerses(text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        for verse in verses.prefix(2) {
            let shown = Psalm.displayReference(verse)
            units.append(.verse(reference: shown.reference, firstHalf: shown.firstHalf, secondHalf: shown.secondHalf))
        }
        return units
    }
}
