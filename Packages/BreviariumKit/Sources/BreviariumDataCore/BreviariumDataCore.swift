import BreviariumKit

/// Entry point for the build-time data pipeline: reads the pinned Divinum Officium
/// checkout, resolves static conditionals, normalises orthography, and emits the
/// bundled data file the app ships. Real parsing logic lands in M2.
public enum BreviariumDataPipeline {
    public static func placeholderVersion() -> Int {
        breviariumKitDataFormatVersion
    }
}
