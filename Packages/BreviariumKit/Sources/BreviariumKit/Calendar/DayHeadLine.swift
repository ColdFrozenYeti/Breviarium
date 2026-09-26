/// The third line of the title block: what DO prints after the day's name and rank in the
/// page head (`$dayname[2]`), e.g. *Commemoratio ad Laudes tantum: Ss. Euphemiæ, Luciæ et
/// Geminiani Martyrum*, *Tempora: Feria V infra Hebdomadam II post Octavam Pentecostes*,
/// *Scriptura: Sabbato infra Hebdomadam I post Octavam Paschæ*.
///
/// A port of the 1960 branches of `occurrence()`'s `$officename[2]` (`horascommon.pl:
/// 536-800`) and its later clean-up (`:1680-1736`), for the hours from Matins to None.
/// Vespers and Compline show none: DO's own line there is its concurrence note, and the
/// odd *Scriptura* it leaves at Compline describes the morning, not the evening's office.
/// Checked against every fixture's page head by `dayHoursFullRangeHeadLineAudit`.
extension LiturgicalCalendarEngine {
    public func headLine(for hour: CanonicalHour, day: Int, month: Int, year: Int) -> String? {
        guard !hour.followsConcurrence else { return nil }
        let resolver = SectionResolver(corpus: corpus, context: context)
        let occurrence = Occurrence(corpus: corpus, context: context, calendar: sanctoralCalendar)
        guard let result = occurrence.resolve(day: day, month: month, year: year) else { return nil }
        func has(_ text: String, _ pattern: String) -> Bool {
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        func rank(_ path: String) -> OfficeRank? { OfficeRank(rankFieldValue: resolver.resolveRank(path: path)) }
        func rule(_ path: String) -> String { resolver.resolve(path: path, section: "Rule") }
        let dayOfWeek = Computus.dayOfWeek(day: day, month: month, year: year)
        let weekName = TemporalCycle.weekName(day: day, month: month, year: year)

        // The temporal office, titled as `officestring` titles it (with its monthday).
        var tname = Occurrence.temporalPath(
            day: day, month: month, year: year, calendar: sanctoralCalendar, corpus: corpus, context: context
        )
        var trank = rank(tname)
        func temporalTitle(_ path: String, _ rank: OfficeRank) -> String {
            rank.title + HourAssembler.monthdayTitleSuffix(office: path, day: day, month: month, year: year, tomorrow: false)
        }
        let temporalRule = rule(tname)

        // The sanctoral office and the ones after it (`@commemoentries`).
        var entries = sanctoralCalendar.candidates(day: day, month: month, year: year).map { "Sancti/\($0)" }
        // A feast moved away this year (`:228-230`, `transfered()`): the day names it.
        var transfered: String?
        if let first = entries.first, !sanctoralCalendar.hasOwnTransferEntry(day: day, month: month, year: year),
            sanctoralCalendar.isTransferredAwayThisYear(candidateKey: String(first.dropFirst("Sancti/".count)), year: year)
        {
            transfered = first
            entries.removeFirst()
        }
        var sname: String?
        var srank: OfficeRank?
        while !entries.isEmpty {
            let path = entries.removeFirst()
            if let found = rank(path) {
                sname = path
                srank = found
                break
            }
        }
        let t = trank?.numericPrecedence ?? 0
        let tTitle = trank?.title ?? ""
        // `:370-400`, 1960: what the day's rank leaves of the saint or of the season.
        if let s = srank?.numericPrecedence, let sTitle = srank?.title {
            let sunday = dayOfWeek == 0
            let privileged = !has(tTitle, "Dominica(?!.*Trinitatis)|Feria|Sabbato|In Octava")
            if (t >= 6 && s < 6)
                || (privileged && ((t >= 6 && s < 2.1) || (t >= 5 && s == 2 && has(sTitle, "infra octavam|post Octavam Asc|Vigilia Pent"))))
                || (has(sTitle, "vigil") && sunday && month < 12)
                || (has(sTitle, "infra octavam|in octava") && (month < 12 || day < 25))
                || (sunday && ((t >= 6 && s < 6) || (t >= 5 && s < 5)))
            {
                sname = nil
                srank = nil
                entries = []
            } else if (s >= 6 && t < 6 && !([2.1, 3.9, 4.9].contains(t) || has(tTitle, "Dominica")))
                || (has(tTitle, "Dominica") && !weekName.hasPrefix("Nat1") && t <= 5 && s >= 5 && has(rule(sname ?? ""), "Festum Domini"))
            {
                tname = ""
                trank = nil
            }
        }
        // 29-31 December: the octave day of Christmas is the one commemorated (`:450-456`).
        if weekName.hasPrefix("Nat1"), day > 28, month == 12, rank("Tempora/Nat\(day)") != nil {
            sname = "Tempora/Nat\(day)"
            srank = rank("Tempora/Nat\(day)")
        }
        // Our Lady on Saturday (`:423-442`): the season's Scripture is still read.
        var scriptura: String?
        let isOurLady = result.winningPath.hasPrefix("Commune/C10")
        if isOurLady {
            scriptura = tname
        }

        let winner = result.winningPath
        let winnerRule = rule(winner)
        var line = ""
        var commemorated: String?

        if result.sanctoralWins, let sname, winner == sname, let srank {
            let s = srank.numericPrecedence
            let winnerRank = s
            if s < 7, !sname.contains("01-01"), let trank, !tname.isEmpty,
                trank.numericPrecedence >= (s >= 5 ? 2.1 : 1.5),
                !(has(srank.title, "Sangu") && has(trank.title, "Cor[dp]"))
            {
                commemorated = tname
                line = "Commemoratio: \(temporalTitle(tname, trank))"
                if has(tname, #"Pasc5\-[13]"#) {
                    line = line.replacingFirst(":", with: " ad Laudes & Matutinum:")
                } else if has(trank.title, "Quattuor.*Sept") {
                    line = line.replacingFirst(":", with: " ad Laudes tantum:")
                }
            } else if let next = entries.first, let nextRank = rank(next) {
                commemorated = next
                line = "Commemoratio: \(nextRank.title)"
                if nextRank.numericPrecedence < 6 { line = line.replacingFirst(":", with: " ad Laudes tantum:") }
            } else if let transfered, let moved = rank(transfered) {
                line = "Transfer: \(moved.title)"
            }
            // A saint's own commemoration section (`:604-613`).
            if line.isEmpty {
                let section = resolver.sectionExists(path: sname, section: "Commemoratio 2") ? "Commemoratio 2"
                    : resolver.sectionExists(path: sname, section: "Commemoratio") ? "Commemoratio" : nil
                if let section,
                    var first = resolver.unresolvedBody(path: sname, section: section)?.first(where: { !$0.isEmpty })
                {
                    if let match = first.firstMatch(of: /@([A-Za-z0-9\/\-]+?):/) {
                        first = "!Commemoratio " + resolver.resolve(path: String(match.1), section: "Officium")
                    }
                    if first.hasPrefix("!Commemoratio ") {
                        line = "Commemoratio ad Laudes tantum: " + first.dropFirst("!Commemoratio ".count)
                    }
                }
            }
            // The season's Scripture at Matins, or its name when nothing else is said
            // (`:615-652`).
            if hour == .matutinum || line.isEmpty, winnerRank < 7, let trank, !tname.isEmpty {
                line = "Tempora: \(temporalTitle(tname, trank))"
                scriptura = tname
                // A Scripture transfer (`initiarule`) names the Sunday whose Scripture is
                // read; DO's page head shows it at Matins only (`webdia.pl:988-996`).
                let saintLectio = resolver.sectionExists(path: sname, section: "Lectio1")
                    && (!has(rule(sname), "Lectio1 Quad") || has(tname, #"Quad(\d|p3\-[3456])"#))
                let scrip = resolver.resolve(path: tname, section: "Lectio1")
                if hour == .matutinum, !saintLectio, resolver.sectionExists(path: tname, section: "Lectio1"),
                    !has(scrip, "evangelii"), !has(resolver.resolveRank(path: sname), ";;ex ") || has(rule(sname), "Lectio1 temp"),
                    let table = sanctoralCalendar.scriptureTransfer(day: day, month: month, year: year), !table.hasSuffix("~A"),
                    let first = table.split(separator: "~").first
                {
                    let tsfile = "Tempora/\(first)"
                    if tsfile != tname, let tsrank = rank(tsfile) {
                        line += "\nScriptura ut in \(tsrank.title)"
                    }
                }
            }
        } else if !result.sanctoralWins || isOurLady {
            // The season wins (`:653-800`).
            let winnerRank = result.winningRank.numericPrecedence
            let winnerRankLine = resolver.resolveRank(path: winner)
            func climit(_ c: String?) -> Int {
                guard let c, !c.isEmpty else { return 0 }
                guard c.hasPrefix("Sancti") else { return 1 }
                if c.contains("7-16"), winner.contains("C10") { return 0 }
                guard has(winner, "tempora|C10") else { return 1 }
                let r = rank(c)?.numericPrecedence ?? 0
                if has(winnerRankLine, "Dominica") {
                    if r >= 5 { return 1 }    // `$hora !~ /Vespera|Completorium/`: always here
                    if hour == .laudes, r >= 5, winnerRank < 6 { return 1 }
                } else if r >= 6 {
                    return 1
                } else if r > 1 {
                    return 2
                }
                return 0
            }
            let omits = has(temporalRule, "omit.*? commemoratio") || has(temporalRule, "No commemoratio")
            let limit = climit(sname)
            var laudesOnly: String
            if let srank, has(srank.title, "vigil"), !has(srank.title, "Epiph") {
                laudesOnly = has(weekName, "Adv|Quad[0-6]") || (weekName.hasPrefix("Quadp3") && dayOfWeek >= 4) || has(tTitle, "Quattuor Temporum Sept")
                    ? " ad Missam tantum" : " ad Laudes tantum"
            } else {
                laudesOnly = limit == 2 ? " ad Laudes tantum" : ""
            }
            if let sname, let srank, limit > 0, !omits {
                commemorated = sname
                let comm = srank.title.hasPrefix("In Commemoratione") ? "" : "Commemoratio:"
                line = "\(comm) \(srank.title)"
                if (t >= 5 && srank.numericPrecedence < 2) || limit == 2 { line = line.replacingFirst(":", with: "\(laudesOnly):") }
                if has(line, "[IJ]anuarii") { line = "" }    // `/Januarii/`, our text I-spelled
            } else if let next = entries.first, !omits, let nextRank = rank(next) {
                let nextLimit = climit(next)
                if nextLimit > 0 {
                    commemorated = next
                    laudesOnly = nextLimit == 2 ? " ad Laudes tantum" : ""
                    line = "Commemoratio: \(nextRank.title)"
                    if (t >= 5 && nextRank.numericPrecedence < 2) || nextLimit == 2 { line = line.replacingFirst(":", with: "\(laudesOnly):") }
                }
            } else if let transfered, let moved = rank(transfered) {
                line = "Transfer: \(moved.title)"
            }
        }

        // The clean-up after occurrence (`:1680-1736`).
        if winner.hasPrefix("Sancti"), has(winnerRule, "Tempora none") {
            line = ""
            scriptura = nil
        }
        if has(winnerRule, "No Sunday commemoratio"), dayOfWeek == 0 { line = "" }
        if let commemorated {
            if has(winnerRule, "Festum Domini"), has(rule(commemorated), "Festum Domini") { line = "" }
            if commemorated.range(of: #"06-28r?"#, options: .regularExpression) != nil, dayOfWeek == 0 { line = "" }
        }
        if line.isEmpty, let scriptura, !scriptura.isEmpty, !has(scriptura, "Nat0[12345]"), let scripturaRank = rank(scriptura) {
            line = "Scriptura: \(temporalTitle(scriptura, scripturaRank))"
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    func replacingFirst(_ target: String, with replacement: String) -> String {
        guard let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}
