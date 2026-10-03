/// The rite an office is said in (`CLAUDE.md`, Rite abstraction). The Roman office is the
/// engine as built since the alpha; the Dominican office (Beta 5) is DO's *Ordo
/// Praedicatorum - 1962*, the 1960 rubrics with a calendar of differences, its own
/// `TemporaOP`, `SanctiOP` and `CommuneOP` files and about thirty branches in DO's code
/// (`docs/rubrics-op1962.md`).
public enum Rite: String, CaseIterable, Codable, Sendable {
    case romanus
    case dominicanus

    /// DO's version string (`Tabulae/data.txt`), which `ConditionalContext.rubrica` and
    /// every `$version` test match against.
    public var doVersion: String {
        switch self {
        case .romanus: "Rubrics 1960 - 1960"
        case .dominicanus: "Ordo Praedicatorum - 1962"
        }
    }

    /// The suffix DO adds to `Tempora`, `Sancti` and `Commune` for this rite
    /// (`horascommon.pl:2160-2166`, `subdirname`).
    public var folderSuffix: String {
        switch self {
        case .romanus: ""
        case .dominicanus: "OP"
        }
    }

    /// The path DO reads for `folder/name` in this rite: the rite's own folder
    /// (`SanctiOP/01-15OP`) when the Latin corpus has the file there, else the Roman one
    /// (`SetupString.pl:830-845`, `checklatinfile`: "OSB & OP => Roman"). The check is
    /// on the Latin corpus, as DO's is, whatever the language being read.
    public func path(_ folder: String, _ name: String, latin: OfficeCorpus) -> String {
        guard !folderSuffix.isEmpty else { return "\(folder)/\(name)" }
        let own = "\(folder)\(folderSuffix)/\(name)"
        return latin.fileExists(path: own) ? own : "\(folder)/\(name)"
    }

    /// A path DO builds with `subdirname` (`Tempora/…`, `Sancti/…`, `Commune/…`), in this
    /// rite: `path(_:_:latin:)` on its folder and name. Any other path, and every path
    /// in the Roman rite, is returned as it is.
    public func adjusted(_ path: String, latin: OfficeCorpus) -> String {
        guard !folderSuffix.isEmpty, let slash = path.firstIndex(of: "/") else { return path }
        let folder = String(path[..<slash])
        guard ["Tempora", "Sancti", "Commune"].contains(folder) else { return path }
        return self.path(folder, String(path[path.index(after: slash)...]), latin: latin)
    }
}

extension ConditionalContext {
    /// The rite this context's version string names (`Rite.doVersion`); the Roman office
    /// for any other version.
    public var rite: Rite {
        Rite.allCases.first { $0.doVersion == rubrica } ?? .romanus
    }
}
