import Testing
@testable import BreviariumKit

private func vesperaContext(
    rubrica: String = "Rubrics 1960 - 1960",
    tempore: String = "post Pentecosten",
    feria: Int = 1
) -> ConditionalContext {
    ConditionalContext(rubrica: rubrica, tempore: tempore, feria: feria, ad: "vesperas", mense: 9)
}

@Test func emptyConditionIsAlwaysTrue() {
    #expect(ConditionalEvaluator.evaluate("", context: vesperaContext()))
    #expect(ConditionalEvaluator.evaluate("   ", context: vesperaContext()))
}

@Test func rubricaSubjectMatchesRegexFallbackPredicate() {
    // "rubrica 196" -- "196" isn't a known predicate name, so it falls back to being
    // tested as a case-insensitive regex against $version (SetupString.pl:290-294).
    #expect(ConditionalEvaluator.evaluate("rubrica 196", context: vesperaContext()))
    #expect(ConditionalEvaluator.evaluate("rubrica 1960", context: vesperaContext()))
    #expect(!ConditionalEvaluator.evaluate("rubrica 1955", context: vesperaContext()))
}

@Test func knownPredicateTridentina() {
    let trident = vesperaContext(rubrica: "Tridentine - 1570")
    #expect(ConditionalEvaluator.evaluate("rubrica tridentina", context: trident))
    #expect(!ConditionalEvaluator.evaluate("rubrica tridentina", context: vesperaContext()))
}

@Test func autAlternationSucceedsIfEitherBranchHolds() {
    // "(sed rubrica tridentina aut rubrica praedicatorum omittuntur)" style condition,
    // from web/www/horas/Latin/Tempora/Adv1-0.txt's [Ant Vespera].
    let condition = "rubrica tridentina aut rubrica praedicatorum"
    #expect(ConditionalEvaluator.evaluate(condition, context: vesperaContext(rubrica: "Tridentine - 1570")))
    #expect(!ConditionalEvaluator.evaluate(condition, context: vesperaContext(rubrica: "Rubrics 1960 - 1960")))
}

@Test func etConjunctionRequiresBothClauses() {
    let context = vesperaContext(rubrica: "Rubrics 1960 - 1960", feria: 1)
    #expect(ConditionalEvaluator.evaluate("rubrica 196 et feria 1", context: context))
    #expect(!ConditionalEvaluator.evaluate("rubrica 196 et feria 2", context: context))
}

@Test func nisiNegatesTheFollowingClause() {
    let context = vesperaContext(rubrica: "Rubrics 1960 - 1960", feria: 3)
    // "rubrica 196 nisi feria 1" = true when rubrica matches AND feria isn't 1.
    #expect(ConditionalEvaluator.evaluate("rubrica 196 nisi feria 1", context: context))
    #expect(!ConditionalEvaluator.evaluate("rubrica 196 nisi feria 3", context: context))
}

@Test func subjectlessClauseDefaultsToTempore() {
    let context = vesperaContext(tempore: "Adventus")
    // A single-word clause with no recognised subject falls back to "tempore <word>".
    #expect(ConditionalEvaluator.evaluate("Adventus", context: context))
    #expect(!ConditionalEvaluator.evaluate("Adventus", context: vesperaContext(tempore: "post Pentecosten")))
}

@Test func unrecognisedSubjectFailsItsAutBranch() {
    // "tonus" isn't a subject ConditionalContext supports (GABC-only) -- the clause
    // should fail cleanly rather than crash, matching vero()'s "unless $subject" guard.
    #expect(!ConditionalEvaluator.evaluate("tonus solemnis", context: vesperaContext()))
}

@Test func multiWordPredicateWithImplicitSubject() {
    // "post septuagesimam" is itself a two-word predicate name with no explicit
    // subject -- should fall back to subject "tempore" (SetupString.pl:282-288).
    #expect(ConditionalEvaluator.evaluate("post septuagesimam", context: vesperaContext(tempore: "Septuagesimæ")))
    #expect(!ConditionalEvaluator.evaluate("post septuagesimam", context: vesperaContext(tempore: "Adventus")))
}
