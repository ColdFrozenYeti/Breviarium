import Foundation
import BreviariumKit
#if canImport(Darwin)
import Darwin
#endif

/// The widget's memory and time budget (1.5, `docs/1.5_plan.md` §4), checked on every
/// run of this tool, so CI fails when the widget's data path outgrows it.
///
/// WidgetKit extensions are held to a small memory limit (about 30 MB is the figure
/// usually given; Apple doesn't document it, and the simulator doesn't enforce it). The
/// measurement is a proxy for that: a fresh process loads the pack and builds one day's
/// timeline, the widget's whole job, and reports what that added to the process's
/// footprint, apart from the runtime's own baseline. (Decoding the app's whole bundle
/// instead added about 37 MB on Linux, without the English: why the widget has a pack.) The day is 16 September 2026 under
/// *Dominicanus*, the costliest of the days measured (80 files of the corpus read).
enum WidgetBudget {
    static let packFileName = "breviarium-widget.pack"

    /// Memory the data may add to the widget process, in bytes, leaving the rest of
    /// the ~30 MB for WidgetKit, SwiftUI and the fonts.
    static let memoryBudget = 10_000_000
    /// Seconds for a day's timeline on the CI runner.
    static let timeBudget = 2.0

    /// Starts `--widget-budget` in a new process and passes on its exit status.
    static func run(packPath: String) -> Int32 {
        guard let executable = Bundle.main.executableURL else { return 1 }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--widget-budget", packPath]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            print("Widget budget: could not start the measurement: \(error)")
            return 1
        }
    }

    /// The measurement itself, in its own process.
    static func measure(packPath: String) -> Int32 {
        let baseline = footprint()
        let start = Date()
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: packPath), options: .alwaysMapped),
              let pack = try? PackedBundle(data: data)
        else {
            print("Widget budget: could not read \(packPath)")
            return 1
        }
        let loaded = Date()
        let timeline = WidgetOffice(pack: pack).timeline(day: 16, month: 9, year: 2026, rite: .dominicanus)
        let seconds = Date().timeIntervalSince(start)
        let added = max(0, peakFootprint() - baseline)

        print("Widget budget (a day's timeline, 16 September 2026, Dominicanus; \(timeline.count) entries):")
        print("  Pack header read in \(String(format: "%.3f", loaded.timeIntervalSince(start)))s; timeline in \(String(format: "%.3f", seconds))s in all (budget \(timeBudget)s)")
        print("  Memory added: \(String(format: "%.1f", Double(added) / 1_000_000)) MB (budget \(memoryBudget / 1_000_000) MB; \(footprintName))")
        var status: Int32 = 0
        if timeline.count != 7 {
            print("  FAILED: expected 7 entries")
            status = 1
        }
        if added > memoryBudget {
            print("  FAILED: over the memory budget")
            status = 1
        }
        if seconds > timeBudget {
            print("  FAILED: over the time budget")
            status = 1
        }
        return status
    }

    #if canImport(Darwin)
    static let footprintName = "phys_footprint, peak"

    private static func vmInfo() -> task_vm_info_data_t? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? info : nil
    }

    private static func footprint() -> Int { vmInfo().map { Int($0.phys_footprint) } ?? 0 }
    private static func peakFootprint() -> Int { vmInfo().map { Int($0.ledger_phys_footprint_peak) } ?? 0 }
    #else
    // iOS charges a process its dirty memory (`phys_footprint`), not clean file-backed
    // pages: the memory-mapped pack and the libraries' code. Linux's nearest measure is
    // the anonymous resident set; the whole resident set would count the mapped pack
    // and Foundation's code pages too (about 17 MB of the 21 measured on 14 November 2026).
    static let footprintName = "anonymous resident set (RssAnon), at the end"

    private static func status(_ field: String) -> Int {
        guard let text = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8),
              let line = text.split(separator: "\n").first(where: { $0.hasPrefix(field + ":") })
        else { return 0 }
        let kilobytes = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).dropFirst().first.flatMap { Int($0) } ?? 0
        return kilobytes * 1024
    }

    private static func footprint() -> Int { status("RssAnon") }
    // Nothing is freed before the end (each file decoded stays cached), so the end is
    // the peak.
    private static func peakFootprint() -> Int { status("RssAnon") }
    #endif
}
