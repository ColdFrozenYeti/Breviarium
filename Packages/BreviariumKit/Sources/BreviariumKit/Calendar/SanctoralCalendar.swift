import Foundation

/// Wraps the flattened 1960 sanctoral calendar table (`DataBundle.calendar`,
/// `KalendariaResolver`) with date-based lookup, plus the annual transfer tables
/// (`DataBundle.transferTable`, `TransferResolver`) that can override a specific date's
/// candidates in a specific year — e.g. the Annunciation or St Joseph, displaced by Holy
/// Week/the Easter Octave or a Lenten Sunday onto a later free day.
public struct SanctoralCalendar: Sendable {
    public var entries: [String: String]
    public var transferTable: [String: [String: String]]
    /// `Tabulae/Tempora/Generale.txt`'s own version-gated whole-week redirect table
    /// (`TemporaRedirectResolver`) — see `redirectedTemporalPath`'s own doc comment.
    public var temporaRedirect: [String: String]

    public init(
        entries: [String: String], transferTable: [String: [String: String]] = [:],
        temporaRedirect: [String: String] = [:]
    ) {
        self.entries = entries
        self.transferTable = transferTable
        self.temporaRedirect = temporaRedirect
    }

    /// Candidate `Sancti` file references for a date, in priority order (a Kalendaria
    /// entry can list several `~`-separated candidates — `do-format.md`). The `"XXXXX"`
    /// removal sentinel and any empty entries are filtered out; the result is empty when
    /// there's no sanctoral office at all on this date.
    ///
    /// When this date is an annual-transfer *target* in this year (e.g. 5 April 2027,
    /// the first free day after the Easter Octave once the Annunciation is displaced
    /// from its own 25 March), the transferred office(s) **replace** the normal
    /// Kalendaria candidates entirely for this lookup — matching `horascommon.pl`'s own
    /// `$sfile = $transfer; @commemoentries = @transfers;` (not merging the two), so the
    /// transferred feast still competes for the day through the ordinary rank comparison
    /// `Occurrence` already does, and any second `~`-joined piece still becomes an
    /// ordinary commemoration runner-up through `Commemorations`, both automatically —
    /// neither of those two types needed a single change for this.
    public func candidates(day: Int, month: Int, year: Int) -> [String] {
        let key = Computus.sanctoralKey(day: day, month: month, year: year)
        if let transferred = transferredCandidates(targetKey: key, year: year) {
            return transferred
        }
        guard let raw = entries[key] else { return [] }
        return raw.split(separator: "~")
            .map(String.init)
            .filter { !$0.isEmpty && !KalendariaResolver.isRemovalSentinel($0) }
    }

    /// Looks up `targetKey` in the merged transfer table for `year`'s own Easter date —
    /// the single-letter "dominical letter" file first, then the exact Easter-`MMDD`
    /// numeric file overriding it for the same key, matching `Directorium.pm`'s
    /// `load_transfers`'s own letter-then-numeric push order (a later push wins the
    /// hash). Returns `nil` (falling through to the ordinary Kalendaria lookup) unless
    /// every `~`-joined piece is Sancti-style — see `TransferResolver`'s own doc comment
    /// for why a `Tempora/`-referencing or `"X-X"` piece isn't handled by this method.
    private func transferredCandidates(targetKey: String, year: Int) -> [String]? {
        guard let source = transferSource(targetKey: targetKey, year: year) else { return nil }
        // `X-X`/`X/X` name no file: the day's own office is suppressed that year, DO
        // finding no Sancti office at all (`Transfer/417.txt`'s `06-23=X/X;;1960`: the
        // Baptist's vigil gives way when the Sacred Heart takes 24 June, as in 2033).
        if source == "X-X" || source == "X/X" { return [] }
        let pieces = source.split(separator: "~").map(String.init).filter { !$0.isEmpty }
        guard !pieces.isEmpty, pieces.allSatisfy(Self.isSanctiStyleTransferSource) else { return nil }
        return pieces
    }

    /// The analogous lookup to `transferredCandidates`, for a transfer entry whose
    /// source is a `Tempora/...` path rather than a Sancti reference — real example:
    /// `01-05=Tempora/Nat2-0` (under 2025's own dominical letter), redirecting 5
    /// January's Vespers to a week-numbered Sunday file instead of the plain
    /// day-numbered `Tempora/Nat05`, confirmed against the real DO engine directly (a
    /// debug trace inside the pinned Docker container, not guessed): `$winner` there is
    /// literally `Tempora/Nat2-0.txt`, not `Tempora/Nat04`/`Nat05`. `nil` falls through
    /// to the ordinary week-name computation (`TemporalCycle.weekName`).
    public func transferredTemporalPath(day: Int, month: Int, year: Int) -> String? {
        let key = Computus.sanctoralKey(day: day, month: month, year: year)
        guard let source = transferSource(targetKey: key, year: year), source.hasPrefix("Tempora/"), !source.contains("~")
        else { return nil }
        return source
    }

    /// The merged transfer-table lookup shared by `transferredCandidates` and
    /// `transferredTemporalPath` — letter file first, then the exact Easter-`MMDD`
    /// numeric file overriding it for the same key, matching `Directorium.pm`'s own
    /// `load_transfers` push order (a later push wins the hash).
    ///
    /// **Leap years split the letter file in two by date range**, a distinction this
    /// project's `transferSource` had missed entirely (see the reverted first attempt
    /// below). `load_transfers` (`Directorium.pm:141-162`) always loads the *primary*
    /// letter file through `load_transfer_file`'s own `$filter` parameter
    /// (`Directorium.pm:55-73`): `$isleap` itself is that filter, and `load_transfer_file`
    /// treats `1` as "Feb 24 - Dec" (excluding every January/early-February line via its
    /// own regex) and `0` as "whole year" (no filtering at all). So in an ordinary year
    /// (`$isleap == 0`) the primary file supplies every date as before; in a leap year
    /// (`$isleap == 1`) its own January/Feb-1-23 entries are silently dropped. Only then,
    /// inside `load_transfers`'s own `if ($isleap)` branch, a *second* letter file is
    /// loaded to fill exactly that gap: `push(@lines, load_transfer_file($letters[$letter
    /// - 6], 2, ...))` — Perl's negative array index wraps from the end, so `$letters[
    /// $letter - 6]` is really `$letters[$letter + 1]` (mod 7) — with filter `2`,
    /// `load_transfer_file`'s own "Jan + Feb 23" branch (the mirror image of `1`).
    ///
    /// A first attempt at this fix loaded the extra letter file unconditionally for
    /// *every* key in a leap year, not just January/Feb-23 ones — regressing 30 October
    /// 2028 (Christ the King) and 30 December 2028 (Holy Family) on the very next full
    /// sweep, both wrongly picking up the *other* letter's own October/December entries.
    /// Reverted in the same session before landing; this version instead mirrors
    /// `load_transfer_file`'s own regex exactly (`isJanuaryOrEarlyFebruaryTransferKey`),
    /// so the two files stay mutually exclusive by date range, matching the real script.
    ///
    /// Confirmed real for 4 January 2032 and 2 January 2036 (both leap years): the real
    /// fixture's title is "Sanctissimi Nominis Jesu ~ II. classis" — the primary letter
    /// computed for both years is `"c"` (whose own `01-03` entry is dropped that year by
    /// the leap-year filter regardless), while `Transfer/d.txt`'s own
    /// `"01-04=Tempora/Nat2-0"` (reached only via the extra file) is what actually
    /// applies. The corresponding *extra numeric* file `load_transfers` also loads in the
    /// same branch (`$easter++` first, wrapping `332` to `401`) is deliberately not
    /// ported here — every numeric transfer file this corpus bundles (`Transfer/322.txt`
    /// ... `426.txt`) only ever carries March/April Annunciation-adjacent keys, never a
    /// January/February one, so it can't affect this gap either way; left for a future
    /// pass if a real fixture ever needs it.
    /// `initiarule` (`specmatins.pl:1611-1624`): the Scripture transfer entry for the date
    /// (`Tabulae/Stransfer`), e.g. `Epi1-0a` for 12 January under letter `f` (2030).
    public func scriptureTransfer(day: Int, month: Int, year: Int) -> String? {
        transferSource(targetKey: Computus.sanctoralKey(day: day, month: month, year: year), year: year, prefix: "S:")
    }

    private func transferSource(targetKey: String, year: Int, prefix: String = "") -> String? {
        guard !transferTable.isEmpty else { return nil }

        let easter = Computus.easter(year: year)
        let numericKey = "\(easter.month)\(String(format: "%02d", easter.day))"
        let easterNumber = easter.month * 100 + easter.day
        let letters = ["a", "b", "c", "d", "e", "f", "g"]
        let letterIndex = (easterNumber - 319 + (easter.month == 4 ? 1 : 0)) % 7
        let letterKey = letters[letterIndex]
        let isLeap = Computus.isLeapYear(year)
        let isJanOrEarlyFeb = Self.isJanuaryOrEarlyFebruaryTransferKey(targetKey)

        var source: String?
        if !(isLeap && isJanOrEarlyFeb) {
            if let letterFile = transferTable[prefix + letterKey], let value = letterFile[targetKey] { source = value }
        }
        if let numericFile = transferTable[prefix + numericKey], let value = numericFile[targetKey] { source = value }
        if isLeap, isJanOrEarlyFeb {
            let extraLetterKey = letters[(letterIndex + 1) % 7]
            if let extraLetterFile = transferTable[prefix + extraLetterKey], let value = extraLetterFile[targetKey] { source = value }
        }
        return source?.isEmpty == false ? source : nil
    }

    /// Mirrors `load_transfer_file`'s own regex exactly (`Directorium.pm:63`):
    /// `^(?:Hy|seant)?(?:01|02-[01]|02-2[01239]|dirge1)` — this project's transfer-table
    /// keys are always plain `MM-DD` dates (`Computus.sanctoralKey`), so only the date
    /// portion of that alternation is relevant: any `01-*` key, or `02-0*`/`02-1*`
    /// (1-19 February), or `02-2` followed by `0`/`1`/`2`/`3`/`9` (20-23 and 29
    /// February — the regex's own character class `[01239]` really does skip 24-28).
    private static func isJanuaryOrEarlyFebruaryTransferKey(_ key: String) -> Bool {
        if key.hasPrefix("01") { return true }
        if key.hasPrefix("02-0") || key.hasPrefix("02-1") { return true }
        if key.hasPrefix("02-2"), let lastDigit = key.dropFirst(4).first {
            return "01239".contains(lastDigit)
        }
        return false
    }

    private static func isSanctiStyleTransferSource(_ reference: String) -> Bool {
        !reference.contains("/") && !reference.contains("Tempora") && reference != "X-X"
    }

    /// Mirrors `Directorium.pm`'s own `transfered()` (`Directorium.pm:235-269`): a
    /// *reverse* lookup across the same year's merged transfer table (the same letter/
    /// leap-extra-letter/numeric files `transferSource` already assembles forward),
    /// checking whether `candidateKey` (e.g. `"03-19"`) appears as the *value* of any
    /// entry — meaning this office has itself been transferred away to some other date
    /// this year, and so should never compete for a commemoration on its own natural
    /// date at all, regardless of the ordinary rank comparison.
    ///
    /// `occurrence()` calls the real `transfered()` immediately after fetching the
    /// day's own Kalendaria candidate (`horascommon.pl:229-232`: `elsif ($sfile &&
    /// transfered(...)) { $sfile = ''; }`), *before* any rank comparison against the
    /// temporal winner — this project's `Commemorations.runnersUp` only ever checked
    /// whether a candidate *lost* occurrence, never whether it had already been excluded
    /// from candidacy entirely this year. Confirmed real for 19 March 2035 (St Joseph):
    /// live Perl instrumentation showed both `@commemoentries`/`@ccommemoentries`
    /// completely empty for that Vespers, unlike an ordinary transfer year (2028) where
    /// St Joseph *does* survive as a same-day-loser commemoration candidate. Easter 2035
    /// falls unusually early (25 March), pushing 19 March into Holy Week itself — the
    /// year's own numeric transfer file (`Transfer/325.txt`) carries `"04-03=03-19"`,
    /// confirming St Joseph is transferred to 3 April that year, which is exactly the
    /// entry this reverse lookup finds.
    ///
    /// Two exclusions mirror the real check exactly: a `Tempora/`-referencing value is
    /// never a Sancti transfer (`$val =~ /Tempora/i && $val !~ /Epi1-0/i` `next`s), and a
    /// value ending in `v` is a vigil-only transfer, not a full transfer of the office
    /// itself (`$transfer{$key} !~ /v\s*$/i`).
    ///
    /// **Not yet applied to `Occurrence.resolve`'s own winner selection** — only to
    /// `Commemorations.runnersUp`, since that's the one confirmed broken; a transferred
    /// office losing occurrence to a naturally higher-ranked temporal winner (as St
    /// Joseph already does against Holy Week's own rank 7) never needed this exclusion to
    /// produce the right *winner*, only the right *commemoration* list. Extending it to
    /// occurrence itself is deferred until a real fixture is found that actually needs
    /// it, rather than guessed at.
    /// Whether the date's candidates come from a transfer entry of its own
    /// (`horascommon.pl:224`, `$transfer =~ /Sancti/`); DO then skips `transfered()`
    /// for them (`04-05=03-25~04-05` in 2027 keeps St Vincent Ferrer).
    public func hasOwnTransferEntry(day: Int, month: Int, year: Int) -> Bool {
        transferredCandidates(targetKey: Computus.sanctoralKey(day: day, month: month, year: year), year: year) != nil
    }

    public func isTransferredAwayThisYear(candidateKey: String, year: Int) -> Bool {
        guard !transferTable.isEmpty else { return false }

        let easter = Computus.easter(year: year)
        let numericKey = "\(easter.month)\(String(format: "%02d", easter.day))"
        let easterNumber = easter.month * 100 + easter.day
        let letters = ["a", "b", "c", "d", "e", "f", "g"]
        let letterIndex = (easterNumber - 319 + (easter.month == 4 ? 1 : 0)) % 7

        var filesToCheck = [transferTable[letters[letterIndex]], transferTable[numericKey]]
        if Computus.isLeapYear(year) {
            filesToCheck.append(transferTable[letters[(letterIndex + 1) % 7]])
        }

        for file in filesToCheck.compactMap({ $0 }) {
            for (key, value) in file {
                guard !value.isEmpty, !value.hasSuffix("v") else { continue }
                // `Directorium.pm:266`, `$val !~ /^$key/`: an entry that stays on its own
                // date moves nothing away (`e.txt`'s `08-09=08-09cc`: St Romanus in 2025).
                if value.hasPrefix(key) { continue }
                if value.range(of: "Tempora", options: .caseInsensitive) != nil { continue }
                if value.range(of: candidateKey, options: .caseInsensitive) != nil { return true }
            }
        }
        return false
    }

    /// `Tabulae/Tempora/Generale.txt`'s own version-gated whole-week redirect
    /// (`TemporaRedirectResolver`, `Directorium.pm`'s `load_tempora()`) — a *completely
    /// separate* mechanism from the annual, date-keyed transfer table above: this one is
    /// keyed by the temporal file path itself (`"Tempora/Quad6-6"`), not by date, and
    /// applies to every hour of the affected week (not just Vespers). Returns `path`
    /// unchanged when there's no matching entry (the overwhelming majority of dates).
    public func redirectedTemporalPath(_ path: String) -> String {
        temporaRedirect[path] ?? path
    }
}
