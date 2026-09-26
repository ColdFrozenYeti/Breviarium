/// Which office of the Roman rite is said (Beta 4, a setting under *Ritus Romanus*): the
/// day's own, or one of DO's votive offices, which take the day's place (`officium.pl`'s
/// `votive`, `horascommon.pl:1770-1830`).
public enum Officium: String, CaseIterable, Sendable, Codable {
    /// The day's office, as since the alpha.
    case diei
    /// *Officium parvum Beatæ Mariæ Virginis*, DO's `C12`.
    case parvumBMV
    /// *Officium defunctorum*, DO's `C9`.
    case defunctorum

    /// The hours the office has, in order (`dialogcommon.pl:54-60`: the Dead has only
    /// Matins, Lauds and Vespers).
    public var hours: [CanonicalHour] {
        switch self {
        case .diei, .parvumBMV: CanonicalHour.allCases
        case .defunctorum: [.matutinum, .laudes, .vesperae]
        }
    }

    /// `hour`, or the nearest earlier hour the office has (decided 2026-09-26): the Dead's
    /// Terce, Sext and None open Lauds, its Compline Vespers.
    public func availableHour(for hour: CanonicalHour) -> CanonicalHour {
        let order = CanonicalHour.allCases
        guard let index = order.firstIndex(of: hour) else { return hours[0] }
        for candidate in order[...index].reversed() where hours.contains(candidate) { return candidate }
        return hours[0]
    }

    /// The votive's Commune file for a date and hour (`horascommon.pl:1774-1785`); `nil`
    /// for the day's office. The Little Office has four seasonal forms: `C12N` from Christmas
    /// Eve's Vespers to 2 February, `C12A` in Advent and on the Annunciation, `C12Q` from
    /// Septuagesima to Easter, `C12` otherwise.
    func votivePath(hour: CanonicalHour, day: Int, month: Int, year: Int, weekName: String, dayWinnerPath: String) -> String? {
        switch self {
        case .diei:
            return nil
        case .defunctorum:
            return "Commune/C9"
        case .parvumBMV:
            if (month == 12 && ((day == 24 && (hour == .vesperae || hour == .completorium)) || day > 24)) || month == 1 || (month == 2 && day < 3) {
                return "Commune/C12N"
            }
            if weekName.range(of: "adv", options: .caseInsensitive) != nil || dayWinnerPath.contains("03-25") {
                return "Commune/C12A"
            }
            if weekName.range(of: "(Quadp|Quad)", options: .regularExpression) != nil {
                return "Commune/C12Q"
            }
            return "Commune/C12"
        }
    }

    /// The votive's rank as DO sets it (`horascommon.pl:1812-1847`). The Little Office has
    /// its own `[Rank]`, and takes Our Lady's Commune, `C11`, as `ex` in every form (even
    /// `C12N`, whose `[Rank]` names none). The Office of the Dead has no `[Rank]`: it keeps
    /// the day's rank, raised to 6 below 3 (I. classis, so that the whole Commune is read),
    /// and is its own Commune. `dayRank` `nil` gives the title's rank, which DO always shows
    /// as I. classis.
    static func votiveRank(path: String, resolver: SectionResolver, dayRank: Double?) -> OfficeRank? {
        if var rank = OfficeRank(rankFieldValue: resolver.resolveRank(path: path)) {
            if path.contains("C12") { rank.communeReference = "ex C11" }
            return rank
        }
        let title = resolver.resolve(path: path, section: "Officium").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let rank = dayRank.map { $0 >= 3 ? $0 : 6 } ?? 6
        return OfficeRank(title: title, degreeLabel: "", numericPrecedence: rank, communeReference: "ex " + path.replacingOccurrences(of: "Commune/", with: ""))
    }
}
