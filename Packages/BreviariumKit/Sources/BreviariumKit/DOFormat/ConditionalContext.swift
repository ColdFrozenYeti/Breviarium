/// The full evaluation context a DO conditional clause is tested against.
///
/// Unlike `BreviariumData` (which never evaluates conditionals at all — see
/// `docs/PLAN.md`'s 2026-09-16 amendment), `BreviariumKit`'s resolution engine only ever
/// runs this at render time, when every one of these is genuinely known for the specific
/// day/hour being rendered. There is no "partial" or "unknown" state to represent.
///
/// Field names mirror the DO subject names in `SetupString.pl`'s `%subjects` table
/// (`rubrica`/`rubricis`, `tempore`, `missa`, `communi`/`commune`, `die`, `feria`,
/// `votiva`, `officio`, `ad`, `mense`, `dioecesis`) so the mapping in
/// `ConditionalEvaluator` stays easy to check against the source.
public struct ConditionalContext: Equatable, Sendable {
    /// The rubrics version string, e.g. "Rubrics 1960 - 1960". Tested with a
    /// case-insensitive substring/regex match, exactly as DO does (`rubrica`/`rubricis`).
    public var rubrica: String

    /// The liturgical season name for the day, e.g. "Adventus", "post Pentecosten" —
    /// DO's `get_tempus_id()` result (`tempore`).
    public var tempore: String

    /// A named-day condition value from DO's `get_dayname_for_condition()` (`die`), e.g.
    /// "Epiphaniae", "Nativitatis" — empty string when no special name applies, matching
    /// DO's own function returning `''` in that case.
    public var die: String

    /// Day of week + 1 (DO's `feria`; 1 = Sunday ... 7 = Saturday, matching
    /// `$dayofweek + 1` in `horascommon.pl`).
    public var feria: Int

    /// Whether this is a Mass (missa) rather than an Office (horas). Always `false` for
    /// this project — Breviarium never renders Mass propers.
    public var missa: Bool

    /// The commune type in use for the winning office of the day, if any (`commune`).
    public var commune: String

    /// The votive-office number, if any (`votiva`). `0`/empty when not a votive office.
    public var votiva: String

    /// The specific office name (`officio`, DO's `$dayname[1]`).
    public var officio: String

    /// The hour being rendered, lowercase, e.g. "vesperas" (`ad`; DO uses `missam` for
    /// Mass, but `missa` is always false here so this is always an hour name).
    public var ad: String

    /// Calendar month, 1-12 (`mense`).
    public var mense: Int

    /// The diocese/calendar in use. Always "Generale" for this project (no diocesan or
    /// national propers — `CLAUDE.md`, Liturgical scope).
    public var dioecesis: String

    public init(
        rubrica: String,
        tempore: String,
        die: String = "",
        feria: Int,
        missa: Bool = false,
        commune: String = "",
        votiva: String = "",
        officio: String = "",
        ad: String,
        mense: Int,
        dioecesis: String = "Generale"
    ) {
        self.rubrica = rubrica
        self.tempore = tempore
        self.die = die
        self.feria = feria
        self.missa = missa
        self.commune = commune
        self.votiva = votiva
        self.officio = officio
        self.ad = ad
        self.mense = mense
        self.dioecesis = dioecesis
    }

    /// Looks up a subject's string value by DO's subject name. Returns `nil` for a name
    /// DO doesn't define as a subject (which `vero` then treats as a parse failure, same
    /// as `SetupString.pl` — an unrecognised subject makes the clause false).
    func value(forSubject subject: String) -> String? {
        switch subject.lowercased() {
        case "rubricis", "rubrica": return rubrica
        case "tempore": return tempore
        case "missa": return missa ? "1" : "0"
        case "communi": return rubrica    // SetupString.pl: communi => sub {$version}
        case "die": return die
        case "feria": return String(feria)
        case "commune": return commune
        case "votiva": return votiva
        case "officio": return officio
        case "ad": return missa ? "missam" : ad
        case "mense": return String(mense)
        case "dioecesis": return dioecesis
        default: return nil
        }
    }
}
