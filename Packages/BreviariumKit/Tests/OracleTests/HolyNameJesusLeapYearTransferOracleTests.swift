import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the Versus category pass): `Directorium.pm`'s
// own `load_transfers` (lines 141-162) loads a *second* letter transfer file in leap
// years -- `push(@lines, load_transfer_file($letters[$letter - 6], 2, ...))`, inside its
// own `if ($isleap)` branch. Perl's negative array index wraps from the end, so
// `$letters[$letter - 6]` is really `$letters[$letter + 1]` (mod 7), pushed *after* the
// primary letter/numeric files and so winning any key both define. This project's
// `SanctoralCalendar.transferSource` only ever consulted the one primary letter file,
// missing this leap-year extension entirely -- so in a leap year, whichever January date
// the *extra* letter file alone redirects (never the primary one) fell through to the
// plain, non-transferred temporal path instead.
//
// Confirmed real for 4 January 2032 and 2 January 2036 (both leap years, both
// "Sanctissimi Nominis Jesu ~ II. classis", the Sunday between 1 January and Epiphany):
// the primary letter computed for both years is "c" (`Transfer/c.txt` only redirects
// `01-03`), but `Transfer/d.txt`'s own `"01-04=Tempora/Nat2-0"` (reached only via this
// leap-year extension) is what actually applies -- this project's engine had been
// resolving straight to `Tempora/Nat04` (the plain day-numbered file, titled for the
// ordinary weekday within the Nativity octave season), missing the redirect to
// `Tempora/Nat2-0` (the week-numbered Sunday file that carries Holy Name of Jesus' own
// proper texts under 1960 rubrics) entirely.

@Test func holyNameOfJesusWinsOnTheSundayInALeapYear() async throws {
    // 4 January 2032 (a Sunday, leap year). Real fixture: "Sanctissimi Nominis Jesu ~ II.
    // classis" with Hymnus "Iesu, dulcis memória..." and Versus "Sit nomen Dómini
    // benedíctum, allelúia. / Ex hoc nunc et usque in sǽculum, allelúia." -- reached via
    // `Tempora/Nat2-0`, not the plain `Tempora/Nat04` this project's engine previously
    // resolved to (which has no Holy Name content at all).
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 4, month: 1, year: 2032, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 4, month: 1, year: 2032, priest: false))

    let versus = try #require(hour.sections.first { $0.kind == .versus })
    let pairs = versus.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(pairs.contains { $0.0.contains("Sit nomen Dómini benedíctum") })

    let hymnus = try #require(hour.sections.first { $0.kind == .hymnus })
    let hymnusText = hymnus.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }.joined()
    #expect(hymnusText.contains("Iesu, dulcis memória"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2032, date: "2032-01-04"))
    #expect(fixture.contains("Sanctissimi Nominis Jesu"))
    #expect(fixture.contains("Sit nomen Dómini benedíctum"))
}

@Test func holyNameOfJesusWinsOnTheSundayInASecondLeapYear() async throws {
    // 2 January 2036 (also a Sunday, also a leap year) -- confirms the fix generalizes
    // beyond the single 2032 date, with a different computed primary letter for its own
    // Easter, still needing the same leap-year extension.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 2, month: 1, year: 2036, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 2, month: 1, year: 2036, priest: false))

    let versus = try #require(hour.sections.first { $0.kind == .versus })
    let pairs = versus.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(pairs.contains { $0.0.contains("Sit nomen Dómini benedíctum") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2036, date: "2036-01-02"))
    #expect(fixture.contains("Sanctissimi Nominis Jesu"))
    #expect(fixture.contains("Sit nomen Dómini benedíctum"))
}
