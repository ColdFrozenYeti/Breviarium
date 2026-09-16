import Foundation
import BreviariumDataCore

let arguments = CommandLine.arguments

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
    print("  Calendar entries: \(bundle.calendar.count)")
    print("  Uncompressed JSON size: \(sizeInBytes) bytes (\(String(format: "%.2f", sizeInMB)) MB)")
    print("  JSONDecoder round-trip: \(String(format: "%.3f", decodeSeconds))s")
    print("    (measured on this CI runner's CPU, not an iOS device -- a rough proxy, not a real cold-load number)")
} catch {
    print("BreviariumData failed: \(error)")
    exit(1)
}
