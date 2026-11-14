import Foundation

/// The widget's data file (1.5, `docs/1.5_plan.md` §4): the same `DataBundle` the app
/// reads, minus the English, packed so that a file of the corpus is decoded only when
/// the engine first asks for it.
///
/// Why: WidgetKit extensions run in a small memory budget (about 30 MB is the figure
/// usually given; Apple doesn't document it), and decoding the whole bundle the way
/// `OfficeDataStore` does peaks at about 37 MB above the process's baseline on Linux,
/// even without the English. A day's eight hours read at most about 80 of the corpus's
/// 3,873 files (under 0.5 MB of JSON), so reading them one by one keeps the widget well
/// inside the budget. It is still the whole corpus, so any date works and nothing is
/// precomputed (`CLAUDE.md`: no precomputed ordo).
///
/// Layout: the 8-byte magic `BRVPACK1`, the header's length as a little-endian `UInt64`,
/// the header (JSON: `Header`), then the files, each one `RawOfficeFile` as JSON, at the
/// offsets the header's indexes give (relative to the end of the header).
public struct PackedBundle: Sendable {
    /// The bundle's calendars, transfer tables and Ambrosian data: a `DataBundle` whose
    /// `latin`, `latinBea` and `english` are empty, so every factory below is
    /// `DataBundle`'s own.
    public let tables: DataBundle
    private let latin: PackedOfficeCorpus
    private let latinBea: PackedOfficeCorpus

    static let magic = Array("BRVPACK1".utf8)

    struct Header: Codable {
        var tables: DataBundle
        /// Path → `[offset, length]` within the files area.
        var latin: [String: [Int]]
        var latinBea: [String: [Int]]
    }

    public enum ReadError: Error, Equatable {
        case notAPack
        case truncated
    }

    /// Reads a pack. Pass memory-mapped data (`Data(contentsOf:options: .alwaysMapped)`)
    /// so the files area stays clean, file-backed memory rather than the process's own.
    public init(data: Data) throws {
        let bytes = [UInt8](data.prefix(16))
        guard bytes.count == 16, Array(bytes[0 ..< 8]) == Self.magic else { throw ReadError.notAPack }
        var length: UInt64 = 0
        for (index, byte) in bytes[8 ..< 16].enumerated() { length |= UInt64(byte) << (8 * UInt64(index)) }
        let headerStart = data.startIndex + 16
        guard length <= UInt64(data.count - 16) else { throw ReadError.truncated }
        let headerEnd = headerStart + Int(length)
        let header = try JSONDecoder().decode(Header.self, from: data[headerStart ..< headerEnd])
        tables = header.tables
        latin = PackedOfficeCorpus(data: data, filesStart: headerEnd, index: header.latin)
        latinBea = PackedOfficeCorpus(data: data, filesStart: headerEnd, index: header.latinBea)
    }

    /// Packs a bundle (the English is left out: the widget is Latin only).
    public static func pack(_ bundle: DataBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var files = Data()
        func add(_ list: [RawOfficeFile]) throws -> [String: [Int]] {
            var index: [String: [Int]] = [:]
            for file in list {
                let blob = try encoder.encode(file)
                index[PackedOfficeCorpus.normalize(file.path)] = [files.count, blob.count]
                files.append(blob)
            }
            return index
        }
        let latinIndex = try add(bundle.latin)
        let beaIndex = try add(bundle.latinBea)
        var tables = bundle
        tables.latin = []
        tables.latinBea = []
        tables.english = []
        let header = try encoder.encode(Header(tables: tables, latin: latinIndex, latinBea: beaIndex))

        var output = Data(Self.magic)
        var length = UInt64(header.count)
        for _ in 0 ..< 8 {
            output.append(UInt8(length & 0xFF))
            length >>= 8
        }
        output.append(header)
        output.append(files)
        return output
    }

    /// The Latin corpus for a psalter, as `DataBundle.makeLatinCorpus(psalter:)` layers it.
    public func makeLatinCorpus(psalter: Psalter) -> OfficeCorpus {
        switch psalter {
        case .vulgate: latin
        case .pius12: LayeredOfficeCorpus(layers: [latinBea, latin])
        }
    }

    public func makeSanctoralCalendar(rite: Rite = .romanus) -> SanctoralCalendar {
        tables.makeSanctoralCalendar(rite: rite)
    }

    /// Beta 6: Ambrosian Compline, from its own sources.
    public var ambrosianCompline: AmbrosianCompline? { tables.ambrosian.map(AmbrosianCompline.init(data:)) }

    /// Every path in the Latin corpus (for the tests that compare a pack with its bundle).
    public var latinPaths: [String] { latin.paths }
}

/// An `OfficeCorpus` that decodes each file the first time it is asked for, and keeps it.
/// Answers exactly as `InMemoryOfficeCorpus` does over the same files.
final class PackedOfficeCorpus: OfficeCorpus, @unchecked Sendable {
    private let data: Data
    private let filesStart: Int
    private let index: [String: [Int]]
    /// Guarded by `lock`: the decoded files, `nil` for one that failed to decode.
    private var cache: [String: RawOfficeFile?] = [:]
    private let lock = NSLock()

    init(data: Data, filesStart: Int, index: [String: [Int]]) {
        self.data = data
        self.filesStart = filesStart
        self.index = index
    }

    var paths: [String] { index.keys.sorted() }

    func rawSections(path: String, name: String) -> [RawSection] {
        file(path)?.sections.filter { $0.name == name } ?? []
    }

    func baseFile(path: String) -> BaseFileReference? {
        file(path)?.baseFile
    }

    func fileExists(path: String) -> Bool {
        index[Self.normalize(path)] != nil
    }

    private func file(_ path: String) -> RawOfficeFile? {
        let key = Self.normalize(path)
        guard let range = index[key], range.count == 2 else { return nil }
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let start = filesStart + range[0]
        let end = start + range[1]
        let decoded: RawOfficeFile? = end <= data.endIndex ? try? JSONDecoder().decode(RawOfficeFile.self, from: data[start ..< end]) : nil
        cache[key] = decoded
        return decoded
    }

    /// As `InMemoryOfficeCorpus` keys its files: without the `.txt` extension.
    static func normalize(_ path: String) -> String {
        path.hasSuffix(".txt") ? String(path.dropLast(4)) : path
    }
}
