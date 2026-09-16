import Testing
@testable import BreviariumKit

private func vesperaContext(rubrica: String, feria: Int = 1) -> ConditionalContext {
    ConditionalContext(rubrica: rubrica, tempore: "Adventus", feria: feria, ad: "vesperas", mense: 12)
}

@Test func plainLinesPassThroughUnconditioned() {
    let lines = ["Ecce nomen Domini.", "", "Venit de longinquo."]
    let result = ConditionalLineProcessor.resolve(lines: lines, context: vesperaContext(rubrica: "Rubrics 1960 - 1960"))
    #expect(result == lines)
}

@Test func realExample_omittiturUnderTridentineKeepsUnder1960() {
    // From web/www/horas/Latin/Tempora/Adv1-0.txt's [Ant Vespera]:
    //   @:Ant Laudes
    //   (sed rubrica tridentina aut rubrica praedicatorum omittuntur)
    // Under 1960 rubrics neither branch holds, so "omittuntur" doesn't apply and the
    // antiphon reference survives.
    let lines = ["@:Ant Laudes", "(sed rubrica tridentina aut rubrica praedicatorum omittuntur)"]
    let result = ConditionalLineProcessor.resolve(lines: lines, context: vesperaContext(rubrica: "Rubrics 1960 - 1960"))
    #expect(result == ["@:Ant Laudes"])
}

@Test func realExample_omittiturUnderTridentineActuallyOmits() {
    // Same fragment, but under Tridentine rubrics the condition holds, so "omittuntur"
    // (SCOPE_NEST backward) deletes the antiphon reference entirely.
    let lines = ["@:Ant Laudes", "(sed rubrica tridentina aut rubrica praedicatorum omittuntur)"]
    let result = ConditionalLineProcessor.resolve(lines: lines, context: vesperaContext(rubrica: "Tridentine - 1570"))
    #expect(result.isEmpty)
}

@Test func sedWithNoScopePhraseReplacesOnlyThePrecedingLine() {
    // "(sed X) Bar" with no explicit scope phrase gets implicit SCOPE_LINE from "sed":
    // when X holds, it removes just the single preceding line and the clause's own
    // trailing text ("Bar") becomes the new content.
    let lines = ["Foo", "(sed rubrica 196) Bar"]
    let result = ConditionalLineProcessor.resolve(lines: lines, context: vesperaContext(rubrica: "Rubrics 1960 - 1960"))
    #expect(result == ["Bar"])
}

@Test func sedWithFalseConditionLeavesPrecedingLineIntact() {
    let lines = ["Foo", "(sed rubrica 196) Bar"]
    let result = ConditionalLineProcessor.resolve(lines: lines, context: vesperaContext(rubrica: "Tridentine - 1570"))
    // Condition false: "(sed rubrica 196)" doesn't hold for Tridentine, so its trailing
    // text is simply dropped (nothing to add), and "Foo" is never touched.
    #expect(result == ["Foo"])
}
