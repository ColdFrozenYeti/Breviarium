import Testing
@testable import BreviariumKit

@Test func splitsSectionsCorrectlyWithCRLFLineEndings() {
    // A Windows checkout (CRLF) would otherwise collapse into one "line": Swift's
    // Character view treats "\r\n" as a single grapheme cluster, so naive
    // split(separator: "\n") finds no boundary inside it. Real DO files can have
    // either line ending depending on checkout settings, so both must parse the same.
    let text = "[Officium]\r\nCathedræ S. Petri Romæ\r\n\r\n[Rank]\r\n;;Duplex majus;;4;;ex C4"
    let file = RawSectionParser.parse(fileText: text, path: "Sancti/01-18.txt")

    #expect(file.sections.count == 2)
    #expect(file.sections[0].body == ["Cathedræ S. Petri Romæ", ""])
    #expect(file.sections[1].body == [";;Duplex majus;;4;;ex C4"])
}

@Test func splitsUnconditionedSections() {
    let text = """
        [Officium]
        Cathedræ S. Petri Romæ

        [Rank]
        ;;Duplex majus;;4;;ex C4
        """
    let file = RawSectionParser.parse(fileText: text, path: "Sancti/01-18.txt")

    #expect(file.sections.count == 2)
    #expect(file.sections[0].name == "Officium")
    #expect(file.sections[0].condition == "")
    #expect(file.sections[0].body == ["Cathedræ S. Petri Romæ", ""])
    #expect(file.sections[1].name == "Rank")
    #expect(file.sections[1].body == [";;Duplex majus;;4;;ex C4"])
}

@Test func preservesConditionedHeaderVariants() {
    let text = """
        [Festa]
        none
        Simplex

        [Festa] (rubrica 196)
        Feria
        IV. classis
        """
    let file = RawSectionParser.parse(fileText: text, path: "Psalterium/Comment.txt")

    let festaSections = file.sections.filter { $0.name == "Festa" }
    #expect(festaSections.count == 2)
    #expect(festaSections[0].condition == "")
    #expect(festaSections[1].condition == "rubrica 196")
    #expect(festaSections[1].body.first == "Feria")
}

@Test func discardsPreambleContent() {
    let text = """
        This is preamble text before any section.

        [Officium]
        Real content.
        """
    let file = RawSectionParser.parse(fileText: text, path: "Sancti/06-29.txt")

    #expect(file.sections.count == 1)
    #expect(file.sections[0].name == "Officium")
}

@Test func qualifiesBareSelfReferences() {
    let text = """
        [Ant Vespera]
        @:Ant Laudes
        @Sancti/02-22
        @Sancti/02-22:Oratio
        """
    let file = RawSectionParser.parse(fileText: text, path: "Sancti/01-18r.txt")

    let body = file.sections[0].body
    #expect(body[0] == "@Sancti/01-18r:Ant Laudes")    // filename filled in, keyword kept
    #expect(body[1] == "@Sancti/02-22:Ant Vespera")    // keyword filled in with current section
    #expect(body[2] == "@Sancti/02-22:Oratio")         // fully qualified already: unchanged
}
