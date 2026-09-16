import Foundation
import Testing
@testable import BreviariumDataCore

@Test func calendarChainOrderMatchesDataTxtBaseChain() {
    // web/www/Tabulae/data.txt's base column, walked by hand in CalendarChainReader:
    // 1960 -> Reduced-1955 -> Divino Afflatu-1954 -> Divino Afflatu-1939 ->
    // Tridentine-1906 -> Tridentine-1888 -> Tridentine-1570 (the ultimate base).
    #expect(CalendarChainReader.chainOldestFirst == ["1570", "1888", "1906", "1939", "1954", "1955", "1960"])
}

@Test func flattenedCalendarReadsRealFilesInChainOrder() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let kalendariaDir = root.appendingPathComponent("Kalendaria")
    try FileManager.default.createDirectory(at: kalendariaDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let filesByVersion: [String: String] = [
        "1570": "01-01=01-01=Circumcisio=3=",
        "1888": "",
        "1906": "",
        "1939": "",
        "1954": "",
        "1955": "",
        "1960": "01-01=XXXXX",    // 1960 explicitly removes what 1570 assigned.
    ]
    for (version, content) in filesByVersion {
        try content.write(to: kalendariaDir.appendingPathComponent("\(version).txt"), atomically: true, encoding: .utf8)
    }

    let calendar = try CalendarChainReader.flattenedCalendar(tabulaeRoot: root)
    #expect(calendar["01-01"] == "XXXXX")
}
