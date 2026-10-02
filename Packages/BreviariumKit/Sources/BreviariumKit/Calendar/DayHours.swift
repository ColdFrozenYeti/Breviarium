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
    static func tempora(
        caller: String, weekName: String, dayOfWeek: Int, day: Int, officeTitle: String, rite: Rite = .romanus, hour: CanonicalHour? = nil
    ) -> String {
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
        // The Dominican office's is the Sunday's, save Saturday Vespers' (`:2312`).
        if caller == "Hymnus major", name.isEmpty {
            name = rite != .dominicanus || (hour == .vesperae && dayOfWeek == 6) ? "Day\(dayOfWeek)" : "Day0"
        }
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
        // `:2334-2340`: the Dominican Compline antiphon's key takes a leading space, and
        // Lent's third and fourth weeks have their own (`Ant 4 Quad3`).
        if caller == "MM Capitulum" || caller == "Nunc dimittis", !name.isEmpty {
            name = " " + name
            if caller == "Nunc dimittis", weekName.range(of: "^Quad[34]", options: .regularExpression) != nil { name += "3" }
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
        for hop in 0..<5 {
            // A later hop to another saint's office (`ex Sancti/12-25`) reads the file as named,
            // with no rite's folder (`specials.pl:502`): 2 January's Dominican Terce takes the
            // Roman Christmas versicle, *Ipse invocábit me*.
            let romanHop = hop > 0 && current.range(of: #"^(ex|vide)\s*Sancti/"#, options: [.regularExpression, .caseInsensitive]) != nil
            guard let path = romanHop ? Self.communeFallbackPath(current)
                : Self.paschalCommuneFallbackPath(current, weekName: weekName, resolver: resolver)
            else { return nil }
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
            } else if Self.matches(rule, Self.psalmiDominica) || Self.matches(communeRule, Self.psalmiDominica),
                rank >= 6 || resolver.context.rite == .dominicanus    // `psalmi.pl:131`: by the version name `1960`.
            {
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
                // `:170`: the Dominican Advent antiphons, `[AdvOP]` (1 December 2026, *Veni et
                // líbera nos*).
                if resolver.context.rite == .dominicanus {
                    name = name.replacingOccurrences(of: #"\d+$"#, with: "OP", options: .regularExpression)
                }
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
            // `:225-228` limits these to I class feasts by the version name `1955|1960`, so not
            // in the Dominican office ("1962"; 10 August 2026, *Lauréntius ingréssus est*).
            let limited = resolver.context.rite != .dominicanus && rank < 6 && dayOfWeek > 0
            if proper == nil, !Self.matches(rule, Self.psalmiExPsalterio), !limited {
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
            text = Self.applyingSeasonalAlleluia(to: text, weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers, english: english, season: macroContext.seasonWeekName)
            return substituteName(in: text, office: office, resolver: resolver, isAntiphon: true)
        }
        // `psalmi.pl:275-281`: "Minores sine Antiphona" (Easter week).
        let withoutAntiphon = Self.matches(rule, "Minores sine Antiphona")
        let latinAntiphon = withoutAntiphon ? "" : antiphon(resolver, english: false) ?? ""
        let englishAntiphon = withoutAntiphon ? nil : englishResolver.flatMap { antiphon($0, english: true) }

        var psalms = psalmsLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if hour == .prima {
            // `:276-282`: 1960 drops Prime's bracketed psalm. The test is by version name, so
            // the Dominican office ("1962") says it with Lauds II (16 February 2026, Ps 46).
            if resolver.context.rite == .dominicanus, laudesScheme(winner: winner, macroContext: macroContext) == 2 {
                psalms = psalms.map { $0.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "") }
            } else {
                psalms = psalms.filter { !$0.hasPrefix("[") }
            }
            // `:122`: psalm 117 gives way to 53 with Lauds II, or by rule.
            if Self.matches(rule, "Prima=53") || laudesScheme(winner: winner, macroContext: macroContext) == 2 {
                psalms = psalms.map { $0 == "117" ? "53" : $0 }
            }
            // `:252-266`, `:301-305`: on feasts with Sunday psalms (I class under 1960) the
            // first psalm is 53.
            var feast = (Self.matches(rule, Self.psalmiDominica) || Self.matches(communeRule, Self.psalmiDominica))
                && !Self.matches(rule, Self.psalmiExPsalterio) && !(rank < 6 && dayOfWeek > 0)
            if rank < 6, resolver.context.rite != .dominicanus { feast = false }    // `/1955|1960/`, as above.
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
        // `specials.pl:550`: under 1960 only on I class feasts, by the version name, so not in
        // the Dominican office ("1962").
        guard Self.matches(rule, "Antiphonas horas") || Self.matches(communeRule, "Antiphonas horas"),
            rank >= 6 || resolver.context.rite == .dominicanus
        else { return nil }
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
        // `hymni.pl:27-36`: the Dominican Compline hymn is the season's in Lent,
        // Passiontide and Paschaltide, and `[Versum 4]` follows the hymn.
        let dominicanCompline = hour == .completorium && resolver.context.rite == .dominicanus
        if dominicanCompline {
            let season = Self.tempora(
                caller: "*", weekName: macroContext.weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay,
                officeTitle: winner.winningRank.title, rite: .dominicanus, hour: hour
            )
            if ["Quad", "Quad5", "Pasch", "Asc", "Pent"].contains(season) { name += " \(season)" }
        }
        guard resolver.sectionExists(path: path, section: name) else { return [] }
        let texts = bothTexts(path: path, section: name, resolver: resolver, englishResolver: englishResolver)
        func stanzas(_ text: String) -> [String] {
            Self.hymnStanzas(text.replacingOccurrences(of: #"\*\s*"#, with: "", options: .regularExpression))
        }
        let latin = stanzas(texts.latin)
        let english = texts.english.map(stanzas)
        var units = Self.pairedStanzas(latin: latin, english: english)
        if dominicanCompline {
            // `postprocess_vr`: in Paschaltide each line ends in *allelúia*.
            let versum = rawBoth(path: path, section: "Versum 4", resolver: resolver, englishResolver: englishResolver)
            let paschal = macroContext.weekName.range(of: "Pasc", options: .caseInsensitive) != nil
            func lines(_ text: String?, alleluia: String) -> [String]? {
                text?.split(separator: "\n").map { line in
                    paschal ? Self.ensuringSingleAlleluia(String(line), alleluia: alleluia) : String(line)
                }
            }
            units += Self.unitsFromLines(
                lines(versum.latin, alleluia: "Allelúia") ?? [], english: lines(versum.english, alleluia: "Alleluia")
            )
        }
        return [Section(kind: .hymnus, units: units)]
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
            // `capitulis.pl:167-190`. In the Dominican office the versicle follows the hymn
            // instead, and in Lent the key is "CompletoriumOP", which the file doesn't have
            // (its section is "Completorium OP Quad"): DO shows no responsory then
            // (`docs/rubrics-op1962.md` §8).
            let dominican = resolver.context.rite == .dominicanus
            var name = "Completorium"
            if dominican, weekName.range(of: "^Quad\\d", options: .regularExpression) != nil { name += "OP" }
            if resolver.sectionExists(path: special, section: "Responsory \(name)") {
                append((special, "Responsory \(name)"), separator: false)
            } else if resolver.sectionExists(path: special, section: "Versum \(name)") {
                append((special, "Responsory breve \(name)"), separator: false)
                append((special, "Versum \(name)"), separator: true)
            }
            if !dominican { append((special, "Versum 4"), separator: true) }
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
            } else {
                // `capitulis.pl:171-174`: in Lent the Dominican responsories are `…OP`
                // sections, the third and fourth weeks sharing `Quad3` (22 February 2026).
                var name = seasonName
                if resolver.context.rite == .dominicanus, weekName.range(of: "^Quad\\d", options: .regularExpression) != nil {
                    name += "OP"
                    if weekName.range(of: "^Quad[34]", options: .regularExpression) != nil {
                        name = name.replacingOccurrences(of: "Quad", with: "Quad3", options: .anchored)
                    }
                }
                if resolver.sectionExists(path: special, section: "Responsory \(name)") {
                    append((special, "Responsory \(name)"), separator: false)
                } else {
                    append((special, "Responsory breve \(name)"), separator: false)
                    append((special, "Versum \(name)"), separator: true)
                }
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
        // `$dayname[0]`, the season's even in a votive office.
        let seasonWeekName = macroContext.seasonWeekName.isEmpty ? weekName : macroContext.seasonWeekName
        let gloria1Omitted = seasonWeekName.range(of: "Quad[56]", options: .regularExpression) != nil
            && !winner.winningPath.contains("Sancti") && !Self.matches(macroContext.winningRule, "Gloria responsory")
        var lines: [String] = []
        // DO still has `&Gloria1` as a line when it adds the alleluias (`horas.pl:697-725`), so
        // the Gloria's versicle doesn't start a "V. … R." pair there: the response after it
        // is the first response with its alleluias, not "Allelúia, allelúia" (12 April 2026).
        var gloriaLines = Set<Int>()
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line == "&Gloria" || line == "&Gloria1" {
                // DO shows the omission (`horas.pl:303-311`), as for the psalms' Gloria.
                guard !gloria1Omitted else { lines.append(english ? "!omit Glory be" : "!Gloria omittitur"); continue }
                let gloria = resolver.resolve(path: SectionResolver.prayersPath, section: "Gloria1").split(separator: "\n").map(String.init)
                gloriaLines.formUnion(lines.count..<(lines.count + gloria.count))
                lines.append(contentsOf: gloria)
            } else if line.hasPrefix("&"), let macroContext = resolver.macroContext ?? Optional(macroContext),
                let resolved = ScriptMacros.resolve(String(line.dropFirst()), context: macroContext, resolver: resolver, isEnglish: english)
            {
                lines.append(contentsOf: resolved.split(separator: "\n").map(String.init))
            } else {
                lines.append(rawLine)
            }
        }
        let paschal = weekName.range(of: "Pasc", options: .caseInsensitive) != nil
        guard paschal || Self.matches(macroContext.winningRule, "Responsory Breve cum Allelu[ij]a") && macroContext.hour.isLittleHour
        else { return lines.map { Self.processingInlineAlleluias($0, paschal: paschal) } }
        let alleluiaDuplex = resolver.resolve(path: SectionResolver.prayersPath, section: "Alleluia Duplex")
            .split(separator: "\n").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        let alleluia = alleluiaDuplex.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "Allelúia"
        let cumAlleluia = Self.matches(macroContext.winningRule, "Responsory Breve cum Allelu[ij]a")
        var inResponsory = false
        var rLines = 0
        var sawVersicle = false
        for index in lines.indices {
            let line = lines[index]
            if line.hasPrefix("R.br.") { inResponsory = true; rLines = 0; sawVersicle = false }
            if inResponsory {
                if line.hasPrefix("V."), !gloriaLines.contains(index) { sawVersicle = true }
                if line.hasPrefix("R."), !line.hasPrefix("R.br.") { rLines += 1 }
                if sawVersicle, line.hasPrefix("R."), !line.hasPrefix("R.br.") {
                    lines[index] = "R. \(alleluiaDuplex)"
                    sawVersicle = false
                } else if line.hasPrefix("R.") {
                    lines[index] = Self.ensuringDoubleAlleluia(line, alleluia: alleluia)
                }
                if line.hasPrefix("R."), !line.hasPrefix("R.br."), rLines >= 3 { inResponsory = false }
            } else if (line.hasPrefix("V.") || line.hasPrefix("R.")), !cumAlleluia, !gloriaLines.contains(index) {
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
        // `horas.pl:533-540`: the Dominican antiphon is the season's.
        let dominican = resolver.context.rite == .dominicanus
        let dominicanSeason = dominican ? Self.tempora(
            caller: "Nunc dimittis", weekName: macroContext.weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay,
            officeTitle: winner.winningRank.title, rite: .dominicanus, hour: .completorium
        ) : ""
        let location = proprium("Ant 4\(vespera)", flag: false, winner: winner, resolver: resolver, weekName: macroContext.weekName)
            ?? ("Psalterium/Special/Minor Special", "Ant 4\(dominicanSeason)")
        let texts = bothTexts(path: location.path, section: location.section, resolver: resolver, englishResolver: englishResolver)
        func antiphons(_ text: String, english: Bool) -> (open: String, close: String) {
            // A second line is the closing antiphon as it stands (`$s[-1] = "Ant. $ant2"`,
            // `horas.pl:568`): Easter week's *Hæc dies*.
            let lines = text.split(separator: "\n").map { String($0).components(separatedBy: ";;").first ?? String($0) }
            let open = lines.first.map {
                Self.applyingSeasonalAlleluia(to: $0, weekName: macroContext.weekName, isFirstVespers: macroContext.isFirstVespers, english: english, season: macroContext.seasonWeekName)
            } ?? ""
            // `:536-539`: *Média vita* closes as it opened, asterisk and all, since DO sets
            // it as `$ant2` (its verse follows, below).
            if dominicanSeason == " Quad3" { return (open, open) }
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
        if dominicanSeason == " Quad3" {
            // Its `V.` line, after the closing antiphon (`$ant2 = "$ant\n$ant2"`).
            func verse(_ text: String?) -> [String]? { text.map { Array($0.split(separator: "\n").map(String.init).dropFirst()) } }
            units += Self.unitsFromLines(verse(texts.latin) ?? [], english: verse(texts.english))
        }
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
        if resolver.context.rite == .dominicanus {
            // `specials.pl:316-319`: always the Salve Regina, which `Prayers.txt` gives
            // in its Dominican form (`Mariaant:Ant Finalis OP`, with *O Lumen*).
            name = "ant Salve Regina"
        } else if weekName.range(of: "Adv|Nat", options: [.regularExpression, .caseInsensitive]) != nil || month == 1 || (month == 2 && day < 2)
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
        // `webdia.pl:681`, `process_inline_alleluias`, over all DO shows: the Dominican
        // form's "(Allelúja.)" stands in Paschaltide and goes otherwise; and the `_`
        // its line joins leave is layout, not text.
        let paschal = weekName.range(of: "Pasc", options: .caseInsensitive) != nil
        func lines(_ text: String?) -> [String] {
            text?.split(separator: "\n", omittingEmptySubsequences: false).map {
                Self.processingInlineAlleluias(String($0), paschal: paschal)
                    .replacingOccurrences(of: #"\s+_(?=\s|$)"#, with: "", options: .regularExpression)
            } ?? []
        }
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
                kind = Self.specialHourKind(heading) ?? kind
            } else if let psalm = chunk.psalm {
                psalmNumber += 1
                let (title, content) = psalmUnits(number: psalm, resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)
                let base = psalm.prefix { $0.isNumber }
                units.append(.psalmTitle(Self.numberedPsalmTitle(title, Int(base).map { $0 > 150 } == true ? nil : psalmNumber)))
                units.append(contentsOf: content)
            } else {
                // `process_inline_alleluias` runs over everything DO shows (the Little
                // Office's Annunciation antiphon, "… Ioseph. (Allelúia.)").
                let season = macroContext.seasonWeekName.isEmpty ? macroContext.weekName : macroContext.seasonWeekName
                let paschal = season.range(of: "Pasc", options: .caseInsensitive) != nil
                // And `suppress_alleluia` from Septuagesima (`webdia.pl:684-685`).
                let suppressed = Self.isAlleluiaSuppressed(weekName: season, isFirstVespers: macroContext.isFirstVespers)
                func processed(_ line: String) -> String {
                    let line = Self.processingInlineAlleluias(line, paschal: paschal)
                    guard suppressed, !line.hasPrefix("&"), !line.hasPrefix("$") else { return line }
                    return line.replacingOccurrences(of: #"[,.]?\s*allel[uú][ij]a"#, with: "", options: [.regularExpression, .caseInsensitive])
                }
                let englishLines = pairEnglish ? english?[index].lines.map(processed) : nil
                if kind == .hymnus {
                    // A hymn in stanzas, as the psalter's hymns are (the Little Office's
                    // *Meménto, rerum Cónditor*): each stanza's `v.`/`r.` opening goes.
                    func stanzas(_ lines: [String]) -> [String] {
                        Self.hymnStanzas(
                            lines.map { $0.replacingOccurrences(of: #"^\s*[vr]\.\s+"#, with: "", options: .regularExpression) }
                                .joined(separator: "\n").replacingOccurrences(of: #"\*\s*"#, with: "", options: .regularExpression)
                        ).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    }
                    units.append(contentsOf: Self.pairedStanzas(latin: stanzas(chunk.lines.map(processed)), english: englishLines.map(stanzas)))
                } else {
                    units.append(contentsOf: Self.unitsFromLines(chunk.lines.map(processed), english: englishLines))
                }
            }
        }
        if !units.isEmpty { sections.append(Section(kind: kind, units: units)) }
        return Hour(sections: sections)
    }

    /// The section a `#Heading` of a special hour opens, by its first word.
    static func specialHourKind(_ heading: String) -> Section.Kind? {
        let word = heading.lowercased()
        let kinds: [(String, Section.Kind)] = [
            ("incipit", .introductio), ("hymnus", .hymnus), ("psalmi", .psalmodia), ("capitulum", .capitulum),
            ("lectio brevis", .lectioBrevis), ("versus", .versus), ("canticum", .canticum), ("oratio", .oratio),
            ("conclusio", .conclusio), ("antiphona finalis", .antiphonaFinalis),
        ]
        return kinds.first { word.hasPrefix($0.0) }?.1
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
                // Not at Compline, whose versicle comes later, except in the Dominican
                // Easter week (`specials.pl:73`; Easter Sunday 2026, *Hæc dies*).
                let dominicanEaster = resolver.context.rite == .dominicanus && winner.winningPath.contains("Pasc0")
                if hour != .completorium || dominicanEaster, let location = resolvedLocation(
                    office: winner.winningPath, communeReference: winner.winningRank.communeReference, section: "Versum 2",
                    resolver: resolver, weekName: macroContext.weekName
                ) {
                    let texts = bothTexts(path: location.path, section: location.section, resolver: resolver, englishResolver: englishResolver)
                    let firstLine = texts.latin.split(separator: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    // The Dominican Easter week's is "Allelúia." then "V. Hæc dies…" (11 April 2026).
                    let hasVersicle = texts.latin.split(separator: "\n").contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("V.") }
                    if firstLine?.hasPrefix("V.") == true || hasVersicle {
                        func lines(_ text: String) -> [String] {
                            text.split(separator: "\n", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
                        }
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
        let rite = context.rite
        let ember = isEmberDay(
            weekName: weekName, dayOfWeek: macroContext.dayOfWeek, month: macroContext.officeMonth, winningRankTitle: winner.winningRank.title
        )
        let penitential = (weekName.hasPrefix("Adv") && macroContext.dayOfWeek != 0) || weekName.contains("Quad") || (ember && !weekName.hasPrefix("Pasc"))
        let temporal = winner.winningPath.hasPrefix("Tempora") && !Self.matches(winner.winningRank.title, "(Beatæ|Sanctæ) Mariæ")
        // `horascommon.pl:1873`: vigils too, except under 1955 and 1960 by the version name, so
        // in the Dominican office ("1962"; the Vigil of Pentecost, 23 May 2026).
        let vigil = winner.winningRank.title + ";;" + winner.winningRank.degreeLabel
        let dominicanVigil = rite == .dominicanus && vigil.range(of: "vigil", options: .caseInsensitive) != nil
            && !Self.matches(macroContext.winningRule, "Psalmi Dominica")
        return (penitential && temporal) || Self.matches(macroContext.winningRule, "Laudes 2") || dominicanVigil ? 2 : 1
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
        let chapter = bothTexts(
            path: special, section: Self.primeChapterKey(winner: winner, macroContext: macroContext, rite: resolver.context.rite),
            resolver: resolver, englishResolver: englishResolver
        )
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

    /// `specprima.pl:64-72`: the chapter of Prime is `[Dominica]`'s, except on ferias and
    /// vigils of a low rank outside Paschaltide, which take `[Feria]` (*Pacem et
    /// veritátem*). The test excludes the 1960 rubrics by version name, so it applies only
    /// to the Dominican office, whose version is "1962".
    static func primeChapterKey(winner: OccurrenceResult, macroContext: MacroContext, rite: Rite) -> String {
        let rank = winner.winningRank
        let rankLine = rank.title + ";;" + rank.degreeLabel
        guard rite == .dominicanus, macroContext.dayOfWeek > 0,
            rankLine.range(of: "Feria|Vigilia", options: [.regularExpression, .caseInsensitive]) != nil,
            rankLine.range(of: "Vigilia Epi", options: .caseInsensitive) == nil,
            !rank.communeReference.contains("C10"), !winner.winningPath.contains("C10"),
            Self.loadedRank(rank, day: macroContext.officeDay) < 3 || macroContext.weekName.contains("Quad6")
                || winner.winningPath.contains("Quadp3-3"),
            macroContext.weekName.range(of: "Pasc", options: .caseInsensitive) == nil
        else { return "Dominica" }
        return "Feria"
    }

    /// The rank as DO loads it (`SetupString.pl:740-741`, `officestring`): the Advent ferias
    /// of the third and fourth weeks from 17 December are 4.9, not 2.1 (17 December 2026).
    static func loadedRank(_ rank: OfficeRank, day: Int) -> Double {
        guard day > 16, rank.numericPrecedence == 2.1,
            (rank.title + ";;" + rank.degreeLabel).range(of: "Feria.*?(III|IV) Adv", options: [.regularExpression, .caseInsensitive]) != nil
        else { return rank.numericPrecedence }
        return 4.9
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

    // MARK: - Dominican Prime

    /// `monastic.pl:618-638`, `regula_vel_evangelium`: the Dominican Prime's reading, in
    /// place of the short lesson. *Iube, domne*, then on feasts the Gospel of the day
    /// (`lectioE`) after the *Divinum auxilium* blessing, or on ferias, vigils and octave
    /// days the day's passage from the Rule of St Augustine after its own blessing; then
    /// *Tu autem* and the Rule's *Finita lectione* (the commemoration of the Order's dead,
    /// Psalm 116 and the collect *Actiónes nostras*).
    func assembleRegulaVelEvangelium(
        winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> Section {
        let regula = "Regula/OrdoPraedicatorum"
        func lines(_ text: String) -> [String] { text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) }
        func part(_ latin: [String], _ english: [String]?) -> [Unit] { Self.unitsFromLines(latin, english: english) }
        func macro(_ name: String, _ resolver: SectionResolver) -> [String] { lines(resolver.expandMacroLine("$" + name)) }

        var units = part(macro("Jube domne", resolver), englishResolver.map { macro("Jube domne", $0) })
        if Self.lectioERequired(winner: winner) {
            func blessing(_ resolver: SectionResolver) -> [String] {
                let first = lines(resolver.resolve(path: SectionResolver.prayersPath, section: "Divinum auxilium"))
                    .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
                return [first] + macro("Amen", resolver)
            }
            units += part(blessing(resolver), englishResolver.map(blessing))
            let latin = primeGospel(winner: winner, resolver: resolver, macroContext: macroContext)
            let english = englishResolver.map { primeGospel(winner: winner, resolver: $0, macroContext: macroContext) }
            // The heading and its reference, then the text, each paired on its own.
            units += part(Array(latin.prefix(2)), english.map { Array($0.prefix(2)) })
            units += part(Array(latin.dropFirst(2)), english.map { Array($0.dropFirst(2)) })
        } else {
            func rule(_ resolver: SectionResolver) -> [String] {
                lines(resolver.resolve(path: regula, section: "Benedictio")) + macro("Amen", resolver)
            }
            units += part(rule(resolver), englishResolver.map(rule))
            let day = String(macroContext.dayOfWeek)
            func reading(_ resolver: SectionResolver) -> [String] {
                resolver.sectionExists(path: regula, section: day)
                    ? ["v. " + resolver.resolve(path: regula, section: day).trimmingCharacters(in: .whitespacesAndNewlines)] : []
            }
            units += part(reading(resolver), englishResolver.map(reading))
        }
        units += part(macro("Tu autem", resolver), englishResolver.map { macro("Tu autem", $0) })

        // `&psalm(116)` is set as a psalm, between the lines before and after it.
        func finita(_ resolver: SectionResolver) -> (before: [String], after: [String]) {
            let all = lines(resolver.resolve(path: regula, section: "Finita lectione"))
            guard let index = all.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("&psalm(") }) else { return (all, []) }
            return (Array(all[..<index]), Array(all[(index + 1)...]))
        }
        let latinFinita = finita(resolver)
        let englishFinita = englishResolver.map(finita)
        units += part(latinFinita.before, englishFinita?.before)
        let (title, psalm) = psalmUnits(number: "116", resolver: resolver, macroContext: macroContext, englishResolver: englishResolver)
        units.append(.psalmTitle(title, english: nil))
        units += psalm
        units += part(latinFinita.after, englishFinita?.after)
        return Section(kind: .regulaVelEvangelium, units: units)
    }

    /// `monastic.pl:612-615`, `lectioE_required`: the Gospel is read unless the day is a
    /// feria, a day within an octave or a vigil, except on Ash Wednesday, Holy Thursday,
    /// Christmas Eve and All Souls.
    static func lectioERequired(winner: OccurrenceResult) -> Bool {
        // `$dayname[1]` is the title and the rank's name (`horascommon.pl:675`): "Sabbato post
        // Cineres Feria major".
        (winner.winningRank.title + " " + winner.winningRank.degreeLabel)
            .range(of: "Feria|octavam|vigil|in albis", options: [.regularExpression, .caseInsensitive]) == nil
            || winner.winningPath.range(of: "Quadp3-3|Quad6-4|12-24|11-02", options: .regularExpression) != nil
    }

    /// `monastic.pl:534-610`, `lectioE`, for the Dominican rite: the Gospel of the day from
    /// the office's `[Evangelium]`, else its Mass (`missa/`), else its Commune; the
    /// heading reduced to its last two words (*secúndum Matthǽum*), the reference, and
    /// the text cut at the `¶` mark. Returned as DO's lines: heading, `!reference`, text.
    func primeGospel(winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext) -> [String] {
        var evangelium = "Evangelium"
        if let match = macroContext.winningRule.firstMatch(of: /(?i)in 3 Nocturno Lectiones ex Commune in (\d+) loco/),
            let place = Int(match.1), place > 1
        {
            evangelium += " in \(place) loco"
        }
        // The Mass's file, read as DO's `%missa` (`SectionResolver.missaLocation`). Its tree has
        // no `M` or `OP` folders (`$win =~ s/(?:M|OP|Cist)//g`).
        var missa = resolver
        missa.missaContext = true
        func missaFile(_ path: String) -> String {
            missa.missaLocation(path.replacingOccurrences(of: #"M|OP|Cist"#, with: "", options: .regularExpression))
        }
        func body(_ resolver: SectionResolver, _ path: String, _ section: String) -> [String]? {
            guard resolver.sectionExists(path: path, section: section) else { return nil }
            return resolver.resolve(path: path, section: section).split(separator: "\n").map(String.init)
        }

        let office = winner.winningPath
        let commune = winner.winningRank.communeReference.isEmpty ? nil
            : Self.paschalCommuneFallbackPath(winner.winningRank.communeReference, weekName: macroContext.weekName, resolver: resolver)
        var source: (resolver: SectionResolver, path: String, section: String)?
        if resolver.sectionExists(path: office, section: "Evangelium") {
            source = (resolver, office, "Evangelium")
        } else if missa.sectionExists(path: missaFile(office), section: "Evangelium") {
            source = (missa, missaFile(office), "Evangelium")
        } else if let commune, resolver.sectionExists(path: commune, section: evangelium) {
            source = (resolver, commune, evangelium)
        } else if let commune, resolver.sectionExists(path: commune, section: "Evangelium") {
            source = (resolver, commune, "Evangelium")
        }
        var gospel: [String] = []
        // An office's `[Evangelium]` that is only a reference to another office (the
        // Dominican Sundays after Easter, `@Tempora/Pasc2-0`) isn't resolved when DO loads
        // the file; `lectioE` reads that office's own section, else its Mass.
        if let source, !source.resolver.missaContext,
            let first = source.resolver.unresolvedBody(path: source.path, section: source.section)?
                .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
            first.hasPrefix("@"), !first.contains("Commune")
        {
            let parts = first.dropFirst().split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            let path = parts[0].isEmpty ? office : parts[0]
            let section = parts.count > 1 && !parts[1].isEmpty ? parts[1].components(separatedBy: ":")[0] : "Evangelium"
            gospel = body(resolver, path, section) ?? body(missa, missaFile(path), section) ?? []
        } else if let source {
            gospel = body(source.resolver, source.path, source.section) ?? []
        }
        gospel = gospel.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if gospel.isEmpty {
            gospel = body(resolver, office, "Evangelium") ?? body(missa, missaFile(office), "Evangelium")
                ?? ["Sequéntia ++ sancti Evangélii secúndum /:...:/", "!...", "In illo témpore: /:...:/"]
        }
        guard gospel.count >= 2 else { return gospel }

        // `$begin =~ s/.*\s+(\p{Letter}+.?)\s+(\p{Letter}+)\.?\s*$/\1 \2/m`: the heading's last
        // two words.
        var heading = gospel[0]
        if let match = heading.firstMatch(of: /^.*\s+(\p{L}+.?)\s+(\p{L}+)\.?\s*$/) {
            heading = "\(match.1) \(match.2)"
        }
        // DO's page drops the `_` block marks inside the joined text (Palm Sunday's Passion).
        var text = gospel.dropFirst(2).filter { !$0.hasPrefix("!") && $0.trimmingCharacters(in: .whitespaces) != "_" }
        guard !text.isEmpty else { return ["v. " + heading, gospel[1]] }
        var first = text[text.startIndex]
        if !first.hasPrefix("v. ") { first = "v. " + first }
        if let cut = first.range(of: #"\s*¶"#, options: .regularExpression) { first = String(first[..<cut.lowerBound]) }
        text[text.startIndex] = first
        return ["v. " + heading, gospel[1], text.joined(separator: " ")]
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
            // `psalmi.pl:555-558`: a single Dominican antiphon covers all the psalms (Easter week,
            // "…;;92;99;62;210;148").
            let underOneAntiphon = resolver.context.rite == .dominicanus && antiphonLines.count == 1
            for index in 0..<(underOneAntiphon ? 1 : 5) {
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
                    antiphon = Self.applyingSeasonalAlleluia(to: antiphon, weekName: weekName, isFirstVespers: false, english: english, season: macroContext.seasonWeekName)
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
            Self.tempora(
                caller: caller, weekName: weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay, officeTitle: title,
                rite: resolver.context.rite, hour: .laudes
            )
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
            // Never in the Dominican office (`hymni.pl:110`): its Sundays keep *Ecce iam noctis*.
            if name.contains("Day0"), resolver.context.rite != .dominicanus,
                Self.matches(weekName, "Epi[2-6]|Quadp") || Self.matches(suffix, "Novembris|Octobris")
            {
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
                    .map { Self.applyingSeasonalAlleluia(to: String($0), weekName: weekName, isFirstVespers: false, english: english, season: macroContext.seasonWeekName) }
            }
            sections.append(Section(kind: .versus, units: Self.unitsFromLines(lines(texts.latin, english: false), english: texts.english.map { lines($0, english: true) })))
        }
        return sections
    }

    /// `getantvers('Versum', 0)` for the Dominican versicle before Lauds: the office's
    /// `[Versum 0]` (or its Commune's), else the psalter's `[… Versum 0]` for the season
    /// (then `1`, `3`, `2`), with Paschaltide's *allelúia*.
    func versiculumAnteLaudes(
        winner: OccurrenceResult, resolver: SectionResolver, macroContext: MacroContext, englishResolver: SectionResolver?
    ) -> (latin: [String], english: [String]?) {
        let special = "Psalterium/Special/Major Special"
        let weekName = macroContext.weekName
        var location = proprium("Versum 0", flag: true, winner: winner, resolver: resolver, weekName: weekName)
        if location == nil {
            let prefix = Self.tempora(
                caller: "getfrompsalterium major", weekName: weekName, dayOfWeek: macroContext.dayOfWeek, day: macroContext.officeDay,
                officeTitle: winner.winningRank.title, rite: resolver.context.rite, hour: .laudes
            )
            location = ["0", "1", "3", "2"].lazy.map { (special, "\(prefix) Versum \($0)") }
                .first { resolver.sectionExists(path: $0.0, section: $0.1) }
        }
        guard let location else { return ([], nil) }
        let texts = bothTexts(path: location.path, section: location.section, resolver: resolver, englishResolver: englishResolver)
        // `replaceNdot`: the saint's name for "N." (*Ora pro nobis, beáte Hilárium*, 14 January).
        // When the day's office has no `[Name]`, DO falls back to the commemorated office's,
        // naming another saint (*beáte Pauli* on Bl. Francis de Capillas's day, 15 January
        // 2026); the Common's "N." is kept instead (`docs/rubrics-op1962.md` §8).
        var named = winner.winningPath
        if !SectionResolver.correctsDOErrors, !resolver.sectionExists(path: named, section: "Name"),
            let commemorated = Commemorations(corpus: corpus, context: context, calendar: calendar)
                .laudsCommemorations(day: macroContext.day, month: macroContext.month, year: macroContext.year).first?.path
        {
            named = commemorated
        }
        func lines(_ text: String, english: Bool) -> [String] {
            text.split(separator: "\n", omittingEmptySubsequences: false).map {
                let line = Self.applyingSeasonalAlleluia(to: String($0), weekName: weekName, isFirstVespers: false, english: english, season: macroContext.seasonWeekName)
                return substituteName(in: line, office: named, resolver: english ? (englishResolver ?? resolver) : resolver)
            }
        }
        return (lines(texts.latin, english: false), texts.english.map { lines($0, english: true) })
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
                let alleluia = Self.applyingSeasonalAlleluia(to: line, weekName: weekName, isFirstVespers: false, english: english, season: macroContext.seasonWeekName)
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
