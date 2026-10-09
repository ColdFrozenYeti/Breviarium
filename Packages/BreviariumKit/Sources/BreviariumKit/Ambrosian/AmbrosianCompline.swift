/// Beta 6: Ambrosian Compline (*Completorium quotidianum*, 1957), assembled from Church of
/// Ambrose's transcription (`data/ambrosian/completorium-1957.txt`) by the order of the
/// hour in `docs/rubrics-ambrosian-compline.md` §2. It reads nothing from Divinum
/// Officium (`docs/ambrosian-sources.md`, rule 1), and every unit comes from a piece
/// with its source pages (`provenance`).
public struct AmbrosianCompline: Sendable {
    public let pieces: [String: AmbrosianPiece]
    public let calendar: AmbrosianCalendar

    public init(data: AmbrosianData) {
        var pieces = Dictionary(data.compline.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if let confessio = pieces["confessio"] { pieces["confessio-sine-sacerdote"] = Self.withoutPriest(confessio) }
        self.pieces = pieces
        calendar = AmbrosianCalendar(entries: data.calendar)
    }

    /// The user's ruling (9 October 2026; `corrections.txt`): without a priest, one
    /// Confiteor as in the Roman Compline, from the hebdomadary's own (with St Ambrose),
    /// without *et vobis, fratres* and *et vos, fratres*; then *Misereátur nostri*, as the
    /// Roman office says it, and the rest as printed. Its pages are the printed
    /// Confiteor's, marked `ruling`.
    static func withoutPriest(_ confessio: AmbrosianPiece) -> AmbrosianPiece {
        let lines = confessio.lines
        let confiteor = lines.first { $0.hasPrefix("Confiteor") }
            .map { $0.replacingOccurrences(of: " et vobis, fratres,", with: "").replacingOccurrences(of: " et vos, fratres,", with: "") }
        let tail = lines.drop { !$0.hasPrefix("Indulg") }
        return AmbrosianPiece(
            id: "confessio-sine-sacerdote", pages: ["ruling"] + confessio.pages,
            lines: (confiteor.map { [$0] } ?? [])
                + ["Misereatur nostri omnipotens Deus: et, dimissis peccatis nostris, perducat nos ad vitam æternam.", "R. Amen."]
                + tail
        )
    }

    /// The pieces the hour used, in order, with their pages: every unit of `assemble` is
    /// traceable to a page of the source.
    public func provenance(day: Int, month: Int, year: Int, priest: Bool) -> [(piece: String, pages: [String])] {
        plan(day: day, month: month, year: year, priest: priest).flatMap(\.pieces).compactMap { id in
            pieces[id].map { (piece: id, pages: $0.pages) }
        }
    }

    public func assemble(day: Int, month: Int, year: Int, priest: Bool) -> Hour {
        let sections = plan(day: day, month: month, year: year, priest: priest).compactMap { step -> Section? in
            var units: [Unit] = []
            for id in step.pieces {
                guard let piece = pieces[id] else { continue }
                units += Self.units(piece, dropping: step.droppedHeading, priest: priest)
            }
            return units.isEmpty ? nil : Section(kind: step.kind, units: units)
        }
        return Hour(sections: sections)
    }

    public func titleBlock(day: Int, month: Int, year: Int) -> TitleBlock {
        calendar.titleBlock(day: day, month: month, year: year)
    }

    // MARK: The order of the hour

    struct Step {
        var kind: Section.Kind
        var pieces: [String]
        /// The source's own red title for this section ("Hymnus.", "Capitulum"), which the
        /// section heading already shows.
        var droppedHeading: String?
    }

    /// `docs/rubrics-ambrosian-compline.md` §2, step by step.
    func plan(day: Int, month: Int, year: Int, priest: Bool) -> [Step] {
        let part = AmbrosianCalendar.part(day: day, month: month, year: year)
        let lent = part == .hiemalisSecunda
        let praise = lent ? "laustibi" : "hallelujah"
        let festal = calendar.isFestal(day: day, month: month, year: year)

        var steps: [Step] = [
            Step(kind: .introductio, pieces: ["praeparatio", "convertenos", "deusinadiutorium", praise]),
            Step(kind: .hymnus, pieces: [lent ? "hymnus-luxalma" : "hymnus-telucis"], droppedHeading: "Hymnus."),
            Step(kind: .psalmodia, pieces: [
                "psalmus4", "gloriapatri", "psalmus30", "gloriapatri", "psalmus90", "gloriapatri",
                "psalmus132", "psalmus133", "psalmus116", "gloriapatri", praise,
            ]),
        ]
        // Lent prints *Te lucis* again after the psalms (both hymns are said, the user,
        // 9 October 2026).
        if lent { steps.append(Step(kind: .hymnus, pieces: ["hymnus-telucis"], droppedHeading: "Hymnus.")) }
        steps += [
            Step(kind: .epistolella, pieces: ["epistolella"]),
            Step(kind: .responsoriumBreve, pieces: ["responsorium"]),
            Step(kind: .canticum, pieces: ["salvanos-incipit", "nuncdimittis", "salvanos"]),
            Step(kind: .capitulum, pieces: ["capitulum", praise, "kyrie", "rubrica-festiva-\(part.rawValue)"], droppedHeading: "Capitulum"),
        ]
        if !festal {
            var preces = ["preces", "psalmus12", "gloriapatri"]
            // Lent prints *Amen.* before *Laus tibi* after Psalm 12's *Glória*.
            if lent { preces.append("amen-HII") }
            preces += [praise, "aversio"]
            steps.append(Step(kind: .precesFeriales, pieces: preces))
        }
        steps += [
            Step(kind: .oratio, pieces: ["dominusvobiscum", "oratio"], droppedHeading: "Oratio"),
            Step(kind: .conclusio, pieces: ["dominusvobiscum", "kyrie", "benedictio", "finis"]),
        ]
        if let antiphon = AmbrosianCalendar.marianAntiphon(day: day, month: month, year: year) {
            var finalis: [String] = []
            if part == .hiemalisPrima || part == .aestivaSecunda { finalis.append("rubrica-antiphona") }
            finalis += [antiphon.rawValue, "fidelium"]
            steps.append(Step(kind: .antiphonaFinalis, pieces: finalis))
        }
        steps.append(Step(kind: .confessio, pieces: [priest ? "confessio" : "confessio-sine-sacerdote"]))
        return steps
    }

    // MARK: Pieces as units

    /// A piece's lines as units (the transcription's format, `completorium-1957.txt`).
    /// `priest`: off, *Dóminus vobíscum* becomes *Dómine, exáudi* (the user's ruling,
    /// 9 October 2026, as in the Roman office).
    static func units(_ piece: AmbrosianPiece, dropping droppedHeading: String?, priest: Bool) -> [Unit] {
        let psalm = piece.id.hasPrefix("psalmus") || piece.id == "nuncdimittis"
        var units: [Unit] = []
        var block: [String] = []
        var pendingVersicle: String?

        func flushBlock() {
            guard !block.isEmpty else { return }
            units.append(.prose(InlineRubrics.markingSourceDirections(block.joined(separator: "\n")), english: nil))
            block = []
        }
        func flushVersicle() {
            if let versicle = pendingVersicle { units.append(.versicleResponse(versicle: versicle, response: "")) }
            pendingVersicle = nil
        }

        var lines = piece.lines
        if let droppedHeading, lines.first == "^\(droppedHeading)" { lines.removeFirst() }
        for line in lines {
            if line == "_" {
                flushVersicle(); flushBlock()
            } else if line.hasPrefix("^") {
                flushVersicle(); flushBlock()
                units.append(.psalmTitle(String(line.dropFirst())))
            } else if line.hasPrefix("!") {
                flushVersicle(); flushBlock()
                units.append(.rubric(String(line.dropFirst()), english: nil))
            } else if line.hasPrefix("V. ") {
                flushVersicle(); flushBlock()
                var text = String(line.dropFirst(3))
                if !priest, text == "Dominus vobiscum." { text = "Domine, exaudi orationem meam." }
                pendingVersicle = text
            } else if line.hasPrefix("R. br. ") {
                flushVersicle(); flushBlock()
                units.append(.versicleResponse(versicle: "", response: String(line.dropFirst(7))))
            } else if line.hasPrefix("R. ") {
                flushBlock()
                var text = String(line.dropFirst(3))
                if !priest, text == "Et cum spiritu tuo." { text = "Et clamor meus ad te veniat." }
                units.append(.versicleResponse(versicle: pendingVersicle ?? "", response: text))
                pendingVersicle = nil
            } else if line.hasPrefix("Ant. ") {
                flushVersicle(); flushBlock()
                units.append(.antiphon(String(line.dropFirst(5)), english: nil))
            } else if psalm, let star = line.range(of: " * ") {
                flushVersicle(); flushBlock()
                let first = line[..<star.lowerBound].trimmingCharacters(in: .whitespaces) + "*"
                let second = String(line[star.upperBound...])
                units.append(.verse(reference: "", firstHalf: first, secondHalf: second))
            } else {
                flushVersicle()
                block.append(line)
            }
        }
        flushVersicle(); flushBlock()
        return units
    }
}

extension InlineRubrics {
    /// The Ambrosian source's directions inside a line, red in print: *(secreto)*,
    /// *(secr.)*, *(alta voce)*.
    static func markingSourceDirections(_ text: String) -> String {
        text.replacing(#/\((secreto|secr\.|alta voce)\)/#) { "\(start)\($0.output.0)\(end)" }
    }
}
