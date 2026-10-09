import Foundation

/// Beta 6: the Ambrosian sources (`data/ambrosian/`), read by the data tool into the
/// bundle. Nothing here touches Divinum Officium: the Ambrosian office is its own
/// provider (`docs/ambrosian-sources.md`, rule 1: no Roman fallback).

/// One piece of the Compline transcription (`completorium-1957.txt`): an id, the source
/// pages that print it (`HI.2`: *Pars hiemalis prima*, page 2), and its lines.
public struct AmbrosianPiece: Codable, Sendable, Equatable {
    public var id: String
    public var pages: [String]
    public var lines: [String]

    public init(id: String, pages: [String], lines: [String]) {
        self.id = id
        self.pages = pages
        self.lines = lines
    }
}

/// One day of the *Kalendarium Ambrosianum* (`kalendarium.txt`).
public struct AmbrosianCalendarEntry: Codable, Sendable, Equatable {
    /// `MM-DD`.
    public var date: String
    public var feast: String
    public var rank: String
    public var note: String
    /// The calendar page (`XV` to `XVIII`).
    public var page: String

    public init(date: String, feast: String, rank: String, note: String, page: String) {
        self.date = date
        self.feast = feast
        self.rank = rank
        self.note = note
        self.page = page
    }
}

/// Everything the bundle carries for the Ambrosian rite.
public struct AmbrosianData: Codable, Sendable, Equatable {
    /// Compline, corrected and spelt by the app's Latin rules, by piece id.
    public var compline: [AmbrosianPiece]
    public var calendar: [AmbrosianCalendarEntry]

    public init(compline: [AmbrosianPiece], calendar: [AmbrosianCalendarEntry]) {
        self.compline = compline
        self.calendar = calendar
    }
}

public enum AmbrosianSource {
    public enum SourceError: Error, CustomStringConvertible {
        case malformedHeader(String)
        case lineOutsidePiece(String)
        case correctionNotFound(piece: String, printed: String, occurrences: Int)
        case unknownPiece(String)
        case malformedCalendarLine(String)

        public var description: String {
            switch self {
            case .malformedHeader(let line): "malformed piece header: \(line)"
            case .lineOutsidePiece(let line): "a line before the first piece: \(line)"
            case .correctionNotFound(let piece, let printed, let n): "correction for [\(piece)]: \"\(printed)\" occurs \(n) times, not once"
            case .unknownPiece(let piece): "correction for an unknown piece [\(piece)]"
            case .malformedCalendarLine(let line): "malformed calendar line: \(line)"
            }
        }
    }

    /// One line of `corrections.txt`.
    public struct Correction: Sendable, Equatable {
        public enum Kind: String, Sendable { case misprint, doubtful, expansion, ruling, witness }
        public var piece: String
        public var printed: String
        public var shown: String
        public var kind: Kind
        public var pages: String
        public var note: String

        /// Applied to the text: misprints and expansions. Doubtful readings are listed
        /// for the user, rulings are built by the engine, witnesses need nothing.
        public var isApplied: Bool { kind == .misprint || kind == .expansion }
    }

    /// The pieces of `completorium-1957.txt`, as transcribed.
    public static func pieces(_ text: String) throws -> [AmbrosianPiece] {
        var pieces: [AmbrosianPiece] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") {
                guard let close = line.firstIndex(of: "]") else { throw SourceError.malformedHeader(line) }
                let id = String(line[line.index(after: line.startIndex)..<close])
                let pages = line[line.index(after: close)...].split(separator: " ").map(String.init)
                pieces.append(AmbrosianPiece(id: id, pages: pages, lines: []))
                continue
            }
            guard !pieces.isEmpty else { throw SourceError.lineOutsidePiece(line) }
            pieces[pieces.count - 1].lines.append(line)
        }
        return pieces
    }

    /// The lines of `corrections.txt`.
    public static func corrections(_ text: String) -> [Correction] {
        text.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let fields = line.components(separatedBy: " | ").map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count >= 5, let kind = Correction.Kind(rawValue: fields[3]) else { return nil }
            return Correction(
                piece: fields[0], printed: fields[1], shown: fields[2], kind: kind, pages: fields[4],
                note: fields.count > 5 ? fields[5...].joined(separator: " | ") : ""
            )
        }
    }

    /// The pieces with every misprint and expansion applied. Each "as printed" text must
    /// occur exactly once in its piece, so a correction can't silently miss or hit twice.
    public static func corrected(_ pieces: [AmbrosianPiece], with corrections: [Correction]) throws -> [AmbrosianPiece] {
        var pieces = pieces
        for correction in corrections where correction.isApplied {
            guard let index = pieces.firstIndex(where: { $0.id == correction.piece }) else {
                throw SourceError.unknownPiece(correction.piece)
            }
            let joined = pieces[index].lines.joined(separator: "\n")
            let occurrences = joined.components(separatedBy: correction.printed).count - 1
            guard occurrences == 1 else {
                throw SourceError.correctionNotFound(piece: correction.piece, printed: correction.printed, occurrences: occurrences)
            }
            pieces[index].lines = joined.replacingOccurrences(of: correction.printed, with: correction.shown)
                .components(separatedBy: "\n")
        }
        return pieces
    }

    /// The app's Latin rule (`CLAUDE.md`): I, not J. The source's accents stay as they
    /// are; none are added (Beta 6 plan, question 9).
    public static func spelt(_ text: String) -> String {
        var result = ""
        for character in text {
            switch character {
            case "j": result.append("i")
            case "J": result.append("I")
            default: result.append(character)
            }
        }
        return result
    }

    /// The calendar lines of `kalendarium.txt`.
    public static func calendar(_ text: String) throws -> [AmbrosianCalendarEntry] {
        try text.split(separator: "\n").compactMap { raw -> AmbrosianCalendarEntry? in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let fields = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count == 5, fields[0].count == 5 else { throw SourceError.malformedCalendarLine(line) }
            return AmbrosianCalendarEntry(
                date: fields[0], feast: spelt(fields[1]), rank: fields[2], note: spelt(fields[3]), page: fields[4]
            )
        }
    }

    /// What the bundle carries: the transcription corrected and spelt, and the calendar.
    public static func data(compline: String, corrections correctionsText: String, calendar calendarText: String) throws -> AmbrosianData {
        let corrected = try corrected(try pieces(compline), with: corrections(correctionsText))
        let compline = corrected.map { piece in
            AmbrosianPiece(id: piece.id, pages: piece.pages, lines: piece.lines.map { Self.spelt($0) })
        }
        return AmbrosianData(compline: compline, calendar: try calendar(calendarText))
    }
}
