/// A source of parsed (but unresolved) office files, keyed by path — what
/// `SectionResolver` reads from. `BreviariumKit` backs this with the bundle
/// `BreviariumData` produced; tests back it with a handful of in-memory files.
public protocol OfficeCorpus: Sendable {
    /// Every raw section variant named `name` in the file at `path`, in file order.
    /// Empty if the file doesn't exist or has no section by that name.
    func rawSections(path: String, name: String) -> [RawSection]

    /// The whole-file inclusion `path`'s own preamble declares (`do-format.md`'s "A
    /// reference appearing in the file's preamble... is a whole-file inclusion"), if
    /// any — `nil` if the file has none, or doesn't exist. Real example:
    /// `Commune/C7a.txt`'s own leading `@Commune/C7` line, needed because `C7a` defines
    /// only its own Mass-proper overrides and has no `[Ant Vespera]`/`[Hymnus Vespera]`
    /// of its own at all. Carries its own raw, unevaluated condition (see
    /// `BaseFileReference`) when the inclusion line is itself conditionally gated.
    func baseFile(path: String) -> BaseFileReference?
}

/// A simple in-memory `OfficeCorpus`, backing both `BreviariumKit`'s loaded bundle and
/// `SectionResolver`'s own tests.
public struct InMemoryOfficeCorpus: OfficeCorpus {
    private let filesByPath: [String: RawOfficeFile]

    public init(files: [RawOfficeFile]) {
        filesByPath = Dictionary(uniqueKeysWithValues: files.map { (Self.normalize($0.path), $0) })
    }

    public func rawSections(path: String, name: String) -> [RawSection] {
        filesByPath[Self.normalize(path)]?.sections.filter { $0.name == name } ?? []
    }

    public func baseFile(path: String) -> BaseFileReference? {
        filesByPath[Self.normalize(path)]?.baseFile
    }

    /// `@` references never carry a `.txt` extension, but a `RawOfficeFile.path` — its
    /// own on-disk identity — naturally does. Normalising here means either form works
    /// as a lookup key, regardless of which one a caller happens to use.
    private static func normalize(_ path: String) -> String {
        path.hasSuffix(".txt") ? String(path.dropLast(4)) : path
    }
}
