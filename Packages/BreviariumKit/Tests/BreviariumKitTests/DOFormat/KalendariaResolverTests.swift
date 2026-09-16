import Testing
@testable import BreviariumKit

@Test func parsesDataLinesSkippingHeadersAndComments() {
    // Real excerpt from web/www/Tabulae/Kalendaria/1960.txt.
    let text = """
        #This file only notes the changes to Reduced - 1955
        *January*
        01-18=01-18r=S Priscae Virginis=1=
        01-25=01-25r=In Conversione S. Pauli Apostoli=4=
        *February*
        *March*
        #identical to 1955=
        *April*
        04-28=04-28=S. Pauli a Cruce Confessoris=3=
        """
    let entries = KalendariaResolver.parseEntries(text)
    #expect(entries.count == 3)
    #expect(entries["01-18"] == "01-18r")
    #expect(entries["01-25"] == "01-25r")
    #expect(entries["04-28"] == "04-28")
}

@Test func parsesRemovalSentinel() {
    let text = "05-06=XXXXX\n05-08=XXXXX"
    let entries = KalendariaResolver.parseEntries(text)
    #expect(entries["05-06"] == "XXXXX")
    #expect(KalendariaResolver.isRemovalSentinel(entries["05-06"] ?? ""))
}

@Test func flattenAppliesChainMostSpecificLast() {
    // A date only in the base survives untouched...
    let base = "01-01=01-01=Circumcisio=3="
    // ...a date the middle version doesn't touch survives past it too...
    let middle = "02-14=02-14=Some Feast=2="
    // ...and the most specific version's entry -- even a removal -- wins over both.
    let mostSpecific = "01-01=XXXXX"

    let merged = KalendariaResolver.flatten(textsOldestFirst: [base, middle, mostSpecific])

    #expect(merged["01-01"] == "XXXXX")    // overridden by the most specific file
    #expect(merged["02-14"] == "02-14")    // untouched, survives from the middle file
}

@Test func laterFileCanReAddADateARemovalDropped() {
    // Order matters: if a later file re-adds a date an earlier one removed, the later
    // (more specific) entry should win, same as any other override.
    let removedByMiddle = "06-17=XXXXX"
    let reAddedByLatest = "06-17=06-17r=Some Feast=3="

    let merged = KalendariaResolver.flatten(textsOldestFirst: [removedByMiddle, reAddedByLatest])
    #expect(merged["06-17"] == "06-17r")
}
