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

    print("Wrote \(outputPath.path)")
    print("")
    print("Bundle report:")
    print("  Latin files:      \(bundle.latin.count)")
    print("  Latin-Bea files:  \(bundle.latinBea.count)")
    print("  Calendar entries: \(bundle.calendar.count)")
    print("  Uncompressed JSON size: \(sizeInBytes) bytes (\(String(format: "%.2f", sizeInMB)) MB)")
} catch {
    print("BreviariumData failed: \(error)")
    exit(1)
}
