import SwiftUI

/// Colours from `CLAUDE.md`'s visual spec, sampled from `design/reference/Format.png`.
/// Night mode only -- there is no light theme.
enum Theme {
    static let background = Color.black
    static let liturgicalText = Color.white
    /// Rubrics and the date line.
    static let rubric = Color(red: 1.0, green: 0.502, blue: 0.502)      // #FF8080
    /// The table-of-contents icon.
    static let icon = Color(red: 1.0, green: 0.302, blue: 0.200)        // #FF4D33
    /// Chrome text: navigation title, page footer.
    static let chrome = Color(red: 0.698, green: 0.698, blue: 0.698)    // #B2B2B2
}

/// The text-size setting `CLAUDE.md` lists under Settings -- scales every serif size and
/// the vertical spacing proportionally; chrome text scales "more gently" per the spec.
/// `.standard` is what `design/reference/Format.png` was measured at.
enum TextSizeSetting: CaseIterable {
    case small, standard, large, extraLarge, largest

    var serifScale: CGFloat {
        switch self {
        case .small: 0.85
        case .standard: 1.0
        case .large: 1.15
        case .extraLarge: 1.3
        case .largest: 1.5
        }
    }

    /// Chrome scales at 40% of the serif delta -- noticeably gentler, never shrinking
    /// below what `.small` still needs to stay legible.
    var chromeScale: CGFloat {
        1.0 + (serifScale - 1.0) * 0.4
    }
}

/// Point measurements from `CLAUDE.md`'s visual spec (§ "Page structure"), scaled by the
/// active `TextSizeSetting`.
struct Metrics {
    var scale: CGFloat = TextSizeSetting.standard.serifScale
    var chromeScale: CGFloat = TextSizeSetting.standard.chromeScale

    var bodySize: CGFloat { 19 * scale }
    /// `CLAUDE.md` gives body text a ~23pt line pitch against a ~19pt body size -- the
    /// ~4pt difference, scaled, is what `.lineSpacing` (extra space *between* lines, on
    /// top of the font's own leading) should add.
    var extraLineSpacing: CGFloat { 4 * scale }
    var margin: CGFloat { 28 * scale }
    var versicleIndent: CGFloat { 23 * scale }
    var hangingIndent: CGFloat { 38 * scale }
    var separatorWidth: CGFloat { 83 * scale }
    var separatorSpacing: CGFloat { 44 * scale }
    var hourTitleSize: CGFloat { bodySize * 1.5 }
    var dayTitleNameSize: CGFloat { bodySize * 1.3 }
    var sectionHeadingSize: CGFloat { bodySize * 1.1 }
    /// "Noticeably larger than body text" (`CLAUDE.md`) -- no exact ratio given; this is
    /// a first estimate (matching the day title name's own 1.3x) to refine once a real
    /// snapshot can be measured against `design/reference/Format.png`.
    var dateLineSize: CGFloat { bodySize * 1.3 }
    var navTitleSize: CGFloat { 13 * chromeScale }
    var footerSize: CGFloat { 12 * chromeScale }
}

/// Hoefler Text ships with iOS, so no bundled font is needed -- `CLAUDE.md`'s visual
/// spec names it as the liturgical serif, to be confirmed by rendering next to the
/// reference screenshot.
enum LiturgicalFont {
    static let regularName = "HoeflerText-Regular"
    static let italicName = "HoeflerText-Italic"
    static let blackName = "HoeflerText-Black"
    static let blackItalicName = "HoeflerText-BlackItalic"

    static func regular(_ size: CGFloat) -> Font { .custom(regularName, size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom(italicName, size: size) }
    static func black(_ size: CGFloat) -> Font { .custom(blackName, size: size) }
    /// Antiphons -- bold italic, per direct feedback comparing a real rendering.
    static func blackItalic(_ size: CGFloat) -> Font { .custom(blackItalicName, size: size) }
}
