import Foundation

// Beta 3: Matins (`Ad Matutinum`), a port of the 1960 Roman paths of
// `web/cgi-bin/horas/specmatins.pl`, which `docs/rubrics-1960-matins.md` describes
// section by section. `HourAssembler.assemble(.matutinum, …)` walks
// `Ordinarium/Matutinum.txt` and calls these for its three Matins-only groups:
// `#Invitatorium`, `#Hymnus` and `#Psalmi cum lectionibus`. The Incipit, Oratio and
// Conclusio go through the code the other hours share.

extension HourAssembler {

    /// `specmatins.pl:15-22`: the 1960 lesson types that `gettype1960` returns.
    enum MatinsLessonType: Equatable {
        case defaultType, ferial, sunday, sanctoral, octaveII
    }

    /// What every Matins routine reads from DO's globals.
    struct MatinsDay {
        var winner: OccurrenceResult
        /// `$rule`.
        var rule: String
        /// `$rank`.
        var rank: Double
        /// `$dayname[1]`: the office's title and its rank's name (`horascommon.pl:518`).
        var dayname1: String
        /// `$dayname[0]`.
        var weekName: String
        var dayOfWeek: Int
        var day: Int
        var month: Int
        var year: Int
        /// `$scriptura`: the temporal office whose lessons a saint's day reads in its first
        /// nocturn (`horascommon.pl:622-659`, `:431`), when a saint (or Our Lady on
        /// Saturday) wins.
        var scriptura: String?
        var lessonType: MatinsLessonType
        /// `%commune`'s path (`vide` or `ex`) and whether it's `ex`.
        var commune: String?
        var communeIsEx: Bool
        /// `$commune{Rule}` (Latin).
        var communeRule: String
        /// `initiarule`: the Scripture transfer for the date, and `$initia`, whether the
        /// day's own Scripture begins a book (`horascommon.pl:187`).
        var scriptureTransfer: String?
        var initia: Bool

        var office: String { winner.winningPath }
        var paschal: Bool { weekName.range(of: "Pasc", options: .caseInsensitive) != nil }
    }

    /// `gettype1960` (`specmatins.pl:1455-1487`) for `Rubrics 1960`.
    static func matinsLessonType(dayname1: String, rank: Double, office: String, rule: String) -> MatinsLessonType {
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        var type = MatinsLessonType.defaultType
        if has(dayname1, "post Nativitatem") {
            type = .octaveII
        } else if rank < 2 || has(dayname1, "(feria|vigilia|die)") {
            type = .ferial
        } else if has(dayname1, "dominica.*?semiduplex") || has(office, #"Pasc1\-0"#) {
            type = .sunday
        } else if rank < 5 {
            type = .sanctoral
        }
        if has(rule, "9 lectiones 1960|12 lectiones") { type = .defaultType }
        return type
    }

    func matinsDay(winner: OccurrenceResult, macroContext: MacroContext, resolver: SectionResolver, day: Int, month: Int, year: Int) -> MatinsDay {
        let office = winner.winningPath
        let rank = winner.winningRank.numericPrecedence
        let dayname1 = "\(winner.winningRank.title) \(winner.winningRank.degreeLabel)"
        let rule = macroContext.winningRule
        // `$scriptura`: the day's temporal office when a saint (or Our Lady on Saturday)
        // wins below rank 7.
        var scriptura: String?
        if !office.hasPrefix("Tempora"), rank < 7 {
            let path = Occurrence.temporalPath(day: day, month: month, year: year, calendar: calendar, corpus: corpus, context: context)
            if resolver.sectionExists(path: path, section: "Rank") { scriptura = path }
        }
        let reference = winner.winningRank.communeReference
        let commune = reference.isEmpty ? nil : Self.paschalCommuneFallbackPath(reference, weekName: macroContext.weekName, resolver: resolver)
        return MatinsDay(
            winner: winner, rule: rule, rank: rank, dayname1: dayname1, weekName: macroContext.weekName, dayOfWeek: macroContext.dayOfWeek,
            day: day, month: month, year: year, scriptura: scriptura,
            lessonType: Self.matinsLessonType(dayname1: dayname1, rank: rank, office: office, rule: rule),
            commune: commune, communeIsEx: reference.lowercased().hasPrefix("ex") || office.hasPrefix("Commune/C10"),
            communeRule: commune.map { resolver.resolve(path: $0, section: "Rule") } ?? "",
            scriptureTransfer: calendar.scriptureTransfer(day: day, month: month, year: year),
            initia: resolver.resolve(
                path: Occurrence.temporalPath(day: day, month: month, year: year, calendar: calendar, corpus: corpus, context: context),
                section: "Lectio1"
            ).range(of: #"!.*? 1:1-"#, options: .regularExpression) != nil
        )
    }

    // MARK: - Invitatorium

    /// `invitatorium` (`specmatins.pl:26-148`): Psalm 94 with the day's antiphon, whole
    /// (`$ant`) and halved (`$ant2`, after the `*`).
    func assembleInvitatorium(
        matins: MatinsDay, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section? {
        let special = "Psalterium/Special/Matutinum Special"
        var season = Self.tempora(
            caller: "Invitatorium", weekName: matins.weekName, dayOfWeek: matins.dayOfWeek, day: macroContext.officeDay,
            officeTitle: matins.winner.winningRank.title
        )
        if matins.weekName.range(of: "^Adv[34]$", options: .regularExpression) != nil { season = "Adv3" }
        let name = season.isEmpty ? "Invit" : "Invit \(season)"
        var index = name == "Invit" ? matins.dayOfWeek : 0
        if index == 0, name == "Invit" {
            let monthday = Computus.monthday(day: matins.day, month: matins.month, year: matins.year, tomorrow: false) ?? ""
            if matins.month < 4 || monthday.range(of: #"^1[0-9][0-9]\-"#, options: .regularExpression) != nil { index = 7 }
        }
        let proper = proprium("Invit", flag: true, winner: matins.winner, resolver: resolver, weekName: matins.weekName)

        // The English office's own `[Invit]` wins, as DO reads it from the English winner
        // (`%winner2`): St Jane Frances's, St Raphael's.
        let englishProper = englishResolver.flatMap {
            proprium("Invit", flag: true, winner: matins.winner, resolver: $0, weekName: matins.weekName)
        }
        func antiphon(_ resolver: SectionResolver, english: Bool) -> String {
            var text: String
            let proper = english ? (englishProper ?? proper) : proper
            if let proper, resolver.sectionExists(path: proper.path, section: proper.section) {
                text = resolver.resolve(path: proper.path, section: proper.section).split(separator: "\n").first.map(String.init) ?? ""
            } else {
                let lines = resolver.resolve(path: special, section: name).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                text = index < lines.count ? lines[index] : ""
            }
            if let equals = text.range(of: #"^.*?=\s*"#, options: .regularExpression) { text.removeSubrange(equals) }
            text = text.trimmingCharacters(in: .whitespaces)
            text = Self.applyingSeasonalAlleluia(to: text, weekName: matins.weekName, isFirstVespers: false, english: english)
            return substituteName(in: text, office: matins.office, resolver: resolver, isAntiphon: true)
        }

        let invitPath = "Psalterium/Invitatorium"
        func lines(_ resolver: SectionResolver, english: Bool) -> [String]? {
            guard let body = resolver.unresolvedBody(path: invitPath, section: RawSectionParser.wholeFileSectionName) else { return nil }
            let ant = antiphon(resolver, english: english)
            guard !ant.isEmpty else { return nil }
            let half = ant.components(separatedBy: "*").dropFirst().joined(separator: "*").trimmingCharacters(in: .whitespaces)
            // The raw file, as DO reads it (`do_read`): its `$ant`/`$ant2` placeholders are
            // filled here, not expanded as prayers.
            var text = body.joined(separator: "\n")
            let rule = matins.rule
            func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
            if has(rule, "Invit2") {
                if let range = text.range(of: #"(?m) \*.*$"#, options: .regularExpression) {
                    text.replaceSubrange(range, with: " ")
                }
            } else if has(matins.weekName, "Quad[56]"), matins.office.hasPrefix("Tempora"), !has(rule, "Gloria responsory|Invit6") {
                text = text.replacingOccurrences(of: "&Gloria", with: "&Gloria2")
                if let range = text.range(of: #"(?m)^(v\.)\s*.* \^ (.)"#, options: .regularExpression) {
                    let match = String(text[range])
                    let first = match.last.map { String($0).uppercased() } ?? ""
                    text.replaceSubrange(range, with: "v. " + first)
                }
                if let range = text.range(of: #"\$ant2\s*(?=\$)"#, options: .regularExpression) { text.removeSubrange(range) }
            } else if proper == nil, matins.dayOfWeek == 1,
                has(matins.weekName, "(Epi|Pent|Quadp)")
            {
                if let range = text.range(of: #"(?m)^(v\.)\s*.* \+ (.)"#, options: .regularExpression) {
                    let match = String(text[range])
                    let first = match.last.map { String($0).uppercased() } ?? ""
                    text.replaceSubrange(range, with: "v. " + first)
                }
            }
            text = text.replacingOccurrences(of: #"[+*^=_] "#, with: "", options: .regularExpression)
            var output: [String] = []
            for raw in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line == "$ant2" {
                    output.append("Ant. \(half)")
                } else if line == "$ant" {
                    output.append("Ant. \(ant)")
                } else if line.hasPrefix("&Gloria") {
                    output.append(contentsOf: gloriaLines(String(line.dropFirst()), matins: matins, resolver: resolver))
                } else if line.hasPrefix("&") {
                    let name = String(line.dropFirst())
                    let resolved = ScriptMacros.resolve(name, context: macroContext, resolver: resolver, isEnglish: english)
                        ?? resolver.expandMacroLine("$" + name.replacingOccurrences(of: "_", with: " "))
                    output.append(contentsOf: resolved.split(separator: "\n").map(String.init))
                } else if !line.isEmpty {
                    output.append(line)
                }
            }
            return output
        }
        guard let latin = lines(resolver, english: false) else { return nil }
        let english = englishResolver.flatMap { lines($0, english: true) }
        return Section(kind: .invitatorium, units: Self.matinsUnits(latin, english: english))
    }

    /// Lines as DO's Matins shows them: `Ant.` lines as antiphons, `v.` strophes as prose,
    /// `V.`/`R.` pairs, `*` verses (the Gloria), `!` rubrics, `/:…:/` inline small print
    /// kept as words.
    static func matinsUnits(_ latin: [String], english: [String]?) -> [Unit] {
        func split(_ lines: [String]) -> [[String]] {
            // One unit per line, except a V. followed by its R. (paired by unitsFromLines).
            lines.map { [$0] }
        }
        let englishPaired = english?.count == latin.count ? english : nil
        var units: [Unit] = []
        var index = 0
        while index < latin.count {
            let line = latin[index]
            let englishLine = englishPaired?[index]
            if line.hasPrefix("Ant.") {
                units.append(.antiphon(
                    DOMarkers.stripLineLabel(line).replacingOccurrences(of: "/:", with: "").replacingOccurrences(of: ":/", with: ""),
                    english: englishLine.map(DOMarkers.stripLineLabel)
                ))
                index += 1
            } else if line.hasPrefix("v. ") {
                let text = String(line.dropFirst(3)).replacingOccurrences(of: "/:", with: "").replacingOccurrences(of: ":/", with: "")
                let englishText = englishLine.map { $0.hasPrefix("v. ") ? String($0.dropFirst(3)) : $0 }
                    .map { $0.replacingOccurrences(of: "/:", with: "").replacingOccurrences(of: ":/", with: "") }
                units.append(.prose(text, english: englishText))
                index += 1
            } else if line.hasPrefix("V."), index + 1 < latin.count, latin[index + 1].hasPrefix("R.") {
                units.append(contentsOf: unitsFromLines([line, latin[index + 1]], english: englishPaired.map { [$0[index], $0[index + 1]] }))
                index += 2
            } else {
                units.append(contentsOf: unitsFromLines([line], english: englishLine.map { [$0] }))
                index += 1
            }
        }
        return units
    }

    // MARK: - Hymnus

    /// `hymnusmatutinum` (`specmatins.pl:152-203`): the office's own `[Hymnus Matutinum]`
    /// (`Hymnus1` for the Commons of Confessors under 1960, `checkmtv`), else the psalter's
    /// for the season or the day.
    func assembleMatinsHymn(
        matins: MatinsDay, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section? {
        let special = "Psalterium/Special/Matutinum Special"
        var name = "Hymnus"
        if !resolver.sectionExists(path: matins.office, section: "Hymnus Matutinum"),
            matins.rule.range(of: "C[45]", options: .regularExpression) != nil
        {
            name += "1"
        }
        var location = proprium("\(name) Matutinum", flag: true, winner: matins.winner, resolver: resolver, weekName: matins.weekName)
        if location == nil {
            let season = Self.tempora(
                caller: "Hymnus matutinum", weekName: matins.weekName, dayOfWeek: matins.dayOfWeek, day: macroContext.officeDay,
                officeTitle: matins.winner.winningRank.title
            )
            var section = season.isEmpty ? "Day\(matins.dayOfWeek) Hymnus" : "Hymnus \(season)"
            if section == "Day0 Hymnus" {
                let monthday = Computus.monthday(day: matins.day, month: matins.month, year: matins.year, tomorrow: false) ?? ""
                if matins.month < 4 || monthday.range(of: #"^1[0-9][0-9]\-"#, options: .regularExpression) != nil { section += "1" }
            }
            location = (special, section)
        }
        guard let location, resolver.sectionExists(path: location.path, section: location.section) else { return nil }
        let texts = bothTexts(path: location.path, section: location.section, resolver: resolver, englishResolver: englishResolver)
        func stanzas(_ text: String) -> [String] { Self.hymnStanzas(text.replacingOccurrences(of: #"\*\s*"#, with: "", options: .regularExpression)) }
        return Section(kind: .hymnus, units: Self.pairedStanzas(latin: stanzas(texts.latin), english: texts.english.map(stanzas)))
    }

    // MARK: - Psalmi cum lectionibus

    /// `psalmi_matutinum` (`specmatins.pl:236-465`): three nocturns on nine-lesson days,
    /// else one; each with its psalms (`nocturn`) and lessons (`lectiones`). The *Te Deum*
    /// follows as its own section when said, and `trailing` (the skeleton's
    /// `$rubrica Matutinum`) closes the hour's lessons.
    func assembleMatinsPsalmi(
        matins: MatinsDay, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?,
        trailing: [String], englishTrailing: [String]?
    ) -> [Section] {
        let psalterPath = "Psalterium/Psalmi/Psalmi matutinum"
        func lines(_ path: String, _ section: String, _ resolver: SectionResolver) -> [String] {
            resolver.resolve(path: path, section: section).split(separator: "\n").map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        let dayOfWeek = matins.dayOfWeek
        let season = Self.tempora(
            caller: "Psalmi Matutinum", weekName: matins.weekName, dayOfWeek: dayOfWeek, day: macroContext.officeDay,
            officeTitle: matins.winner.winningRank.title
        )
        let properAnt = proprium("Ant Matutinum", flag: false, winner: matins.winner, resolver: resolver, weekName: matins.weekName)

        func psalmLines(_ resolver: SectionResolver, english: Bool) -> [String] {
            var psalmi = lines(psalterPath, "Day\(dayOfWeek)", resolver)
            if dayOfWeek == 0, matins.weekName.hasPrefix("Adv") {
                psalmi = lines(psalterPath, "Adv 0 Ant Matutinum", resolver)
            }
            if laudesScheme(winner: matins.winner, macroContext: macroContext) == 2, dayOfWeek == 3, !has(matins.office, "12-24") {
                psalmi = lines(psalterPath, "Day31", resolver)
            }
            func setVersum(_ key: String, at first: Int) {
                let versum = lines(psalterPath, key, resolver)
                guard versum.count >= 2, psalmi.count > first + 1 else { return }
                psalmi[first] = versum[0]
                psalmi[first + 1] = versum[1]
            }
            if !season.isEmpty, matins.office.hasPrefix("Tempora") || season == "Nat" || season == "Epi" {
                if dayOfWeek == 0 {
                    for i in 1...3 { setVersum("\(season) \(i) Versum", at: (i - 1) * 5 + 3) }
                    if psalmi.count > 14 { (psalmi[13], psalmi[14]) = (psalmi[3], psalmi[4]) }
                } else {
                    var i = dayOfWeek
                    if i > 3 { i -= 3 }
                    setVersum("\(season) \(i) Versum", at: 13)
                }
            }
            // `getantmatutinum` (`:1820-1864`): the office's own antiphons, filled out with its
            // nocturns' versicles when shorter than the 15 lines of a nine-lesson Matins.
            if let properAnt, resolver.sectionExists(path: properAnt.path, section: properAnt.section) {
                var proper = lines(properAnt.path, properAnt.section, resolver)
                if proper.count < 15 {
                    var built: [String] = []
                    for nocturn in 1...3 {
                        let take = min(3, proper.count)
                        built.append(contentsOf: proper.prefix(take))
                        proper.removeFirst(take)
                        // `getproprium`: a Commune file without the first nocturn's versicle
                        // gives its `[Versum 1]` (`specials.pl:465-469`).
                        if let versum = proprium(
                            "Nocturn \(nocturn) Versum", flag: true, winner: matins.winner, resolver: resolver, weekName: matins.weekName,
                            substitute: nocturn == 1 ? "Versum 1" : nil
                        ) {
                            built.append(contentsOf: lines(versum.path, versum.section, resolver))
                        }
                    }
                    psalmi = built
                } else {
                    psalmi = proper
                }
            }
            if has(matins.weekName, "Pasc[1-6]") {
                psalmi = paschalMatinsAntiphons(psalmi, matins: matins, proper: properAnt != nil, resolver: resolver)
            }
            if let match = matins.rule.firstMatch(of: /(?i)Ant Matutinum ([0-9]+) special/), let ind = Int(match.1),
                resolver.sectionExists(path: matins.office, section: "Ant Matutinum \(ind)")
            {
                let special = resolver.resolve(path: matins.office, section: "Ant Matutinum \(ind)").trimmingCharacters(in: .whitespacesAndNewlines)
                let target = ind == 12 && matins.paschal ? 10 : ind
                if target < psalmi.count, let range = psalmi[target].range(of: "^.*?;;", options: .regularExpression) {
                    psalmi[target].replaceSubrange(range, with: "\(special);;")
                }
            }
            return psalmi
        }

        var latin = psalmLines(resolver, english: false)
        var english = englishResolver.map { psalmLines($0, english: true) }

        let nineLessons = has(matins.rule, "9 lectio") && matins.lessonType == .defaultType && matins.rank >= 2
        var sections: [Section] = []
        var psalmNumber = 0
        if nineLessons {
            if properAnt == nil || !resolver.sectionExists(path: matins.office, section: "Ant Matutinum") {
                if (season == "Pasch" || season == "Asc"), matins.rank < 5,
                    !has(matins.winner.winningRank.title, "(?:in|post).*octava.*Ascensio")
                {
                    let key = has(matins.dayname1, "Dominica") ? "Dominica" : "Feria"
                    func applySpec(_ psalmi: inout [String], _ resolver: SectionResolver) {
                        let spec = lines(psalterPath, "Pasch Ant \(key)", resolver)
                        for i in [3, 4, 8, 9, 13, 14] where i < spec.count && i < psalmi.count { psalmi[i] = spec[i] }
                    }
                    applySpec(&latin, resolver)
                    if var eng = english, let englishResolver { applySpec(&eng, englishResolver); english = eng }
                } else if matins.office.hasPrefix("Tempora"), ["Adv", "Quad", "Pasch"].contains(season) {
                    func applyVersum(_ psalmi: inout [String], _ resolver: SectionResolver) {
                        for i in 1...3 {
                            let versum = lines(psalterPath, "\(season) \(i) Versum", resolver)
                            let first = (i - 1) * 5 + 3
                            if versum.count >= 2, psalmi.count > first + 1 { psalmi[first] = versum[0]; psalmi[first + 1] = versum[1] }
                        }
                    }
                    applyVersum(&latin, resolver)
                    if var eng = english, let englishResolver { applyVersum(&eng, englishResolver); english = eng }
                }
            }
            for nocturn in 1...3 {
                let indices = Array(((nocturn - 1) * 5)..<(nocturn * 5))
                var units = nocturnUnits(
                    latin: latin, english: english, psalmIndices: Array(indices.prefix(3)), versumLatin: indices.suffix(2).compactMap { $0 < latin.count ? latin[$0] : nil },
                    versumEnglish: english.map { eng in indices.suffix(2).compactMap { $0 < eng.count ? eng[$0] : nil } },
                    matins: matins, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver, psalmNumber: &psalmNumber
                )
                units.append(contentsOf: lessonUnits(nocturn: nocturn, matins: matins, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
                let kind: Section.Kind = nocturn == 1 ? .nocturnusI : nocturn == 2 ? .nocturnusII : .nocturnusIII
                sections.append(Section(kind: kind, units: units))
            }
        } else {
            // The single nocturn (`:368-464`).
            let vn = Self.dayOfWeek2i(dayOfWeek)
            var versLatin: [String] = []
            var versEnglish: [String]?
            if has(matins.weekName, "Pasc[1-6]") {
                let location: (String, String) = season == "Asc" ? ("Tempora/Pasc5-4", "Nocturn \(vn) Versum") : (psalterPath, "Pasch \(vn) Versum")
                versLatin = lines(location.0, location.1, resolver)
                versEnglish = englishResolver.map { lines(location.0, location.1, $0) }
            }
            if versLatin.isEmpty {
                versLatin = [13, 14].compactMap { $0 < latin.count ? latin[$0] : nil }
                versEnglish = english.map { eng in [13, 14].compactMap { $0 < eng.count ? eng[$0] : nil } }
            }
            var psalmIndices = [0, 1, 2]
            if latin.count > 9 { psalmIndices.append(contentsOf: [5, 6, 7, 10, 11, 12]) }
            if matins.month == 12, matins.day == 24 {
                versLatin = lines(psalterPath, "Nat24 Versum", resolver)
                versEnglish = englishResolver.map { lines(psalterPath, "Nat24 Versum", $0) }
            }
            if has(matins.weekName, "Pasc[07]") {
                versLatin = [3, 4].compactMap { $0 < latin.count ? latin[$0] : nil }
                versEnglish = english.map { eng in [3, 4].compactMap { $0 < eng.count ? eng[$0] : nil } }
            }
            var units = nocturnUnits(
                latin: latin, english: english, psalmIndices: psalmIndices, versumLatin: versLatin, versumEnglish: versEnglish,
                matins: matins, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver, psalmNumber: &psalmNumber
            )
            units.append(contentsOf: lessonUnits(nocturn: 0, matins: matins, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
            sections.append(Section(kind: .adNocturnum, units: units))
        }

        // The *Te Deum* after the last lesson (`lectio`, `:1373`).
        let last = nineLessons ? 9 : 3
        if teDeumRequired(lesson: last, matins: matins) {
            let latinTeDeum = resolver.resolve(path: SectionResolver.prayersPath, section: "Te Deum")
            let englishTeDeum = englishResolver.flatMap { eng in
                eng.sectionExists(path: SectionResolver.prayersPath, section: "Te Deum") ? eng.resolve(path: SectionResolver.prayersPath, section: "Te Deum") : nil
            }
            sections.append(Section(kind: .teDeum, units: Self.teDeumUnits(latinTeDeum, english: englishTeDeum)))
        }
        if !trailing.isEmpty, !sections.isEmpty {
            sections[sections.count - 1].units.append(contentsOf: Self.unitsFromLines(trailing, english: englishTrailing))
        }
        return sections
    }

    /// The *Te Deum*'s lines: each `*` line a verse, the others (the last lines have no
    /// `*`) plain, `/:(Fit reverentia):/` kept as words, as DO shows it.
    static func teDeumUnits(_ latin: String, english: String?) -> [Unit] {
        func lines(_ text: String) -> [String] {
            text.split(separator: "\n").map { line in
                var text = String(line).trimmingCharacters(in: .whitespaces)
                if text.hasPrefix("v. ") { text = String(text.dropFirst(3)) }
                return text
            }.filter { !$0.isEmpty }
        }
        return unitsFromLines(lines(latin), english: english.map(lines))
    }

    /// `dayofweek2i` (`:467-472`).
    static func dayOfWeek2i(_ dayOfWeek: Int) -> Int {
        var i = dayOfWeek == 0 ? 1 : dayOfWeek
        if i > 3 { i -= 3 }
        return i
    }

    /// `ant_matutinum_paschal` (`:1562-1609`).
    func paschalMatinsAntiphons(_ input: [String], matins: MatinsDay, proper: Bool, resolver: SectionResolver) -> [String] {
        var psalmi = input
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        func stripAntiphon(_ line: String) -> String {
            guard let range = line.range(of: "^.*?(?=;;)", options: .regularExpression) else { return line }
            return line.replacingCharacters(in: range, with: "")
        }
        func keepSingle(_ line: String) -> String {
            guard let range = line.range(of: "^.*;;", options: .regularExpression) else { return line }
            return line.replacingCharacters(in: range, with: ";;")
        }
        let alleluia = alleluiaAntiphon(resolver: resolver)
        if matins.dayOfWeek != 0 || matins.weekName.hasPrefix("Pasc6") {
            if !proper || matins.office.contains("/C10") {
                psalmi = psalmi.map(stripAntiphon)
                if !psalmi.isEmpty { psalmi[0] = alleluia + psalmi[0] }
                if matins.dayOfWeek != 0, has(matins.rule, "9 lectio"), matins.rank > 3, matins.rank >= 2 {
                    for i in [5, 10] where i < psalmi.count { psalmi[i] = alleluia + psalmi[i] }
                }
            } else if !matins.office.hasPrefix("Tempora") {
                for i in 0...3 {
                    for j in [i * 5 + 1, i * 5 + 2] where j < psalmi.count { psalmi[j] = keepSingle(psalmi[j]) }
                }
            }
        } else if has(matins.weekName, "Pasc[1-5]"), has(matins.dayname1, "Dominica") {
            let sunday = resolver.resolve(path: "Psalterium/Psalmi/Psalmi matutinum", section: "Pasch0").split(separator: "\n").map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for i in psalmi.indices where i < sunday.count {
                if let range = psalmi[i].range(of: "^.*;;", options: .regularExpression) {
                    psalmi[i].replaceSubrange(range, with: sunday[i])
                }
            }
            for i in psalmi.indices.dropFirst() { psalmi[i] = keepSingle(psalmi[i]) }
        }
        return psalmi
    }

    /// `nocturn` (`:205-234`) and `antetpsalm` (`psalmi.pl:661-707`): each antiphon whole
    /// before its psalms and without its asterisk after them, then the versicle.
    func nocturnUnits(
        latin: [String], english: [String]?, psalmIndices: [Int], versumLatin: [String], versumEnglish: [String]?,
        matins: MatinsDay, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?,
        psalmNumber: inout Int
    ) -> [Unit] {
        func entry(_ line: String, english: Bool) -> (antiphon: String, psalms: [String]) {
            let parts = line.components(separatedBy: ";;")
            var antiphon = parts[0].trimmingCharacters(in: .whitespaces)
            let psalms = parts.count > 1 ? parts[1] : ""
            if !antiphon.isEmpty {
                antiphon = Self.applyingSeasonalAlleluia(to: antiphon, weekName: matins.weekName, isFirstVespers: false, english: english)
                antiphon = substituteName(in: antiphon, office: matins.office, resolver: english ? (englishResolver ?? resolver) : resolver, isAntiphon: true)
            }
            let list = psalms.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return (antiphon, list)
        }
        var units: [Unit] = []
        var open: (latin: String, english: String?)?
        for index in psalmIndices where index < latin.count {
            let latinEntry = entry(latin[index], english: false)
            let englishAntiphon = english.flatMap { index < $0.count ? entry($0[index], english: true).antiphon : nil }.flatMap { $0.isEmpty ? nil : $0 }
            if !latinEntry.antiphon.isEmpty {
                if let open { units.append(.antiphon(Self.closingAntiphon(open.latin), english: open.english.map(Self.closingAntiphon))) }
                units.append(.antiphon(latinEntry.antiphon, english: englishAntiphon))
                open = (latinEntry.antiphon, englishAntiphon)
            }
            for (offset, psalm) in latinEntry.psalms.enumerated() {
                psalmNumber += 1
                let (title, content) = psalmUnits(number: psalm, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)
                var psalmContent = content
                // `horasscripts.pl:664`: Psalm 94 as a nocturn psalm (Epiphany) repeats its
                // antiphon at each `$ant` of the file.
                if psalm == "94" {
                    psalmContent = psalmContent.map { unit in
                        guard String(describing: unit).contains(":ant is missing!") else { return unit }
                        return .antiphon(open?.latin ?? latinEntry.antiphon, english: open?.english ?? englishAntiphon)
                    }
                }
                if offset < latinEntry.psalms.count - 1 {
                    let gloria = gloriaUnits(resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)
                    psalmContent = Array(psalmContent.dropLast(gloria.count))
                }
                if offset == 0, !latinEntry.antiphon.isEmpty {
                    let (tagged, latinMatched, englishMatched) = Self.applyingAntiphonDagger(
                        antiphon: latinEntry.antiphon, englishAntiphon: englishAntiphon, psalmContent: psalmContent
                    )
                    psalmContent = tagged
                    if latinMatched || englishMatched {
                        units[units.count - 1] = .antiphon(
                            latinMatched ? "\(latinEntry.antiphon) ‡" : latinEntry.antiphon,
                            english: englishMatched ? englishAntiphon.map { "\($0) ‡" } : englishAntiphon
                        )
                    }
                }
                units.append(.psalmTitle(Self.numberedPsalmTitle(title, psalmNumber)))
                units.append(contentsOf: psalmContent)
            }
        }
        if let open { units.append(.antiphon(Self.closingAntiphon(open.latin), english: open.english.map(Self.closingAntiphon))) }
        // The versicle, one alleluia in Paschaltide.
        func versum(_ lines: [String], english: Bool) -> [String] {
            lines.map { line in
                let line = Self.processingInlineAlleluias(line, paschal: matins.paschal)
                return matins.paschal ? Self.ensuringSingleAlleluia(line, alleluia: english ? "Alleluia" : "Allelúia") : line
            }
        }
        if versumLatin.count >= 2 {
            units.append(contentsOf: Self.unitsFromLines(
                versum(Array(versumLatin.prefix(2)), english: false), english: versumEnglish.flatMap { $0.count >= 2 ? versum(Array($0.prefix(2)), english: true) : nil }
            ))
        }
        return units
    }

    // MARK: - Lessons

    /// `lectiones` (`:659-699`) with `get_absolutio_et_benedictiones` (`:492-657`): the
    /// *Pater noster*, the absolution, and before each lesson *Iube, Dómine* and its
    /// blessing; then the lesson with its responsory (`lectio`).
    func lessonUnits(nocturn: Int, matins: MatinsDay, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?) -> [Unit] {
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        let rule = matins.rule
        let limit = has(rule, "Limit.*?Benedictio")
        var units: [Unit] = []
        let latinBlessings = absolutioEtBenedictiones(nocturn: nocturn, matins: matins, resolver: resolver)
        let englishBlessings = englishResolver.map { absolutioEtBenedictiones(nocturn: nocturn, matins: matins, resolver: $0) }

        func expanded(_ lines: [String], _ resolver: SectionResolver) -> [String] {
            lines.flatMap { resolver.expandMacroLine($0).split(separator: "\n").map(String.init) }
        }
        if !limit {
            if !has(rule, "sine absolutio") {
                let latin = expanded(["$rubrica Pater secreto", "$Pater noster Et"], resolver)
                let english = englishResolver.map { expanded(["$rubrica Pater secreto", "$Pater noster Et"], $0) }
                units.append(contentsOf: Self.pairedLines(latin, english))
                if let absolution = latinBlessings.first {
                    units.append(.versicleResponse(
                        versicle: absolution, response: amen(resolver), versicleEnglish: englishBlessings?.first,
                        responseEnglish: englishResolver.map { amen($0) }
                    ))
                }
            }
        } else {
            let latin = expanded(["$Pater totum secreto"], resolver)
            let english = englishResolver.map { expanded(["$Pater totum secreto"], $0) }
            units.append(contentsOf: Self.pairedLines(latin, english))
        }

        let perNocturn = has(rule, "Lectio brevis") ? 1 : 3
        let number = max(nocturn, 1)
        for i in 1...perNocturn {
            let lesson = (number - 1) * perNocturn + i
            if !limit {
                let jube = expanded(["$Jube domne"], resolver).map(DOMarkers.stripLineLabel).filter { !$0.isEmpty }
                let jubeEnglish = englishResolver.map { expanded(["$Jube domne"], $0).map(DOMarkers.stripLineLabel).filter { !$0.isEmpty } }
                if let first = jube.first { units.append(.prose(first, english: jubeEnglish?.first)) }
                if i < latinBlessings.count {
                    units.append(.versicleResponse(
                        versicle: latinBlessings[i], response: amen(resolver),
                        versicleEnglish: englishBlessings.flatMap { i < $0.count ? $0[i] : nil }, responseEnglish: englishResolver.map { amen($0) }
                    ))
                }
            }
            units.append(contentsOf: lectioUnits(lesson, matins: matins, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
        }
        return units
    }

    func amen(_ resolver: SectionResolver) -> String {
        DOMarkers.stripLineLabel(resolver.expandMacroLine("$Amen").split(separator: "\n").first.map(String.init) ?? "Amen.")
    }

    /// Latin and English lines as units, paired when they line up.
    static func pairedLines(_ latin: [String], _ english: [String]?) -> [Unit] {
        unitsFromLines(latin, english: english)
    }

    /// `get_absolutio_et_benedictiones` (`:492-657`) for the 1960 Roman office: the
    /// absolution first, then one blessing per lesson.
    func absolutioEtBenedictiones(nocturn: Int, matins: MatinsDay, resolver: SectionResolver) -> [String] {
        let path = "Psalterium/Benedictions"
        func lines(_ section: String) -> [String] {
            resolver.resolve(path: path, section: section).split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        let absolutions = lines("Absolutiones")
        let evangelica = lines("Evangelica")
        let office = matins.office
        // DO tests the whole `[Rank]` line (`$winner{Rank}`), its Commune too: St Anne's
        // `ex C7a` makes her blessing *ipsa*.
        let rank = matins.winner.winningRank
        let rankTitle = "\(rank.title);;\(rank.degreeLabel);;\(rank.numericPrecedence);;\(rank.communeReference)"
        let commune = matins.commune ?? ""
        var blessings: [String]
        if nocturn > 0, has(matins.rule, "9 lectiones") {
            blessings = lines("Nocturn \(nocturn)")
            if nocturn == 3, has(office, "Sancti|Quad5-5") {
                if has(office, "12-25") {
                    blessings = lines("Nocturn 3 12-25")
                } else if has(rankTitle, #"(?:\bss?\.|\bbb?\.|sanctorum)"#) || has(commune, "C11|08-15|09-08|12-08") {
                    let shift = cujusQ(rankTitle, rule: matins.rule, commune: commune)
                    if blessings.count > 3 + shift, blessings.count > 1 { blessings[1] = blessings[3 + shift] }
                }
            }
            if nocturn == 3, !has(office, "12-25"), !blessings.isEmpty, let first = evangelica.first {
                blessings[0] = first
            }
            if nocturn == 3, !has(office, "12-25"),
                lectioText(9, matins: matins, resolver: resolver).range(of: #"!(?:Matt|Marc|Luc|Joannes|Ioannes)"#, options: .regularExpression) != nil,
                let ev9 = lines("Evangelica9").first, blessings.count > 2
            {
                blessings[2] = ev9
            }
            blessings.insert(nocturn - 1 < absolutions.count ? absolutions[nocturn - 1] : "", at: 0)
        } else if let match = office.firstMatch(of: /(C1[02])/) {
            let file = "Commune/\(match.1)"
            blessings = resolver.resolve(path: file, section: "Benedictio").split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        } else {
            blessings = lines("Nocturn 3")
            if has(rankTitle, "vigil|quatt|ciner") || has(office, "Quad[1-5]-[^0]|Quad6-1|Pasc5-1|Pasc[07]") {
                if !blessings.isEmpty, let first = evangelica.first { blessings[0] = first }
            } else if has(rankTitle, "dominica") || has(matins.dayname1, "dominica") {
                if let ev9 = lines("Evangelica9").first, blessings.count > 2 { blessings[2] = ev9 }
            } else if (office.hasPrefix("Sancti") && has(rankTitle, #"\bss?\.|b\."#)) || has(commune, "C11") {
                let shift = cujusQ(rankTitle, rule: matins.rule, commune: commune)
                if blessings.count > 3 + shift, blessings.count > 1 { blessings[1] = blessings[3 + shift] }
            } else {
                blessings = lines("Nocturn \(Self.dayOfWeek2i(matins.dayOfWeek))")
            }
            let index = Self.dayOfWeek2i(matins.dayOfWeek) - 1
            blessings.insert(index < absolutions.count ? absolutions[index] : "", at: 0)
        }
        return blessings.map { DOMarkers.stripLineLabel($0.replacingOccurrences(of: "Benedictio. ", with: "")) }
    }

    /// `cujus_q` (`:475-490`): which *Cuius / Quorum festum* blessing.
    func cujusQ(_ rankTitle: String, rule: String, commune: String) -> Int {
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        if has(rule, "Quorum Festum") { return 1 }
        if has(commune, "C11|08-15|09-08|12-08") { return 4 }
        if has(rankTitle, "basilic") { return -2 }
        if rankTitle.contains("S. P. N. Benedicti Abbatis") { return 5 }
        var j = 0
        if has(rankTitle, "(virgin|vidu[aæ]|poenitentis|pœnitentis|C6|C7)"), !has(rankTitle, "C[2-5]") { j += 2 }
        if has(rankTitle, #"(?:ss\.|bb\.|sanctorum|sociorum)"#) { j += 1 }
        return j
    }

    /// `contract_scripture` (`:1797-1818`).
    func contractScripture(_ lesson: Int, matins: MatinsDay, forResponsory: Bool = false) -> Bool {
        guard lesson == 2 else { return false }
        if (matins.commune ?? "").contains("C10") || matins.office.contains("C10") { return true }
        guard matins.lessonType == .sanctoral || matins.lessonType == .sunday else { return false }
        let scriptura1960 = matins.rule.range(of: "scriptura1960", options: .caseInsensitive) != nil
        return !scriptura1960 || forResponsory
    }

    /// `tedeum_required` (`:1405-1438`) for the Roman office.
    func teDeumRequired(lesson: Int, matins: MatinsDay) -> Bool {
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        let rule = matins.rule
        let office = matins.office
        let isLast = (lesson == 9 && has(rule, "9 lectiones"))
            || (lesson == 3 && (!has(rule, "9 lectiones") || matins.lessonType != .defaultType))
        guard isLast, !has(rule, "no Te Deum"), !(matins.commune ?? "").contains("C9"),
            !has(office, "^Tempora.*(?:Adv|Quad)")
        else { return false }
        let title = matins.dayname1
        return (matins.dayOfWeek == 0 && !has(title, "Vigilia"))
            || (has(office, "Sancti|Commune") && !has(title, "Vigilia"))
            || has(rule, "Feria Te Deum")
            || has(office, "Pasc|Nat|C10")
            || (office.hasPrefix("Tempora") && matins.rank > 5 && matins.dayOfWeek != 0)
    }

    /// `responsory_gloria` (`:1489-1560`): the *Gloria Patri* on the last responsory of each
    /// nocturn and on the one before the *Te Deum*; none elsewhere.
    func responsoryWithGloria(_ lines: [String], lesson: Int, matins: MatinsDay) -> [String] {
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        var lines = lines.map { $0.replacingOccurrences(of: #"&Gloria1?"#, with: "&Gloria1", options: .regularExpression) }
        if (lesson == 1 && has(matins.office, "(?:Adv1|Pasc0)-0")) || has(matins.rule, "requiem Gloria") { return lines }
        let addsGloria = lesson % 3 == 0 || (lesson % 3 == 2 && teDeumRequired(lesson: lesson + 1, matins: matins))
        if addsGloria {
            if !lines.contains(where: { $0.contains("&Gloria") }) {
                while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty || last.trimmingCharacters(in: .whitespaces) == "_" {
                    lines.removeLast()
                }
                if let lastR = lines.last, lastR.hasPrefix("R.") {
                    lines.append("&Gloria1")
                    lines.append(lastR)
                }
            }
        } else if let index = lines.firstIndex(where: { $0.contains("&Gloria") }) {
            lines = Array(lines[..<index])
        }
        return lines
    }

    // MARK: - lectio

    /// The lesson's source text (`lectio`, `:726-1375`) before its responsory, as DO
    /// selects it for the 1960 Roman office: the winner's own `Lectio<n>`, the occurring
    /// Scripture's, the Commune's; the 1960 diversions of lesson 3 on Sundays and III
    /// class feasts; the contraction of lessons 2 and 3.
    func lectioText(_ requested: Int, matins: MatinsDay, resolver: SectionResolver) -> String {
        lectioSource(requested, matins: matins, resolver: resolver).text
    }

    struct LectioSource {
        var text: String
        /// Where the responsory is looked up first, and under which number.
        var responsoryPath: String?
        var responsoryNumber: Int
    }

    func lectioSource(_ requested: Int, matins: MatinsDay, resolver: SectionResolver) -> LectioSource {
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        func section(_ path: String?, _ name: String) -> String? {
            guard let path else { return nil }
            let effective = monthdayMerged(path, section: name, matins: matins, resolver: resolver)
            guard resolver.sectionExists(path: effective, section: name) else { return nil }
            let text = resolver.resolve(path: effective, section: name)
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
        }
        let office = matins.office
        let rule = matins.rule
        var num = requested
        var lessonType = matins.lessonType
        if office.range(of: "C12", options: .caseInsensitive) != nil { lessonType = .defaultType }
        if lessonType == .sunday, num == 3 {
            num = 7
        } else if num == 3, lessonType == .sanctoral {
            num = 4
        }
        let nocturn = (num - 1) / 3 + 1
        var source = office
        var text: String?
        var transferredResponsory: (path: String, lesson: Int)?

        // `scriptura1960` (`:831-848`).
        if num < 3, has(rule, "scriptura1960"), let scriptura = matins.scriptura, let s = section(scriptura, "Lectio\(num)") {
            text = s
            source = scriptura
            if num == 2, has(matins.dayname1, "feria") == false, let third = section(scriptura, "Lectio3") {
                var joined = s
                if let underscore = joined.range(of: "_") { joined = String(joined[..<underscore.lowerBound]) }
                text = joined + third
            }
        }
        // `Lectio1 OctNat` / `TempNat` (`:780-808`), 29 December to 5 January: the first
        // nocturn from the day's own `Tempora/NatDD` (before the 29th, Christmas Day's).
        if text == nil, nocturn == 1, has(rule, "Lectio1 (Oct|Temp)Nat") {
            let file = matins.month == 12 && matins.day < 29 ? "Sancti/12-25" : String(format: "Tempora/Nat%02d", matins.day)
            if let own = section(file, "Lectio\(num)") {
                text = own
                source = file
                if contractScripture(num, matins: matins), let third = section(file, "Lectio3") { text = own + "\n" + third }
            }
        }
        // Our Lady on Saturday (`:872-877`): lessons 1-3 of its own office.
        if office.contains("C12") {
            if num == 4 { num = 3 }
            num = num % 3 == 0 ? 3 : num % 3
        }
        if text == nil, let own = section(office, "Lectio\(num)") {
            text = own
            source = office
        }
        if nocturn == 1, has(rule, "Lectio1 Quad"), !has(matins.weekName, #"Quad(\d|p3\-[3456])"#) {
            text = nil
        }
        // The Commune (`:915-946`), for an `ex` Commune, or by the rule "in N Nocturno
        // Lectiones ex Commune in L loco" (St Agnes: the Commune's second set).
        if text == nil, office.hasPrefix("Sancti"), let commune = matins.commune, commune.hasPrefix("Commune"),
            matins.communeIsEx && matins.rank > 3 || has(rule, "in \(nocturn) Nocturno Lectiones ex")
        {
            var file = commune
            var name = "Lectio\(num)"
            if let match = rule.firstMatch(of: /(?i)in (\d) Nocturno Lectiones ex (Commune|C\d+[a-z]*) in (\d+) loco/),
                Int(match.1) == nocturn, let loco = Int(match.3)
            {
                if match.2 != "Commune" { file = "Commune/\(match.2)" }
                if loco > 1 { name += " in \(loco) loco" }
            }
            if let c = section(file, name) {
                text = c
                source = file
                if contractScripture(num, matins: matins) {
                    let third = name.replacingOccurrences(of: "Lectio2", with: "Lectio3")
                    if let rest = section(file, third) { text = c + "\n" + rest }
                }
            } else if let c = section(commune, "Lectio\(num)") {
                text = c
                source = commune
                if contractScripture(num, matins: matins), let third = section(commune, "Lectio3") { text = c + "\n" + third }
            }
        }
        // The occurring Scripture for the first nocturn (`:949-976`).
        if text == nil, num < 4, let scriptura = matins.scriptura, let s = section(scriptura, "Lectio\(num)") {
            text = s
            source = scriptura
        }
        if var t = text, contractScripture(num, matins: matins), source != matins.commune {
            if let underscore = t.range(of: "_") { t = String(t[..<underscore.lowerBound]) }    // `(.*?)\_`, the first one
            if let third = section(source, "Lectio3") { t += "\n" + third }
            text = t
        }
        if text == nil, let commune = matins.commune, let c = section(commune, "Lectio\(num)") {
            text = c
            source = commune
            if contractScripture(num, matins: matins), let third = section(commune, "Lectio3") { text = c + "\n" + third }
        }
        // The Scripture transfer table (`resolveitable`, `:848-856`, `:1629-1690`), for the
        // single transfer the 1960 tables hold (`01-12=Epi1-0a` under letter `f`): the
        // transferred book's lessons from the first, or, when the day's own Scripture
        // already begins a book, its incipit in the third place (12 January 2030).
        if nocturn == 1, num <= 3, !has(office, "C12"), var file = matins.scriptureTransfer,
            file.range(of: "~B$", options: .regularExpression) == nil || !matins.initia
        {
            let replace = file.hasSuffix("~R")
            file = file.replacingOccurrences(of: "~[ABR]$", with: "", options: .regularExpression)
            let pieces = file.split(separator: "~").map(String.init)
            var start = 1
            if matins.initia, !replace {
                start = pieces.count < 2 ? 3 : 2
                if !has(rule, "(9|12) lectiones"), office.hasPrefix("Sancti") { start = 1 }
            }
            // Slot `start`... take the files' first lessons, then the last file's next ones.
            var slots: [Int: (file: String, lesson: Int)] = [:]
            var slot = start
            for piece in pieces.prefix(3) where slot <= 3 {
                slots[slot] = ("Tempora/\(piece)", 1)
                slot += 1
            }
            var next = 2
            while slot <= 3, let last = pieces.last {
                slots[slot] = ("Tempora/\(last)", next)
                slot += 1
                next += 1
            }
            if let (path, lesson) = slots[num], let transferred = section(path, "Lectio\(lesson)") {
                text = transferred
                source = path
                transferredResponsory = (path, lesson)
            }
        }
        // The III class feast's legend (`:1215-1234`): `Lectio94`, else lessons 4, 5, 6 joined.
        if lessonType == .sanctoral, num == 4 {
            if let legend = section(office, "Lectio94") {
                text = legend
                source = office
            } else {
                var joined = text ?? ""
                for i in 5..<7 {
                    guard let next = section(office, "Lectio\(i)"), !next.contains("!") else { break }
                    if let underscore = joined.range(of: "_") { joined = String(joined[..<underscore.lowerBound]) }
                    joined += "\n" + next
                }
                text = joined
            }
        }
        // `Special Lectio N` (`:1015-1020`): Our Lady on Saturday reads the month's lesson from C10.
        // DO reads it in the Commune's rule (`$commune{Rule}`): Mount Carmel on a Saturday,
        // `Sancti/07-16sab`, has only "Special Benedictio" in its own.
        if has(rule, "Special Lectio \(requested)\\b") || has(matins.communeRule, "Special Lectio \(requested)\\b") {
            let c10 = "Commune/C10"
            if let marian = section(c10, String(format: "Lectio M%02d", matins.month)) {
                text = marian
                source = c10
            }
        }
        var responsoryNumber = num
        if let (path, lesson) = transferredResponsory {
            // `tferifile`: the transferred book's responsory when it brings its own.
            let rule = resolver.resolve(path: path, section: "Rule")
            if section(path, "Responsory\(lesson)") != nil,
                has(rule, "Initia cum Responsory") || has(resolver.resolveRank(path: path), "Dominica")
            {
                return LectioSource(text: text ?? "", responsoryPath: path, responsoryNumber: lesson)
            }
            source = office
        }
        if lessonType != .defaultType || (office.hasPrefix("Sancti") && matins.rank < 2), num > 2 { responsoryNumber = 3 }
        return LectioSource(text: text ?? "", responsoryPath: source, responsoryNumber: responsoryNumber)
    }

    /// The lesson as units: its heading (*Lectio i*), its title and reference lines, the
    /// text, *Tu autem*, and the responsory, or nothing after the last lesson when the
    /// *Te Deum* follows (`lectio`, `:1236-1375`).
    func lectioUnits(_ lesson: Int, matins: MatinsDay, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?) -> [Unit] {
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        var source = lectioSource(lesson, matins: matins, resolver: resolver)
        source.text = source.text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { Self.processingInlineAlleluias(String($0), paschal: matins.paschal) }.joined(separator: "\n")
        var englishSource = englishResolver.map { lectioSource(lesson, matins: matins, resolver: $0) }
        // `:1349-1353`: outside Latin, a parenthesised reference or number loses its brackets
        // (`parenthesised_text`), "(2 Cor. ii. 15.)" showing as "2 Cor. ii. 15.".
        if let text = englishSource?.text {
            englishSource?.text = Self.unbracketingReferences(text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { Self.processingInlineAlleluias(String($0), paschal: matins.paschal) }.joined(separator: "\n"))
        }
        var units: [Unit] = [.psalmTitle("Lectio \(Self.romanNumeral(lesson))")]
        units.append(contentsOf: Self.lessonUnits(source.text, english: englishSource?.text))

        let limit = has(matins.rule, "Limit.*?Benedictio")
        if !limit {
            let latin = resolver.expandMacroLine("$Tu autem").split(separator: "\n").map(String.init)
            let english = englishResolver.map { $0.expandMacroLine("$Tu autem").split(separator: "\n").map(String.init) }
            units.append(contentsOf: Self.unitsFromLines(latin, english: english))
        }
        let isLast = teDeumRequired(lesson: lesson, matins: matins)
        if !isLast {
            let latin = responsoryLines(lesson, source: source, matins: matins, resolver: resolver)
            // The responsory is part of DO's lesson text, so its asides are unbracketed too.
            let english = englishResolver.map {
                responsoryLines(lesson, source: englishSource ?? source, matins: matins, resolver: $0).map(Self.unbracketingReferences)
            }
            units.append(contentsOf: responsoryUnits(latin, english: english, matins: matins, resolver: resolver, englishResolver: englishResolver, macroContext: macroContext))
        }
        return units
    }

    /// The responsory's lines (`:1246-1313`): `Responsory<n> 1960`, else `Responsory<n>`
    /// from the lesson's source, the winner, then its Commune; with its Gloria.
    func responsoryLines(_ lesson: Int, source: LectioSource, matins: MatinsDay, resolver: SectionResolver) -> [String] {
        var number = source.responsoryNumber
        if matins.office.hasPrefix("Tempora"), matins.dayOfWeek == 0,
            matins.weekName.range(of: "(Adv|Quad)", options: .regularExpression) != nil, number == 3
        {
            number = 9
        }
        // After that, a contracted second lesson takes the third responsory (`:1255-1257`).
        if contractScripture(lesson, matins: matins, forResponsory: true) { number = 3 }
        // `&Gloria` stays a marker for `responsory_gloria`, as in DO's text.
        let resolver = SectionResolver(corpus: resolver.corpus, context: resolver.context, macroContext: nil, isEnglish: resolver.isEnglish)
        func find(_ path: String?, _ section: String) -> String? {
            guard let path else { return nil }
            let effective = monthdayMerged(path, section: section, matins: matins, resolver: resolver)
            guard resolver.sectionExists(path: effective, section: section) else { return nil }
            let found = resolver.resolve(path: effective, section: section)
            return found.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : found
        }
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        let name = "Responsory\(number)"
        var found: String?
        // `:1262-1305`: the office's own 1960 responsory (`%w`, the winner with its
        // monthday merge, not the file the lesson came from: Ss. John and Paul keep theirs
        // over the Scripture's); by rule, the occurring Scripture's; else the winner's own
        // before the lesson source's, then the Commune's.
        if let own1960 = find(matins.office, "\(name) 1960") {
            found = own1960
        } else if has(matins.rule, "Responsory Feria") || (has(matins.rule, "scriptura1960") && find(matins.office, name) == nil) {
            found = find(matins.scriptura, name) ?? find(matins.scriptura, "\(name) 1960")
        } else {
            found = find(matins.office, name) ?? find(source.responsoryPath, name) ?? find(matins.commune, name)
        }
        if found == nil {
            let winnerName = matins.office.contains("C9") && number == 9 ? "Responsory91" : name
            found = find(matins.office, winnerName) ?? find(matins.commune, name)
        }
        let text = found ?? ""
        // `process_inline_alleluias`: "(Allelúia.)" is kept, unbracketed, in Paschaltide and
        // dropped outside it (`LanguageTextTools.pm:55-73`).
        var lines = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .map { Self.processingInlineAlleluias($0, paschal: matins.paschal) }
        if matins.paschal {
            // `matins_lectio_responsory_alleluia`: one alleluia on the respond's end, the
            // verse's repeat and the last line.
            let alleluia = resolver.isEnglish ? "Alleluia" : "Allelúia"
            for index in [1, 3, lines.count - 1] where index >= 0 && index < lines.count && !lines[index].hasPrefix("V.") {
                lines[index] = Self.ensuringSingleAlleluia(lines[index], alleluia: alleluia)
            }
        }
        return responsoryWithGloria(lines, lesson: lesson, matins: matins)
    }

    /// A responsory's lines as units: the respond (its two halves, like a psalm verse),
    /// then each `V.` with the `R.` after it, the *Gloria* too.
    func responsoryUnits(
        _ latin: [String], english: [String]?, matins: MatinsDay, resolver: SectionResolver, englishResolver: SectionResolver?, macroContext: MacroContext
    ) -> [Unit] {
        func normalised(_ lines: [String], _ resolver: SectionResolver) -> [String] {
            var result: [String] = []
            for line in lines {
                if line.hasPrefix("&Gloria") {
                    result.append(contentsOf: gloriaLines(String(line.dropFirst()), matins: matins, resolver: resolver))
                } else if let last = result.last, last.hasPrefix("R."),
                    line.hasPrefix("*") || line.range(of: #"^[\p{Ll}]"#, options: .regularExpression) != nil
                {
                    // The respond's second half, or a continuation, on its own line.
                    result[result.count - 1] = last + " " + line
                } else {
                    result.append(line)
                }
            }
            return result
        }
        let latinLines = normalised(latin, resolver)
        let englishLines = english.flatMap { eng in englishResolver.map { normalised(eng, $0) } }
        let paired = englishLines?.count == latinLines.count ? englishLines : nil
        var units: [Unit] = []
        var index = 0
        while index < latinLines.count {
            let line = latinLines[index]
            if index == 0, line.hasPrefix("R.") {
                let text = DOMarkers.stripLineLabel(line)
                let (first, second) = Psalm.splitHalves(text)
                let englishSplit = paired.map { Psalm.splitHalves(DOMarkers.stripLineLabel($0[0])) }
                units.append(.verse(reference: "", firstHalf: first, secondHalf: second, firstHalfEnglish: englishSplit?.first, secondHalfEnglish: englishSplit?.second))
                index += 1
            } else if line.hasPrefix("V."), index + 1 < latinLines.count, latinLines[index + 1].hasPrefix("R.") {
                units.append(.versicleResponse(
                    versicle: DOMarkers.stripLineLabel(line), response: DOMarkers.stripLineLabel(latinLines[index + 1]),
                    versicleEnglish: paired.map { DOMarkers.stripLineLabel($0[index]) }, responseEnglish: paired.map { DOMarkers.stripLineLabel($0[index + 1]) }
                ))
                index += 2
            } else {
                units.append(contentsOf: Self.unitsFromLines([line], english: paired.map { [$0[index]] }))
                index += 1
            }
        }
        return units
    }

    /// A lesson's text as units: a title line followed by a `!` reference (the book or the
    /// Gospel, the homily's author and source) as reference lines, the text itself as
    /// `.lesson` paragraphs (one per `_` block), each source line one piece, its verse
    /// number dropped.
    static func lessonUnits(_ latin: String, english: String?) -> [Unit] {
        let latinPieces = lessonPieces(latin)
        let englishPieces = english.map(lessonPieces)
        let aligned = englishPieces?.count == latinPieces.count ? englishPieces : nil
        var units: [Unit] = []
        for index in latinPieces.indices {
            let piece = latinPieces[index]
            let englishPiece = aligned.map { $0[index] }
            let englishMatches = englishPiece.map { $0.isReference == piece.isReference } ?? false
            if piece.isReference {
                units.append(.psalmTitle(piece.texts.first ?? "", english: englishMatches ? englishPiece?.texts.first : nil))
            } else {
                units.append(.lesson(LessonParagraph(lines: piece.texts, english: englishMatches ? englishPiece?.texts : nil)))
            }
        }
        // Unaligned English: all of it with the first paragraph, so none is lost.
        if aligned == nil, let englishPieces, let first = latinPieces.firstIndex(where: { !$0.isReference }) {
            var all: [String] = []
            for piece in englishPieces { all.append(contentsOf: piece.texts) }
            units[first] = .lesson(LessonParagraph(lines: latinPieces[first].texts, english: all))
        }
        return units
    }

    /// A lesson's pieces: reference lines (`isReference`, one text each) and paragraphs
    /// (their source lines).
    static func lessonPieces(_ text: String) -> [(isReference: Bool, texts: [String])] {
        var lines: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(line).trimmingCharacters(in: .whitespaces)
            // A stray `_` on the end of a verse (the English `Tempora/Pasc1-4`) isn't shown.
            if line.count > 1, line.hasSuffix("_") { line.removeLast() }
            lines.append(line)
        }
        var result: [(isReference: Bool, texts: [String])] = []
        var paragraph: [String] = []
        for index in lines.indices {
            let line = lines[index]
            if line.isEmpty || line.hasPrefix("&") || line.hasPrefix("$") { continue }
            if line == "_" {
                if !paragraph.isEmpty { result.append((false, paragraph)); paragraph = [] }
                continue
            }
            var nextLine: String?
            var probe = index + 1
            while probe < lines.count {
                if !lines[probe].isEmpty { nextLine = lines[probe]; break }
                probe += 1
            }
            let isReferenceLine = line.hasPrefix("!")
            let isTitleLine = paragraph.isEmpty && !isReferenceLine && (nextLine?.hasPrefix("!") ?? false)
            if isReferenceLine || isTitleLine {
                if !paragraph.isEmpty { result.append((false, paragraph)); paragraph = [] }
                let cleaned = DOMarkers.stripRubricMarkers(line).replacingOccurrences(of: "/:", with: "").replacingOccurrences(of: ":/", with: "")
                result.append((true, [cleaned]))
                continue
            }
            var body = line
            if let label = body.firstMatch(of: /^[vr]\.\s*/) { body = String(body[label.range.upperBound...]) }    // `v.` initial, `r.` large first letter (`horas.pl:178-185`)
            // A verse number goes, and the verse starts with a capital, as DO sets it
            // (`lectio`, `:1325-1330`, `s/^./\u$&/`).
            if let number = body.range(of: #"^[0-9]+\s+"#, options: .regularExpression) {
                body.removeSubrange(number)
                if let first = body.first { body = first.uppercased() + body.dropFirst() }
            }
            body = body.replacingOccurrences(of: "/:", with: "").replacingOccurrences(of: ":/", with: "")
                .replacingOccurrences(of: "¶", with: "").trimmingCharacters(in: .whitespaces)
            if !body.isEmpty { paragraph.append(body) }
        }
        if !paragraph.isEmpty { result.append((false, paragraph)) }
        return result
    }

    /// `officestring` (`SetupString.pl:723-780`): from August to November (and after
    /// Epiphany) a week's file of the Sundays after Pentecost takes the sections of its
    /// monthday file (`Tempora/083-1` for the Monday of August's third week), the
    /// Scripture of those weeks. The monthday file's section wins when it has one.
    func monthdayMerged(_ path: String, section: String, matins: MatinsDay, resolver: SectionResolver) -> String {
        guard Self.participatesInMonthdayMerge(office: path),
            let key = Computus.monthday(day: matins.day, month: matins.month, year: matins.year, tomorrow: false)
        else { return path }
        let monthdayPath = "Tempora/\(key)"
        return resolver.sectionExists(path: monthdayPath, section: section) ? monthdayPath : path
    }

    /// `&Gloria1` (the *Gloria Patri* alone) and `&Gloria2` (with *Sicut erat*): in
    /// Passiontide, outside saints' offices, the small note *Gloria omittitur* instead
    /// (`horas.pl:303-311`).
    func gloriaLines(_ name: String, matins: MatinsDay, resolver: SectionResolver) -> [String] {
        func has(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil }
        if has(matins.rule, "Requiem gloria") { return resolver.expandMacroLine("$Requiem").split(separator: "\n").map(String.init) }
        if has(name, "Gloria[12]"), has(matins.weekName, "Quad[56]"), !matins.office.hasPrefix("Sancti"), !has(matins.rule, "Gloria responsory") {
            let note = resolver.resolve(path: "Psalterium/Common/Translate", section: "Gloria omittitur")
                .split(separator: "\n").first.map(String.init) ?? "Gloria omittitur"
            return ["!" + note]
        }
        let section = name == "Gloria1" ? "Gloria1" : "Gloria"
        return resolver.expandMacroLine("$" + section).split(separator: "\n").map(String.init)
    }

    static func unbracketingReferences(_ text: String) -> String {
        // `parenthesised_text` (`:1398-1403`): only a short or numbered one; a longer
        // aside keeps its brackets.
        text.replacing(/\(([^(]*?[.,\d][^(]*?)\)/) { match in
            let inner = String(match.1)
            return inner.count < 20 || inner.contains(/[0-9][.,]/) ? inner : "(\(inner))"
        }
    }

    static func romanNumeral(_ number: Int) -> String {
        ["", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii"][min(max(number, 0), 12)]
    }
}
