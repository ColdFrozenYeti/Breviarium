import Foundation

// Beta 2: the sections of the day hours that Vespers doesn't have, each a port of the DO
// routine named in its doc comment (`web/cgi-bin/horas/`). `HourAssembler.assemble(_:)`
// walks each hour's skeleton (`Ordinarium/<hour>.txt`) and calls these for the groups
// only those hours contain; everything shared with Vespers (Incipit, Oratio, Conclusio,
// the psalm text itself) goes through the existing Vespers code.

extension HourAssembler {

    // MARK: - gettempora

    /// `horascommon.pl:2288-2343`, `gettempora($caller)`: the season key the psalter files
    /// index by. `officeTitle` is `$dayname[1]` (the winning office's title).
    static func tempora(caller: String, weekName: String, dayOfWeek: Int, day: Int, officeTitle: String) -> String {
        var name: String
        if weekName.hasPrefix("Adv"), caller != "Doxology", caller != "Nunc dimittis" {
            name = "Adv"
        } else if weekName.range(of: "^Quad[56]", options: .regularExpression) != nil, caller != "Doxology" {
            name = "Quad5"
        } else if weekName.range(of: "^Quad(?!p)", options: .regularExpression) != nil, caller != "Doxology" {
            name = "Quad"
        } else if weekName.hasPrefix("Pasc6") || (weekName.hasPrefix("Pasc5") && dayOfWeek > 3 && !officeTitle.hasPrefix("Dominica")) {
            name = "Asc"
        } else if weekName.range(of: "^Pasc[0-5]", options: .regularExpression) != nil {
            name = "Pasch"
        } else if weekName.hasPrefix("Pasc7") {
            name = "Pent"
        } else {
            name = ""
        }
        if caller == "Psalmi minor" || caller == "Invitatorium" || caller == "Hymnus matutinum", name == "Asc" || name == "Pent" {
            name = "Pasch"
        }
        if caller == "Lectio brevis Prima", name.isEmpty { name = "Per Annum" }
        // `:2311-2313`: the Roman office's psalter hymn is the weekday's own.
        if caller == "Hymnus major", name.isEmpty { name = "Day\(dayOfWeek)" }
        if caller.hasPrefix("Capitulum") || caller.hasSuffix("major"), name.isEmpty {
            let duplex = caller == "Capitulum minor" && officeTitle.range(of: "Duplex", options: .caseInsensitive) != nil
                && officeTitle.range(of: "Dominica|Vigilia", options: [.regularExpression, .caseInsensitive]) == nil
            name = dayOfWeek == 0 || duplex ? "Dominica" : "Feria"
        }
        // Under 1960 (`$version =~ /196/`) every caller but the minor psalter and the
        // Nunc dimittis gets the Christmas and Epiphany keys.
        if caller != "Psalmi minor", caller != "Nunc dimittis" {
            if weekName.hasPrefix("Nat") {
                name = day >= 6 && day < 13 ? "Epi" : "Nat"
            } else if weekName.range(of: "^Epi[01]", options: .regularExpression) != nil, day < 14 {
                name = "Epi"
            }
        }
        return name
    }

    // MARK: - Shared lookups

    /// The same `(path, section)` in Latin and, when present there, in English.
    func bothTexts(path: String, section: String, resolver: SectionResolver, englishResolver: SectionResolver?) -> (latin: String, english: String?) {
        let latin = resolver.resolve(path: path, section: section)
        let english = englishResolver.flatMap { eng in
            eng.sectionExists(path: path, section: section) ? eng.resolve(path: path, section: section) : nil
        }
        return (latin, english)
    }

    /// `getproprium($name, $lang, $flag)` (`specials.pl:443-520`): the winning office's own
    /// section, else (with `flag`, or for an `ex` Commune) its Commune chain. `substitute`
    /// is the Commune-file-only replacement key (`:463-469`), tried at each Commune hop.
    func proprium(
        _ section: String, flag: Bool, winner: OccurrenceResult, resolver: SectionResolver, weekName: String, substitute: String? = nil
    ) -> (path: String, section: String)? {
        let office = winner.winningPath
        if resolver.sectionExists(path: office, section: section) { return (office, section) }
        let reference = winner.winningRank.communeReference
        guard !reference.isEmpty, flag || reference.lowercased().hasPrefix("ex") else { return nil }
        var current = reference
        for _ in 0..<5 {
            guard let path = Self.paschalCommuneFallbackPath(current, weekName: weekName, resolver: resolver) else { return nil }
            if resolver.sectionExists(path: path, section: section) { return (path, section) }
            if let substitute, path.hasPrefix("Commune"), resolver.sectionExists(path: path, section: substitute) {
                return (path, substitute)
            }
            guard let next = OfficeRank(rankFieldValue: resolver.resolveRank(path: path))?.communeReference,
                !next.isEmpty, next != current
            else { return nil }
            if next.lowercased().hasPrefix("vide"), !flag { return nil }
            current = next
        }
        return nil
    }

    /// The Commune's own `[Rule]` (`$communerule`), which DO sets only for an `ex`
    /// Commune (`horascommon.pl:1764-1768`): 2 January's `vide Sancti/01-01` doesn't pass
    /// on the Circumcision's "Psalmi Dominica".
    func communeRule(winner: OccurrenceResult, resolver: SectionResolver, weekName: String) -> String {
        let reference = winner.winningRank.communeReference
        guard reference.lowercased().hasPrefix("ex"), let path = Self.paschalCommuneFallbackPath(reference, weekName: weekName, resolver: resolver),
            resolver.sectionExists(path: path, section: "Rule")
        else { return "" }
        return resolver.resolve(path: path, section: "Rule")
    }

    /// DO's `$rank`.
    private static func rank(_ winner: OccurrenceResult) -> Double { Double(winner.winningRank.numericPrecedence) }

    private static let psalmiDominica = #"Psalmi\s*(minores)*\s*Dominica"#
    private static let psalmiExPsalterio = #"Psalmi\s*(minores)*\s*ex Psalterio"#

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Psalmody of Prime, the little hours and Compline

    /// `psalmi.pl:29-331`, `psalmi_minor`, for the 1960 Roman office: one antiphon over
    /// the whole psalmody, from `Psalmi minor.txt`'s day line, the season's own set, the
    /// office's own `[Ant <hour>]`, or Lauds' antiphons on I class feasts; the psalms from
    /// the day line (Sunday's on feasts that say so). `antetpsalm` (`:661-707`) then shows
    /// the antiphon whole before the psalms (`$duplexf`, always under 1960) and without
    /// its asterisk after them.
    func assembleMinorPsalmodia(
        hour: CanonicalHour, winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section {
        let psalterPath = "Psalterium/Psalmi/Psalmi minor"
        let dayOfWeek = macroContext.dayOfWeek
        let rule = macroContext.winningRule
        let rank = Self.rank(winner)
        let title = winner.winningRank.title
        let office = winner.winningPath
        let communeRule = communeRule(winner: winner, resolver: resolver, weekName: macroContext.weekName)
        func lines(_ path: String, _ section: String, _ resolver: SectionResolver) -> [String] {
            resolver.resolve(path: path, section: section).split(separator: "\n").map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        // The day line.
        let dayLines = lines(psalterPath, hour.doName, resolver)
        var index = 2 * dayOfWeek
        if Self.matches(rule, Self.psalmiDominica) || (Self.matches(communeRule, Self.psalmiDominica) && !Self.matches(rule, Self.psalmiExPsalterio)) {
            index = 0
        }
        let sanctiOrCommune = Self.matches(office, "Sancti|C[1-7]")
        if Self.matches(rule, "horas1960 feria") || (sanctiOrCommune && rank < 5)
            || ((sanctiOrCommune || Self.matches(office, "Nat[23]")) && rank < 6 && hour != .completorium)
        {
            index = 2 * dayOfWeek
        }
        if hour == .completorium, dayOfWeek == 6, Self.matches(title, "Dominica"), !macroContext.weekName.hasPrefix("Nat") {
            index = 12
        }
        // Where the antiphon comes from, so the English can take the same one.
        var antiphonSource: (path: String, section: String, line: Int?) = (psalterPath, hour.doName, index)
        var psalmsLine = index + 1 < dayLines.count ? dayLines[index + 1] : ""

        if hour == .completorium {
            if office.hasPrefix("Tempora"), dayOfWeek > 0, Self.matches(title, "Dominica"), rank < 6 {
                // Keeps the day's psalms.
            } else if Self.matches(rule, Self.psalmiDominica) || Self.matches(communeRule, Self.psalmiDominica), rank >= 6 {
                antiphonSource = (psalterPath, hour.doName, 0)
                psalmsLine = dayLines.count > 1 ? dayLines[1] : psalmsLine
            }
            let vespera = macroContext.isFirstVespers ? 1 : 3
            if resolver.sectionExists(path: office, section: "Ant Completorium\(vespera)") {
                antiphonSource = (office, "Ant Completorium\(vespera)", nil)
            } else if resolver.sectionExists(path: office, section: "Ant Completorium") {
                antiphonSource = (office, "Ant Completorium", nil)
            }
        }

        // The season's antiphon (`:170-221`).
        if office.hasPrefix("Tempora") || macroContext.weekName.range(of: "pasc", options: .caseInsensitive) != nil {
            var seasonIndex: Int = switch hour {
            case .prima: 0
            case .tertia: 1
            case .sexta: 2
            case .nona: 4
            default: -1
            }
            var name = Self.tempora(
                caller: "Psalmi minor", weekName: macroContext.weekName, dayOfWeek: dayOfWeek, day: macroContext.officeDay, officeTitle: title
            )
            if name == "Adv" {
                name = macroContext.weekName
                if macroContext.officeDay > 16, macroContext.officeDay < 24, dayOfWeek > 0 { name = "Adv4\(dayOfWeek + 1)" }
            }
            if name == "Pasch", !macroContext.weekName.hasPrefix("Pasc7") || hour == .completorium { seasonIndex = 0 }
            if !name.isEmpty, seasonIndex >= 0, resolver.sectionExists(path: psalterPath, section: name) {
                antiphonSource = (psalterPath, name, seasonIndex)
            }
        }

        // The office's own antiphon (`:223-261`), not at Compline.
        if hour != .completorium {
            var proper = proprium("Ant \(hour.doName)", flag: false, winner: winner, resolver: resolver, weekName: macroContext.weekName)
                .map { (path: $0.path, section: $0.section, line: Int?.none) }
            if proper == nil, !Self.matches(rule, Self.psalmiExPsalterio), !(rank < 6 && dayOfWeek > 0) {
                proper = laudsAntiphonForHour(hour: hour, winner: winner, rule: rule, communeRule: communeRule, rank: rank, resolver: resolver, weekName: macroContext.weekName)
            }
            if let proper { antiphonSource = proper }
        }

        func antiphon(_ resolver: SectionResolver, english: Bool) -> String? {
            guard resolver.sectionExists(path: antiphonSource.path, section: antiphonSource.section) else { return nil }
            var text: String
            if let line = antiphonSource.line {
                let all = lines(antiphonSource.path, antiphonSource.section, resolver)
                guard line < all.count else { return nil }
                text = all[line]
            } else {
                text = resolver.resolve(path: antiphonSource.path, section: antiphonSource.section)
                    .split(separator: "\n").first.map(String.init) ?? ""
            }
            if let equals = text.range(of: #"^.*?=\s*"#, options: .regularExpression) { text.removeSubrange(equals) }
            text = text.components(separatedBy: ";;").first ?? text
            text = text.trimmingCharacters(in: .whitespaces)
            text = Self.applyingSeasonalAlleluia(to: text, weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers, english: english)
            return substituteName(in: text, office: office, resolver: resolver, isAntiphon: true)
        }
        // `psalmi.pl:275-281`: "Minores sine Antiphona" (Easter week).
        let withoutAntiphon = Self.matches(rule, "Minores sine Antiphona")
        let latinAntiphon = withoutAntiphon ? "" : antiphon(resolver, english: false) ?? ""
        let englishAntiphon = withoutAntiphon ? nil : englishResolver.flatMap { antiphon($0, english: true) }

        var psalms = psalmsLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if hour == .prima {
            // `:292-299`: 1960 drops Prime's bracketed psalm.
            psalms = psalms.filter { !$0.hasPrefix("[") }
            // `:122`: psalm 117 gives way to 53 with Lauds II, or by rule.
            if Self.matches(rule, "Prima=53") || laudesScheme(winner: winner, macroContext: macroContext) == 2 {
                psalms = psalms.map { $0 == "117" ? "53" : $0 }
            }
            // `:252-266`, `:301-305`: on feasts with Sunday psalms (I class under 1960) the
            // first psalm is 53.
            var feast = (Self.matches(rule, Self.psalmiDominica) || Self.matches(communeRule, Self.psalmiDominica))
                && !Self.matches(rule, Self.psalmiExPsalterio) && !(rank < 6 && dayOfWeek > 0)
            if rank < 6 { feast = false }
            if Self.matches(title, "Dominica"), !Self.matches(macroContext.weekName, "Nat|Pasc6") { feast = false }
            if feast, !psalms.isEmpty { psalms[0] = "53" }
            // `:309-323`: the Athanasian Creed, under 1960 only on Trinity Sunday.
            if macroContext.weekName.hasPrefix("Pent01"), dayOfWeek == 0, !Self.matches(rule, "Non dicitur Quicumque") {
                psalms.append("234")
            }
        }

        var units: [Unit] = []
        if !latinAntiphon.isEmpty { units.append(.antiphon(latinAntiphon, english: englishAntiphon)) }
        for (offset, psalm) in psalms.enumerated() {
            let (psalmTitle, content) = psalmUnits(number: psalm, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)
            var psalmContent = content
            if offset == 0, !latinAntiphon.isEmpty {
                let (tagged, latinMatched, englishMatched) = Self.applyingAntiphonDagger(
                    antiphon: latinAntiphon, englishAntiphon: englishAntiphon, psalmContent: psalmContent
                )
                psalmContent = tagged
                if latinMatched || englishMatched {
                    units[units.count - 1] = .antiphon(
                        latinMatched ? "\(latinAntiphon) ‡" : latinAntiphon,
                        english: englishMatched ? englishAntiphon.map { "\($0) ‡" } : englishAntiphon
                    )
                }
            }
            units.append(.psalmTitle(Self.numberedPsalmTitle(psalmTitle, offset + 1)))
            units.append(contentsOf: psalmContent)
        }
        if !latinAntiphon.isEmpty {
            units.append(.antiphon(Self.closingAntiphon(latinAntiphon), english: englishAntiphon.map(Self.closingAntiphon)))
        }
        return Section(kind: .psalmodia, units: units)
    }

    /// `specials.pl:543-573`, `getanthoras`: on I class feasts whose rule says
    /// "Antiphonas horas", the hours take Lauds' antiphons (Prime the 1st, Terce the 2nd,
    /// Sext the 3rd, None the 5th).
    private func laudsAntiphonForHour(
        hour: CanonicalHour, winner: OccurrenceResult, rule: String, communeRule: String, rank: Double, resolver: SectionResolver, weekName: String
    ) -> (path: String, section: String, line: Int?)? {
        guard Self.matches(rule, "Antiphonas horas") || Self.matches(communeRule, "Antiphonas horas"), rank >= 6 else { return nil }
        guard let location = proprium("Ant Laudes", flag: false, winner: winner, resolver: resolver, weekName: weekName) else { return nil }
        let count = resolver.resolve(path: location.path, section: location.section).split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        guard count > 3 else { return nil }
        let line = switch hour {
        case .prima: 0
        case .tertia: 1
        case .sexta: 2
        default: 4
        }
        return (location.path, location.section, line)
    }

    // MARK: - Hymn of Prime, the little hours and Compline

    /// `hymni.pl:5-65`, `gethymn`, for the minor hours: always the psalter's own hymn
    /// (`Minor Special` / `Prima Special`), Veni Creator at Terce in Pentecost week. The
    /// 1960 rubrics never change the doxology (`:44`), so the `*` is only removed.
    func assembleMinorHymn(
        hour: CanonicalHour, winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> [Section] {
        guard !hour.isMajor else { return [] }
        var name = "Hymnus \(hour.doName)"
        if hour == .tertia, macroContext.weekName.hasPrefix("Pasc7") { name = "Hymnus Pasc7 Tertia" }
        let path = hour == .prima ? "Psalterium/Special/Prima Special" : "Psalterium/Special/Minor Special"
        guard resolver.sectionExists(path: path, section: name) else { return [] }
        let texts = bothTexts(path: path, section: name, resolver: resolver, englishResolver: englishResolver)
        func stanzas(_ text: String) -> [String] {
            Self.hymnStanzas(text.replacingOccurrences(of: #"\*\s*"#, with: "", options: .regularExpression))
        }
        let latin = stanzas(texts.latin)
        let english = texts.english.map(stanzas)
        return [Section(kind: .hymnus, units: Self.pairedStanzas(latin: latin, english: english))]
    }

    // MARK: - Chapter and short responsory

    /// `capitulis.pl:229-260`, `capitulum_minor`, and `:161-227`, `minor_reponsory`: the
    /// chapter (the office's own, Terce taking Lauds'; else the psalter's for the season or
    /// the day), then the short responsory and its versicle, the office's own or the
    /// psalter's. Compline's are fixed: `[Completorium]`, `[Responsory Completorium]` and
    /// `[Versum 4]`.
    func assembleMinorCapitulum(
        hour: CanonicalHour, winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> [Section] {
        guard hour.isLittleHour || hour == .completorium else { return [] }
        let special = "Psalterium/Special/Minor Special"
        let weekName = macroContext.weekName
        let seasonName: String
        if hour == .completorium {
            seasonName = "Completorium"
        } else {
            seasonName = Self.tempora(
                caller: "Capitulum minor", weekName: weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay,
                officeTitle: winner.winningRank.title
            ) + " \(hour.doName)"
        }

        // The chapter.
        let properName = hour == .tertia ? "Capitulum Laudes" : "Capitulum \(hour.doName)"
        let chapterLocation = proprium(properName, flag: true, winner: winner, resolver: resolver, weekName: weekName)
            ?? (special, seasonName)
        var units: [Unit] = []
        if resolver.sectionExists(path: chapterLocation.path, section: chapterLocation.section) {
            let texts = bothTexts(path: chapterLocation.path, section: chapterLocation.section, resolver: resolver, englishResolver: englishResolver)
            let deoGratias = bothTexts(path: SectionResolver.prayersPath, section: "Deo gratias", resolver: resolver, englishResolver: englishResolver)
            units.append(contentsOf: Self.capitulumUnits(latin: texts.latin, english: texts.english, thanks: deoGratias))
        }

        // The short responsory and versicle.
        var latinResponsory = ""
        var englishResponsory: String?
        func append(_ location: (path: String, section: String)?, separator: Bool) {
            guard let location, resolver.sectionExists(path: location.path, section: location.section) else { return }
            let raw = rawBoth(path: location.path, section: location.section, resolver: resolver, englishResolver: englishResolver)
            if separator, !latinResponsory.isEmpty { latinResponsory += "\n_\n" }
            latinResponsory += raw.latin
            if let english = raw.english {
                englishResponsory = (englishResponsory.map { $0.isEmpty || !separator ? $0 : $0 + "\n_\n" } ?? "") + english
            }
        }
        if hour == .completorium {
            if resolver.sectionExists(path: special, section: "Responsory Completorium") {
                append((special, "Responsory Completorium"), separator: false)
            } else {
                append((special, "Responsory breve Completorium"), separator: false)
                append((special, "Versum Completorium"), separator: true)
            }
            append((special, "Versum 4"), separator: true)
        } else {
            let versumSubstitute: String? = switch hour {
            case .tertia: "Nocturn 2 Versum"
            case .sexta: "Nocturn 3 Versum"
            case .nona: "Versum 2"
            default: nil
            }
            if let own = proprium("Responsory \(hour.doName)", flag: true, winner: winner, resolver: resolver, weekName: weekName) {
                append(own, separator: false)
            } else if let breve = proprium("Responsory Breve \(hour.doName)", flag: true, winner: winner, resolver: resolver, weekName: weekName) {
                append(breve, separator: false)
                append(
                    proprium("Versum \(hour.doName)", flag: true, winner: winner, resolver: resolver, weekName: weekName, substitute: versumSubstitute),
                    separator: true
                )
            } else if let versum = proprium(
                "Versum \(hour.doName)", flag: true, winner: winner, resolver: resolver, weekName: weekName, substitute: versumSubstitute
            ) {
                // `$wr .= $vers` with no responsory of the office's own: the versicle alone.
                append(versum, separator: false)
            } else if resolver.sectionExists(path: special, section: "Responsory \(seasonName)") {
                append((special, "Responsory \(seasonName)"), separator: false)
            } else {
                append((special, "Responsory breve \(seasonName)"), separator: false)
                append((special, "Versum \(seasonName)"), separator: true)
            }
        }
        let latinLines = shortResponsoryLines(latinResponsory, resolver: resolver, winner: winner, macroContext: macroContext, english: false)
        let englishLines = englishResponsory.map {
            shortResponsoryLines($0, resolver: englishResolver ?? resolver, winner: winner, macroContext: macroContext, english: true)
        }
        units.append(contentsOf: Self.unitsFromLines(latinLines, english: englishLines))
        return [Section(kind: .capitulum, units: units)]
    }

    /// A section's text with conditionals and `@`/`$` references resolved but its `&`
    /// macros left as they are (`&Gloria`), for `postprocess_short_resp`.
    func rawBoth(path: String, section: String, resolver: SectionResolver, englishResolver: SectionResolver?) -> (latin: String, english: String?) {
        var plain = resolver
        plain.macroContext = nil
        var plainEnglish = englishResolver
        plainEnglish?.macroContext = nil
        return bothTexts(path: path, section: section, resolver: plain, englishResolver: plainEnglish)
    }

    /// `horas.pl:697-726`, `postprocess_short_resp`: `&Gloria` becomes `&Gloria1` (the
    /// first half-verse only, and none in Passiontide outside the saints' offices), and in
    /// Paschaltide the responsory takes its alleluias. Then the remaining macros resolve.
    func shortResponsoryLines(
        _ text: String, resolver: SectionResolver, winner: OccurrenceResult, macroContext: MacroContext, english: Bool
    ) -> [String] {
        let weekName = macroContext.weekName
        let gloria1Omitted = weekName.range(of: "Quad[56]", options: .regularExpression) != nil
            && !winner.winningPath.contains("Sancti") && !Self.matches(macroContext.winningRule, "Gloria responsory")
        var lines: [String] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line == "&Gloria" || line == "&Gloria1" {
                // DO shows the omission (`horas.pl:303-311`), as for the psalms' Gloria.
                guard !gloria1Omitted else { lines.append(english ? "!omit Glory be" : "!Gloria omittitur"); continue }
                lines.append(contentsOf: resolver.resolve(path: SectionResolver.prayersPath, section: "Gloria1")
                    .split(separator: "\n").map(String.init))
            } else if line.hasPrefix("&"), let macroContext = resolver.macroContext ?? Optional(macroContext),
                let resolved = ScriptMacros.resolve(String(line.dropFirst()), context: macroContext, resolver: resolver, isEnglish: english)
            {
                lines.append(contentsOf: resolved.split(separator: "\n").map(String.init))
            } else {
                lines.append(rawLine)
            }
        }
        let paschal = weekName.range(of: "Pasc", options: .caseInsensitive) != nil
        guard paschal || Self.matches(macroContext.winningRule, "Responsory Breve cum Alleluja") && macroContext.hour.isLittleHour
        else { return lines.map { Self.processingInlineAlleluias($0, paschal: paschal) } }
        let alleluiaDuplex = resolver.resolve(path: SectionResolver.prayersPath, section: "Alleluia Duplex")
            .split(separator: "\n").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let alleluia = alleluiaDuplex.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Allelúia"
        let cumAlleluia = Self.matches(macroContext.winningRule, "Responsory Breve cum Alleluja")
        var inResponsory = false
        var rLines = 0
        var sawVersicle = false
        for index in lines.indices {
            let line = lines[index]
            if line.hasPrefix("R.br.") { inResponsory = true; rLines = 0; sawVersicle = false }
            if inResponsory {
                if line.hasPrefix("V.") { sawVersicle = true }
                if line.hasPrefix("R."), !line.hasPrefix("R.br.") { rLines += 1 }
                if sawVersicle, line.hasPrefix("R."), !line.hasPrefix("R.br.") {
                    lines[index] = "R. \(alleluiaDuplex)"
                    sawVersicle = false
                } else if line.hasPrefix("R.") {
                    lines[index] = Self.ensuringDoubleAlleluia(line, alleluia: alleluia)
                }
                if line.hasPrefix("R."), !line.hasPrefix("R.br."), rLines >= 3 { inResponsory = false }
            } else if (line.hasPrefix("V.") || line.hasPrefix("R.")), !cumAlleluia {
                lines[index] = Self.ensuringSingleAlleluia(line, alleluia: alleluia)
            }
        }
        return lines.map { Self.processingInlineAlleluias($0, paschal: paschal) }
    }

    /// `LanguageTextTools.pm:55-73`, `process_inline_alleluias`, which `webdia.pl:681`
    /// runs over everything DO displays: a bracketed "(Allelúia.)" is unbracketed in
    /// Paschaltide and dropped otherwise (St Michael's `Versum Tertia`, borrowed from
    /// 8 May).
    static func processingInlineAlleluias(_ line: String, paschal: Bool) -> String {
        guard line.range(of: "(", options: .literal) != nil else { return line }
        let replaced = line.replacingOccurrences(
            of: #"\((all[ae]l[uú][ij]a[^)]*)\)"#, with: paschal ? " $1 " : "", options: [.regularExpression, .caseInsensitive]
        )
        guard replaced != line else { return line }
        return replaced.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    /// `LanguageTextTools.pm:103-118`, `ensure_double_alleluia`.
    static func ensuringDoubleAlleluia(_ line: String, alleluia: String) -> String {
        let pattern = #"(?i)all[ae]l[uú][ij]a[,.] all[ae]l[uú][ij]a\p{P}?\s*$"#
        guard line.range(of: pattern, options: .regularExpression) == nil else { return line }
        var text = line
        if let star = text.range(of: #"\s*\*\s*(.)"#, options: .regularExpression) {
            let following = text[star].last.map { String($0).lowercased() } ?? ""
            text.replaceSubrange(star, with: " " + following)
        }
        if let tail = text.range(of: #"\p{P}?\s*$"#, options: .regularExpression) { text.removeSubrange(tail) }
        return text + ", * \(alleluia), \(alleluia.lowercased())."
    }

    /// `LanguageTextTools.pm:78-96`, `ensure_single_alleluia`.
    static func ensuringSingleAlleluia(_ line: String, alleluia: String) -> String {
        guard line.range(of: #"(?i)all[ae]l[uú][ij]a\p{P}?\)?\s*$"#, options: .regularExpression) == nil,
            !line.trimmingCharacters(in: .whitespaces).isEmpty
        else { return line }
        var text = line
        if let tail = text.range(of: #"\p{P}?\s*$"#, options: .regularExpression) { text.removeSubrange(tail) }
        return text + ", \(alleluia.lowercased())."
    }

    // MARK: - Compline

    /// `specials.pl:210-214`: Compline's short lesson, `[Lectio Completorium]`, then the
    /// rest of its group (`Adiutórium nostrum`, the Confiteor, `Convérte nos`, the opening
    /// `Deus in adiutórium`).
    func assembleLectioBrevis(
        hour: CanonicalHour, group: SkeletonGroup, englishGroup: SkeletonGroup?, resolver: SectionResolver, englishResolver: SectionResolver?
    ) -> [Section] {
        guard hour == .completorium else {
            return [Section(kind: .lectioBrevis, units: Self.unitsFromLines(group.lines, english: englishGroup?.lines))]
        }
        let texts = bothTexts(path: "Psalterium/Special/Minor Special", section: "Lectio Completorium", resolver: resolver, englishResolver: englishResolver)
        func split(_ text: String) -> (reading: String, rest: [String]) {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let restStart = lines.dropFirst().firstIndex { $0.hasPrefix("V.") || $0.hasPrefix("R.") } ?? lines.count
            return (lines[..<restStart].joined(separator: "\n"), Array(lines[restStart...]))
        }
        let latin = split(texts.latin)
        let english = texts.english.map(split)
        var units = Self.capitulumUnits(latin: latin.reading, english: english?.reading)
        units.append(contentsOf: Self.unitsFromLines(latin.rest, english: english?.rest))
        units.append(contentsOf: Self.unitsFromLines(group.lines, english: englishGroup?.lines))
        return [Section(kind: .lectioBrevis, units: units)]
    }

    /// `horas.pl:508-568`, `canticum`, at Compline: the Nunc dimittis (canticle 233), with
    /// the office's own `[Ant 4<vespera>]` (Easter week) or the psalter's `[Ant 4]`.
    func assembleNuncDimittis(
        winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section {
        let vespera = macroContext.isFirstVespers ? 1 : 3
        let location = proprium("Ant 4\(vespera)", flag: false, winner: winner, resolver: resolver, weekName: macroContext.weekName)
            ?? ("Psalterium/Special/Minor Special", "Ant 4")
        let texts = bothTexts(path: location.path, section: location.section, resolver: resolver, englishResolver: englishResolver)
        func antiphons(_ text: String, english: Bool) -> (open: String, close: String) {
            // A second line is the closing antiphon as it stands (`$s[-1] = "Ant. $ant2"`,
            // `horas.pl:568`): Easter week's *Hæc dies*.
            let lines = text.split(separator: "\n").map { String($0).components(separatedBy: ";;").first ?? String($0) }
            let open = lines.first.map {
                Self.applyingSeasonalAlleluia(to: $0, weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers, english: english)
            } ?? ""
            return (open, lines.count > 1 ? lines[1] : Self.closingAntiphon(open))
        }
        let latin = antiphons(texts.latin, english: false)
        let english = texts.english.map { antiphons($0, english: true) }
        var units: [Unit] = []
        if !latin.open.isEmpty { units.append(.antiphon(latin.open, english: english?.open)) }
        let path = "Psalterium/Psalmorum/Psalm233"
        let text = resolver.resolvePsalmText(path: path, section: RawSectionParser.wholeFileSectionName)
        let latinVerses = Psalm.parseVerses(text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        let englishVerses: [PsalmVerse]? = englishResolver.flatMap { eng in
            guard eng.sectionExists(path: path, section: RawSectionParser.wholeFileSectionName) else { return nil }
            return Psalm.parseVerses(eng.resolvePsalmText(path: path, section: RawSectionParser.wholeFileSectionName)
                .split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        }
        units.append(contentsOf: Self.pairedVerses(latin: latinVerses, english: englishVerses))
        units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
        if !latin.close.isEmpty { units.append(.antiphon(latin.close, english: english?.close)) }
        return Section(kind: .canticum, units: units)
    }

    /// `specials.pl:313-338`: the Marian antiphon of the season, then `&Divinum_auxilium`
    /// and the rest of the group. The date is the office's own (tomorrow's on first
    /// Vespers, as DO re-derives `$day`/`$month`).
    func assembleAntiphonaFinalis(
        group: SkeletonGroup, englishGroup: SkeletonGroup?, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section {
        let weekName = macroContext.weekName
        // DO's `$month`/`$day` here are the date asked for, not the office's: Compline on
        // 1 February still has Alma Redemptoris, before the Purification.
        let (month, day) = (macroContext.month, macroContext.day)
        let name: String
        if weekName.range(of: "Adv|Nat", options: [.regularExpression, .caseInsensitive]) != nil || month == 1 || (month == 2 && day < 2)
            || (month == 2 && day == 2 && macroContext.hour != .completorium)
        {
            name = "ant Alma Redemptoris Mater"
        } else if month == 2 || month == 3 || weekName.range(of: "Quad", options: .caseInsensitive) != nil,
            weekName.range(of: "Pasc", options: .caseInsensitive) == nil
        {
            name = "ant Ave Regina caelorum"
        } else if weekName.range(of: "Pasc") != nil {
            name = "ant Regina caeli"
        } else {
            name = "ant Salve Regina"
        }
        let antiphon = bothTexts(path: SectionResolver.prayersPath, section: name, resolver: resolver, englishResolver: englishResolver)
        let auxilium = ScriptMacros.resolve("Divinum_auxilium", context: macroContext, resolver: resolver)
        let englishAuxilium = englishResolver.flatMap { ScriptMacros.resolve("Divinum_auxilium", context: macroContext, resolver: $0, isEnglish: true) }
        func lines(_ text: String?) -> [String] { text?.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) ?? [] }
        let latinLines = lines(antiphon.latin) + lines(auxilium) + group.lines
        let englishLines: [String]? = englishResolver == nil ? nil : lines(antiphon.english) + lines(englishAuxilium) + (englishGroup?.lines ?? [])
        // The antiphon's lines are one text, set like a hymn stanza, not a paragraph each.
        var units = Self.unitsFromLines(latinLines, english: englishLines)
        let leading = units.prefix { if case .prose = $0 { true } else { false } }
        if leading.count > 1 {
            var latin: [String] = []
            var english: [String] = []
            for case .prose(let text, let englishText) in leading {
                latin.append(text.trimmingCharacters(in: .whitespaces))
                if let englishText { english.append(englishText.trimmingCharacters(in: .whitespaces)) }
            }
            let merged = Unit.prose(latin.joined(separator: "\n"), english: english.count == latin.count ? english.joined(separator: "\n") : nil)
            units.replaceSubrange(0..<leading.count, with: [merged])
        }
        return Section(kind: .antiphonaFinalis, units: units)
    }

    // MARK: - An office's own form of the hour

    /// `specials.pl:36-37` and `loadspecial` (`:768-776`): the office's `[Special <hour>]`
    /// is the whole hour, its `&psalm(n)` lines expanded as psalms with their titles
    /// (`horasscripts.pl`, `psalm`), everything else as ordinary lines.
    func assembleSpecialHour(
        path: String, section: String, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Hour {
        // A chunk is a psalm, a `#Heading` (a new section, as DO shows it), or plain lines.
        func chunks(_ text: String) -> [(psalm: String?, heading: String?, lines: [String])] {
            var result: [(psalm: String?, heading: String?, lines: [String])] = [(nil, nil, [])]
            for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("#") {
                    result.append((nil, String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces), []))
                    result.append((nil, nil, []))
                } else if let match = trimmed.firstMatch(of: /^&psalm\((\d+)(?:,\s*'?(\w+)'?,\s*'?(\w+)'?)?\)$/) {
                    // `&psalm(37,1,11)`: verses 1-11 (`horasscripts.pl:447-456`).
                    let spec = match.2.map { from in "\(match.1)(\(from)-\(match.3 ?? ""))" } ?? String(match.1)
                    result.append((spec, nil, []))
                    result.append((nil, nil, []))
                } else {
                    result[result.count - 1].lines.append(line)
                }
            }
            return result
        }
        // `horasscripts.pl:693-712`, `special($name, $lang)`: the office's own section in
        // place (All Souls). `$lang` picks the column's office (`columnsel`), so the
        // English file's `&special('Conclusio', 'Latin')` shows the Latin there, as DO does.
        func expandingSpecials(_ text: String, _ own: SectionResolver) -> String {
            text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
                guard let match = line.firstMatch(of: /^\s*&special\('([^']+)'(?:,\s*'(\w+)')?/) else { return String(line) }
                let name = String(match.1)
                // The Martyrology is a separate "hour" in a later beta (decided 2026-09-24).
                if name == "#Martyrologium" { return "" }
                guard match.2 == "Latin", own.isEnglish else {
                    return own.sectionExists(path: path, section: name) ? own.resolve(path: path, section: name) : String(line)
                }
                // The Latin section, its `&` macros still run in the column's own
                // language (`&Gloria` is "Eternal rest" there).
                var latinOnly = resolver
                latinOnly.macroContext = nil
                guard latinOnly.sectionExists(path: path, section: name) else { return String(line) }
                return latinOnly.resolve(path: path, section: name).split(separator: "\n", omittingEmptySubsequences: false).map { part in
                    guard part.hasPrefix("&"), let context = own.macroContext,
                        let resolved = ScriptMacros.resolve(String(part.dropFirst()), context: context, resolver: own, isEnglish: true)
                    else { return String(part) }
                    return resolved
                }.joined(separator: "\n")
            }.joined(separator: "\n")
        }
        let latin = chunks(expandingSpecials(resolver.resolve(path: path, section: section), resolver))
        let english = englishResolver.flatMap { eng in
            eng.sectionExists(path: path, section: section) ? chunks(expandingSpecials(eng.resolve(path: path, section: section), eng)) : nil
        }
        let pairEnglish = english?.count == latin.count
        var sections: [Section] = []
        var units: [Unit] = []
        var kind = Section.Kind.introductio
        var psalmNumber = 0
        for (index, chunk) in latin.enumerated() {
            if let heading = chunk.heading {
                if !units.isEmpty { sections.append(Section(kind: kind, units: units)) }
                units = []
                kind = heading.lowercased().hasPrefix("oratio") ? .oratio : heading.lowercased().hasPrefix("conclusio") ? .conclusio : kind
            } else if let psalm = chunk.psalm {
                psalmNumber += 1
                let (title, content) = psalmUnits(number: psalm, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)
                let base = psalm.prefix { $0.isNumber }
                units.append(.psalmTitle(Self.numberedPsalmTitle(title, Int(base).map { $0 > 150 } == true ? nil : psalmNumber)))
                units.append(contentsOf: content)
            } else {
                units.append(contentsOf: Self.unitsFromLines(chunk.lines, english: pairEnglish ? english?[index].lines : nil))
            }
        }
        if !units.isEmpty { sections.append(Section(kind: kind, units: units)) }
        return Hour(sections: sections)
    }

    // MARK: - Omitted and replaced sections

    /// `specials.pl:57-117`, for the hours other than Vespers: "Capitulum Versum 2" puts the
    /// office's `[Versum 2]` in place of the chapter (not at Compline, where the chapter
    /// just goes), and "Omit <section>" drops a section. `true` when the group is done.
    func skipsGroup(
        _ name: String, hour: CanonicalHour, winner: OccurrenceResult, resolver: SectionResolver, englishResolver: SectionResolver?,
        macroContext: MacroContext, sections: inout [Section]
    ) -> Bool {
        let rule = macroContext.winningRule
        if name.contains("Capitulum"), let qualifier = Self.capitulumVersum2Qualifier(rule: rule) {
            if Self.matches(qualifier, "nisi ad Laudes"), hour == .laudes { return true }
            let excluded = (Self.matches(qualifier, "ad Laudes tantum") && hour != .laudes)
                || (Self.matches(qualifier, "ad Laudes et Vesperas") && !hour.isMajor)
            if !excluded {
                if hour != .completorium, let location = resolvedLocation(
                    office: winner.winningPath, communeReference: winner.winningRank.communeReference, section: "Versum 2",
                    resolver: resolver, weekName: macroContext.weekName
                ) {
                    let texts = bothTexts(path: location.path, section: location.section, resolver: resolver, englishResolver: englishResolver)
                    let firstLine = texts.latin.split(separator: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    if firstLine?.hasPrefix("V.") == true {
                        func lines(_ text: String) -> [String] { text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) }
                        sections.append(Section(kind: .versus, units: Self.unitsFromLines(lines(texts.latin), english: texts.english.map(lines))))
                    } else {
                        sections.append(Section(kind: .versus, units: [
                            .antiphon(DOMarkers.stripLineLabel(texts.latin), english: texts.english.map(DOMarkers.stripLineLabel)),
                        ]))
                    }
                }
                return true
            }
        }
        let keyword = name.split(separator: " ").first.map(String.init) ?? name
        let versum2KeepsChapter = name.contains("Capitulum") && hour == .laudes && Self.capitulumVersum2Qualifier(rule: rule) != nil
        return Self.ruleOmits(rule: rule, keyword: keyword, atMatins: hour == .matutinum) && !versum2KeepsChapter
    }

    // MARK: - Prime

    /// `horascommon.pl:1862-1878`, `$laudes`: Lauds II on the penitential days of the
    /// temporal cycle (Advent ferias, Septuagesima to Holy Week, Ember days outside
    /// Paschaltide), or by rule; Lauds I otherwise.
    func laudesScheme(winner: OccurrenceResult, macroContext: MacroContext) -> Int {
        let weekName = macroContext.weekName
        let ember = isEmberDay(
            weekName: weekName, dayOfWeek: macroContext.dayOfWeek, month: macroContext.officeMonth, winningRankTitle: winner.winningRank.title
        )
        let penitential = (weekName.hasPrefix("Adv") && macroContext.dayOfWeek != 0) || weekName.contains("Quad") || (ember && !weekName.hasPrefix("Pasc"))
        let temporal = winner.winningPath.hasPrefix("Tempora") && !Self.matches(winner.winningRank.title, "(Beatæ|Sanctæ) Mariæ")
        return (penitential && temporal) || Self.matches(macroContext.winningRule, "Laudes 2") ? 2 : 1
    }

    /// `specprima.pl:55-108`, `capitulum_prima`: under 1960 always the Sunday chapter,
    /// then the short responsory, whose versicle changes with the season
    /// (`get_prima_responsory`, `:110-136`), and the versicle.
    func assemblePrimeCapitulum(
        winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?,
        commemoratioRule: String = ""
    ) -> [Section] {
        let special = "Psalterium/Special/Prima Special"
        let deoGratias = bothTexts(path: SectionResolver.prayersPath, section: "Deo gratias", resolver: resolver, englishResolver: englishResolver)
        let chapter = bothTexts(path: special, section: "Dominica", resolver: resolver, englishResolver: englishResolver)
        var units = Self.capitulumUnits(latin: chapter.latin, english: chapter.english, thanks: deoGratias)

        var key = Self.tempora(
            caller: "Prima responsory", weekName: macroContext.weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay,
            officeTitle: winner.winningRank.title
        )
        if let match = macroContext.winningRule.firstMatch(of: /(?i)Doxology=(Nat|Epi|Pasch|Asc|Corp|Heart)/)
            ?? commemoratioRule.firstMatch(of: /(?i)Doxology=(Nat|Epi|Pasch|Asc|Corp|Heart)/)
        {
            key = String(match.1)
        }
        if macroContext.officeMonth == 12, macroContext.officeDay > 8, macroContext.officeDay < 16, macroContext.officeDay != 12 { key = "Adv" }
        if key == "Corp" || key == "Heart" { key = "" }

        func responsory(_ resolver: SectionResolver, english: Bool) -> [String] {
            var plain = resolver
            plain.macroContext = nil
            var lines = plain.resolve(path: special, section: "Responsory").split(separator: "\n").map(String.init)
            var versicle = key.isEmpty || !resolver.sectionExists(path: special, section: "Responsory \(key)")
                ? "" : resolver.resolve(path: special, section: "Responsory \(key)").trimmingCharacters(in: .whitespacesAndNewlines)
            if resolver.sectionExists(path: winner.winningPath, section: "Versum Prima") {
                versicle = resolver.resolve(path: winner.winningPath, section: "Versum Prima").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !versicle.isEmpty, lines.count > 2 { lines[2] = "V. \(versicle)" }
            lines.append("_")
            lines += plain.resolve(path: special, section: "Versum").split(separator: "\n").map(String.init)
            return shortResponsoryLines(lines.joined(separator: "\n"), resolver: resolver, winner: winner, macroContext: macroContext, english: english)
        }
        let latin = responsory(resolver, english: false)
        let english = englishResolver.map { responsory($0, english: true) }
        units.append(contentsOf: Self.unitsFromLines(latin, english: english))
        return [Section(kind: .capitulum, units: units)]
    }

    /// `specials.pl:297-302`: the Martyrology itself is a separate "hour" in a later beta
    /// (decided 2026-09-24); the *Pretiosa* that DO says after it belongs to Prime and
    /// stays, as the start of "De Officio Capituli" (except in the Office of the Dead).
    func assemblePretiosa(winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?) -> Section? {
        guard !Self.matches(macroContext.winningRule, "ex C9") else { return nil }
        let texts = bothTexts(path: SectionResolver.prayersPath, section: "Pretiosa", resolver: resolver, englishResolver: englishResolver)
        func lines(_ text: String) -> [String] { text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) }
        return Section(kind: .officiumCapituli, units: Self.unitsFromLines(lines(texts.latin), english: texts.english.map(lines)))
    }

    /// `specprima.pl:5-53`, `lectio_brevis_prima`: `Iube, Dómine`, the blessing, the
    /// season's short lesson (under 1960 never the office's own), `Tu autem`.
    func assemblePrimeLectio(
        winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section {
        let special = "Psalterium/Special/Prima Special"
        let name = Self.tempora(
            caller: "Lectio brevis Prima", weekName: macroContext.weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay,
            officeTitle: winner.winningRank.title
        )
        func lines(_ text: String?) -> [String] { text?.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) ?? [] }
        let blessing = bothTexts(path: SectionResolver.prayersPath, section: "benedictio Prima", resolver: resolver, englishResolver: englishResolver)
        let lesson = bothTexts(path: special, section: name, resolver: resolver, englishResolver: englishResolver)
        let tuAutem = bothTexts(path: SectionResolver.prayersPath, section: "Tu autem", resolver: resolver, englishResolver: englishResolver)
        var units = Self.unitsFromLines(lines(blessing.latin), english: blessing.english.map(lines))
        units.append(contentsOf: Self.capitulumUnits(latin: lesson.latin, english: lesson.english))
        units.append(contentsOf: Self.unitsFromLines(lines(tuAutem.latin), english: tuAutem.english.map(lines)))
        return Section(kind: .lectioBrevis, units: units)
    }

    // MARK: - Lauds

    /// A psalm's display title with its number: "Psalmus 96 [1]", or for a canticle
    /// (`psalmTitle`'s "title * source") "Canticum Iudith [4] Iudith 16:15-22", as DO
    /// sets it (`horasscripts.pl:561-580`).
    static func numberedPsalmTitle(_ title: String, _ number: Int?) -> String {
        let parts = title.components(separatedBy: " * ")
        guard parts.count == 2 else { return number.map { "\(title) [\($0)]" } ?? title }
        return number.map { "\(parts[0]) [\($0)] \(parts[1])" } ?? "\(parts[0]) \(parts[1])"
    }

    /// `psalmi.pl:333-659`, `psalmi_major`, at Lauds under 1960: Lauds I or II
    /// (`$laudes`) for the day, the office's own antiphons (its `[Ant Laudes]`, or an
    /// `ex` Commune's), Sunday's psalms on feasts that say so, the week before Christmas's
    /// own antiphons, and Paschaltide's single *Allelúia* antiphon where the office has
    /// none. `antetpsalm` (`:661-707`) then sets each antiphon whole before its psalm
    /// group and without its asterisk after it; within a group only the last psalm has
    /// the Gloria (`:696`, the `-` prefix).
    func assembleLaudsPsalmodia(
        winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section {
        let psalter = "Psalterium/Psalmi/Psalmi major"
        let office = winner.winningPath
        let rule = macroContext.winningRule
        let dayOfWeek = macroContext.dayOfWeek
        let weekName = macroContext.weekName
        // `psalmi.pl:474`'s `$commune{Rule}`: the commune's own rule, `vide` as well as
        // `ex` (DO loads `%commune` for both, `horascommon.pl:1745`; only `$communerule`
        // is `ex`-only). 26 June, "vide C3": Sunday psalms at Lauds.
        let communeRule: String = {
            let reference = winner.winningRank.communeReference
            guard !reference.isEmpty, let path = Self.paschalCommuneFallbackPath(reference, weekName: weekName, resolver: resolver),
                resolver.sectionExists(path: path, section: "Rule")
            else { return "" }
            return resolver.resolve(path: path, section: "Rule")
        }()
        let communeIsEx = winner.winningRank.communeReference.lowercased().hasPrefix("ex")
        func lines(_ path: String, _ section: String, _ resolver: SectionResolver) -> [String] {
            resolver.resolve(path: path, section: section).split(separator: "\n").map(String.init)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        let scheme = laudesScheme(winner: winner, macroContext: macroContext)
        let daySection = "Day\(dayOfWeek) Laudes\(scheme)"

        // Where each antiphon line comes from, so the English follows the Latin.
        var antiphonSource: (path: String, section: String)?
        if macroContext.officeMonth == 12, macroContext.officeDay > 16, macroContext.officeDay < 24, dayOfWeek > 0 {
            antiphonSource = (psalter, "Day\(dayOfWeek) Laudes3")
        }
        var psalmSource = (psalter, daySection)
        if !Self.matches(rule, "Psalmi ex Psalterio") {
            if resolver.sectionExists(path: office, section: "Ant Laudes") {
                antiphonSource = (office, "Ant Laudes")
            } else if communeIsEx, let location = proprium("Ant Laudes", flag: true, winner: winner, resolver: resolver, weekName: weekName) {
                antiphonSource = location
            }
            if let antiphonSource, Self.matches(rule, "Psalmi Dominica") || Self.matches(communeRule, "Psalmi Dominica"),
                !Self.matches(rule, "Psalmi Feria|Psalmi ex Psalterio"),
                let first = lines(antiphonSource.path, antiphonSource.section, resolver).first,
                first.range(of: #";;\s*[0-9]+"#, options: .regularExpression) == nil
            {
                psalmSource = (psalter, "Day0 Laudes1")
            }
        }
        let paschalAlleluia = weekName.range(of: "Pasc", options: .caseInsensitive) != nil
            && (!resolver.sectionExists(path: office, section: "Ant Laudes") || winner.winningRank.communeReference.contains("C10"))
            // Our Lady on Saturday is `vide C10` for `$communetype` (`horascommon.pl:437`);
            // its `ex` rank only feeds `$communerule`. 3 May 2025: one Allelúia antiphon.
            && (!communeIsEx || winner.winningRank.communeReference.contains("C10"))

        func entries(_ resolver: SectionResolver, english: Bool) -> [(antiphon: String, psalms: [String])] {
            let psalmLines = lines(psalmSource.0, psalmSource.1, resolver)
            let antiphonLines = antiphonSource.map { lines($0.path, $0.section, resolver) } ?? []
            var result: [(antiphon: String, psalms: [String])] = []
            for index in 0..<5 {
                let dayLine = index < psalmLines.count ? psalmLines[index] : ""
                let dayParts = dayLine.components(separatedBy: ";;")
                var antiphon = dayParts.first ?? ""
                var psalms = dayParts.count > 1 ? dayParts[1] : ""
                if index < antiphonLines.count {
                    let parts = antiphonLines[index].components(separatedBy: ";;")
                    antiphon = parts[0]
                    if parts.count > 1, parts[1].range(of: #"^[0-9;\s]+$"#, options: .regularExpression) != nil { psalms = parts[1] }
                }
                if paschalAlleluia { antiphon = index == 0 ? alleluiaAntiphon(resolver: resolver) : "" }
                antiphon = antiphon.trimmingCharacters(in: .whitespaces)
                if !antiphon.isEmpty {
                    antiphon = Self.applyingSeasonalAlleluia(to: antiphon, weekName: weekName, isFirstVespers: false, english: english)
                    antiphon = substituteName(in: antiphon, office: office, resolver: resolver, isAntiphon: true)
                }
                result.append((antiphon, psalms.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }))
            }
            return result
        }
        let latin = entries(resolver, english: false)
        let english = englishResolver.map { entries($0, english: true) }

        var units: [Unit] = []
        var number = 0
        var openAntiphon: (latin: String, english: String?)?
        for (index, entry) in latin.enumerated() {
            let englishAntiphon = english.flatMap { index < $0.count ? $0[index].antiphon : nil }.flatMap { $0.isEmpty ? nil : $0 }
            if !entry.antiphon.isEmpty {
                if let open = openAntiphon {
                    units.append(.antiphon(Self.closingAntiphon(open.latin), english: open.english.map(Self.closingAntiphon)))
                }
                units.append(.antiphon(entry.antiphon, english: englishAntiphon))
                openAntiphon = (entry.antiphon, englishAntiphon)
            }
            for (offset, psalm) in entry.psalms.enumerated() {
                number += 1
                let (title, content) = psalmUnits(number: psalm, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)
                var psalmContent = content
                if offset < entry.psalms.count - 1 {
                    // No Gloria inside a group: drop the doxology `psalmUnits` appended.
                    let gloria = gloriaUnits(resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)
                    psalmContent = Array(psalmContent.dropLast(gloria.count))
                }
                if offset == 0, !entry.antiphon.isEmpty {
                    let (tagged, latinMatched, englishMatched) = Self.applyingAntiphonDagger(
                        antiphon: entry.antiphon, englishAntiphon: englishAntiphon, psalmContent: psalmContent
                    )
                    psalmContent = tagged
                    if latinMatched || englishMatched {
                        units[units.count - 1] = .antiphon(
                            latinMatched ? "\(entry.antiphon) ‡" : entry.antiphon,
                            english: englishMatched ? englishAntiphon.map { "\($0) ‡" } : englishAntiphon
                        )
                    }
                }
                units.append(.psalmTitle(Self.numberedPsalmTitle(title, number)))
                units.append(contentsOf: psalmContent)
            }
        }
        if let open = openAntiphon {
            units.append(.antiphon(Self.closingAntiphon(open.latin), english: open.english.map(Self.closingAntiphon)))
        }
        return Section(kind: .psalmodia, units: units)
    }

    /// `capitulis.pl:5-37`, `capitulum_major`; `hymni.pl:67-123`, `hymnusmajor`; and
    /// `getantvers('Versum', 2)` (`specials.pl:575-622`), at Lauds: each the office's own
    /// (or its Commune's), else the psalter's for the season or the day.
    func assembleLaudsCapitulumHymnusVersus(
        winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?, day: Int, month: Int, year: Int
    ) -> [Section] {
        let special = "Psalterium/Special/Major Special"
        let weekName = macroContext.weekName
        let title = winner.winningRank.title
        func season(_ caller: String) -> String {
            Self.tempora(caller: caller, weekName: weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay, officeTitle: title)
        }
        var sections: [Section] = []

        let chapterLocation = proprium("Capitulum Laudes", flag: true, winner: winner, resolver: resolver, weekName: weekName)
            ?? (special, "\(season("Capitulum major")) Laudes")
        if resolver.sectionExists(path: chapterLocation.path, section: chapterLocation.section) {
            let texts = bothTexts(path: chapterLocation.path, section: chapterLocation.section, resolver: resolver, englishResolver: englishResolver)
            let thanks = bothTexts(path: SectionResolver.prayersPath, section: "Deo gratias", resolver: resolver, englishResolver: englishResolver)
            sections.append(Section(kind: .capitulum, units: Self.capitulumUnits(latin: texts.latin, english: texts.english, thanks: thanks)))
        }

        var hymnLocation = proprium("Hymnus Laudes", flag: true, winner: winner, resolver: resolver, weekName: weekName)
        if hymnLocation == nil {
            var name = "Hymnus \(season("Hymnus major")) Laudes"
            let suffix = Self.monthdayTitleSuffix(office: winner.winningPath, day: day, month: month, year: year, tomorrow: false)
            if name.contains("Day0"), Self.matches(weekName, "Epi[2-6]|Quadp") || Self.matches(suffix, "Novembris|Octobris") {
                name += " hiemalis"
            }
            hymnLocation = (special, name)
        }
        if let hymnLocation, resolver.sectionExists(path: hymnLocation.path, section: hymnLocation.section) {
            let texts = bothTexts(path: hymnLocation.path, section: hymnLocation.section, resolver: resolver, englishResolver: englishResolver)
            func stanzas(_ text: String) -> [String] { Self.hymnStanzas(text.replacingOccurrences(of: #"\*\s*"#, with: "", options: .regularExpression)) }
            let latin = stanzas(texts.latin)
            let english = texts.english.map(stanzas)
            sections.append(Section(kind: .hymnus, units: Self.pairedStanzas(latin: latin, english: english)))
        }

        var versumLocation = proprium("Versum 2", flag: true, winner: winner, resolver: resolver, weekName: weekName)
        if versumLocation == nil {
            let prefix = season("getfrompsalterium major")
            versumLocation = ["2", "1", "3"].lazy.map { (special, "\(prefix) Versum \($0)") }
                .first { resolver.sectionExists(path: $0.0, section: $0.1) }
        }
        if let versumLocation {
            let texts = bothTexts(path: versumLocation.path, section: versumLocation.section, resolver: resolver, englishResolver: englishResolver)
            func lines(_ text: String, english: Bool) -> [String] {
                text.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { Self.applyingSeasonalAlleluia(to: String($0), weekName: weekName, isFirstVespers: false, english: english) }
            }
            sections.append(Section(kind: .versus, units: Self.unitsFromLines(lines(texts.latin, english: false), english: texts.english.map { lines($0, english: true) })))
        }
        return sections
    }

    /// `horas.pl:508-568`, `canticum`, at Lauds: the Benedictus (canticle 231) with
    /// `getantvers('Ant', 2)`, the office's `[Ant 2]` (or its Commune's), else the
    /// psalter's; the week before Christmas has its own on the 21st and 23rd.
    func assembleBenedictus(
        winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section {
        let special = "Psalterium/Special/Major Special"
        let weekName = macroContext.weekName
        var location: (path: String, section: String)?
        if macroContext.officeMonth == 12, [21, 23].contains(macroContext.officeDay), winner.winningPath.hasPrefix("Tempora") {
            location = (special, "Adv Ant \(macroContext.officeDay)L")
        }
        if location == nil {
            location = proprium("Ant 2", flag: true, winner: winner, resolver: resolver, weekName: weekName)
        }
        if location == nil {
            let prefix = Self.tempora(
                caller: "getfrompsalterium major", weekName: weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay,
                officeTitle: winner.winningRank.title
            )
            location = ["2", "1", "3"].lazy.map { (special, "\(prefix) Ant \($0)") }.first { resolver.sectionExists(path: $0.0, section: $0.1) }
        }
        var units: [Unit] = []
        var antiphons: (latin: String, english: String?)?
        if let location, resolver.sectionExists(path: location.path, section: location.section) {
            let texts = bothTexts(path: location.path, section: location.section, resolver: resolver, englishResolver: englishResolver)
            func first(_ text: String, english: Bool) -> String {
                let line = text.split(separator: "\n").first.map { String($0).components(separatedBy: ";;").first ?? String($0) } ?? ""
                let alleluia = Self.applyingSeasonalAlleluia(to: line, weekName: weekName, isFirstVespers: false, english: english)
                return substituteName(in: alleluia, office: winner.winningPath, resolver: english ? (englishResolver ?? resolver) : resolver, isAntiphon: true)
            }
            antiphons = (first(texts.latin, english: false), texts.english.map { first($0, english: true) })
        }
        if let antiphons { units.append(.antiphon(antiphons.latin, english: antiphons.english)) }
        let path = "Psalterium/Psalmorum/Psalm231"
        let latinVerses = Psalm.parseVerses(resolver.resolvePsalmText(path: path, section: RawSectionParser.wholeFileSectionName)
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        let englishVerses: [PsalmVerse]? = englishResolver.flatMap { eng in
            guard eng.sectionExists(path: path, section: RawSectionParser.wholeFileSectionName) else { return nil }
            return Psalm.parseVerses(eng.resolvePsalmText(path: path, section: RawSectionParser.wholeFileSectionName)
                .split(separator: "\n", omittingEmptySubsequences: false).map(String.init))
        }
        units.append(contentsOf: Self.pairedVerses(latin: latinVerses, english: englishVerses))
        units.append(contentsOf: gloriaUnits(resolver: resolver, macroContext: macroContext, englishResolver: englishResolver))
        if let antiphons {
            units.append(.antiphon(Self.closingAntiphon(antiphons.latin), english: antiphons.english.map(Self.closingAntiphon)))
        }
        return Section(kind: .canticum, units: units)
    }
}

extension HourAssembler {
    /// A hymn's stanzas, Latin with English. When the translation has more stanzas (the
    /// Pentecost Lauds hymn: 7 Latin, 8 English, the English doxology in two), the extra
    /// ones go with the last Latin stanza, so none of the English is lost; DO shows the
    /// whole hymn in one row.
    static func pairedStanzas(latin: [String], english: [String]?) -> [Unit] {
        // `webdia.pl:694`: the editor's grave accents go ("`gainst").
        let english = english?.map { $0.replacingOccurrences(of: "`", with: "") }
        guard let english, !english.isEmpty, !latin.isEmpty else { return latin.map { .prose($0, english: nil) } }
        guard english.count != latin.count else { return zip(latin, english).map { .prose($0, english: $1) } }
        guard english.count > latin.count else { return latin.map { .prose($0, english: nil) } }
        return latin.enumerated().map { index, stanza in
            let text = index == latin.count - 1 ? english[index...].joined(separator: "\n\n") : english[index]
            return .prose(stanza, english: text)
        }
    }
}
