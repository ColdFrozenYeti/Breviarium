import Foundation
import BreviariumKit
import BreviariumDataCore

let arguments = CommandLine.arguments

// `BreviariumData --widget-budget <pack>`: what the widget (1.5) spends loading its data
// file and building a day's timeline, measured in a process of its own (see
// `WidgetBudget.swift`). The normal run below starts it on the pack it has just written.
if arguments.count == 3, arguments[1] == "--widget-budget" {
    exit(WidgetBudget.measure(packPath: arguments[2]))
}

guard arguments.count == 3 else {
    print("Usage: BreviariumData <divinum-officium-checkout-root> <output-bundle.json>")
    exit(1)
}

let checkoutRoot = URL(fileURLWithPath: arguments[1])
let outputPath = URL(fileURLWithPath: arguments[2])

do {
    print("Walking \(checkoutRoot.path) ...")
    let bundle = try BreviariumDataPipeline.build(checkoutRoot: checkoutRoot)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(bundle)

    try data.write(to: outputPath)

    let sizeInBytes = data.count
    let sizeInMB = Double(sizeInBytes) / 1_000_000

    let decoder = JSONDecoder()
    let decodeStart = Date()
    _ = try decoder.decode(DataBundle.self, from: data)
    let decodeSeconds = Date().timeIntervalSince(decodeStart)

    print("Wrote \(outputPath.path)")
    print("")
    print("Bundle report:")
    print("  Latin files:      \(bundle.latin.count)")
    print("  Latin-Bea files:  \(bundle.latinBea.count)")
    print("  English files:    \(bundle.english.count)")
    print("  Calendar entries: \(bundle.calendar.count)")
    print("  Transfer tables:  \(bundle.transferTable.count)")
    print("  Uncompressed JSON size: \(sizeInBytes) bytes (\(String(format: "%.2f", sizeInMB)) MB)")
    print("  JSONDecoder round-trip: \(String(format: "%.3f", decodeSeconds))s")
    print("    (measured on this CI runner's CPU, not an iOS device -- a rough proxy, not a real cold-load number)")

    // The widget's data file (1.5), next to the app's: the same bundle without the
    // English, packed so each file of the corpus is decoded only when it is read
    // (`PackedBundle`). The widget reads it from the app's bundle.
    let packPath = outputPath.deletingLastPathComponent().appendingPathComponent(WidgetBudget.packFileName)
    let pack = try PackedBundle.pack(bundle)
    try pack.write(to: packPath)
    print("")
    print("Widget pack: \(packPath.path)")
    print("  Size: \(pack.count) bytes (\(String(format: "%.2f", Double(pack.count) / 1_000_000)) MB)")
    // Flushed first, so the log reads in order when stdout is a file or a pipe (CI).
    fflush(nil) // every stream: naming `stdout` is a Swift 6 concurrency error
    let status = WidgetBudget.run(packPath: packPath.path)
    if status != 0 { exit(status) }
} catch {
    print("BreviariumData failed: \(error)")
    exit(1)
}
