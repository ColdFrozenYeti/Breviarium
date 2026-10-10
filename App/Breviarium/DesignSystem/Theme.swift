import BreviariumKit
import SwiftUI
import UIKit

/// A colour theme (1.2, `docs/1.2_plan.md` §3): the five colours of `CLAUDE.md`'s visual
/// spec, which *Nox*, the default, takes from `design/reference/Format.png`. Every view
/// reads the chosen one from the environment (`\.theme`), and `OfficeTypesetter` sets
/// the office in it.
struct Theme: Equatable {
    let background: Color
    /// Liturgical text, section headings, the day title and the separator rules.
    let liturgicalText: Color
    /// Rubrics and the date line.
    let rubric: Color
    /// The table-of-contents icon, checkmarks and the selected calendar day.
    let icon: Color
    /// Chrome text: navigation title, page footer.
    let chrome: Color
    /// A light background: the system parts (status bar, sheets, Settings) turn light too.
    let isLight: Bool

    var colorScheme: ColorScheme { isLight ? .light : .dark }
    var uiBackground: UIColor { UIColor(background) }
    var indicatorStyle: UIScrollView.IndicatorStyle { isLight ? .black : .white }

    /// The liturgical colour dots of the *Jump to date* calendar (Beta 4, decision 4):
    /// red and green as in `design/reference/Calendar.png`, violet and rose lightened to
    /// read on black; black days get a grey ring, or on a light theme a black dot
    /// (`CalendarDot`).
    func liturgical(_ color: CalendarColor) -> Color {
        switch color {
        case .white: .white
        case .red: Color(red: 1.0, green: 0.0, blue: 0.0)            // #FF0000
        case .green: Color(red: 0.0, green: 0.784, blue: 0.0)        // #00C800
        case .violet: Color(red: 0.627, green: 0.361, blue: 0.878)   // #A05CE0
        case .rose: Color(red: 0.949, green: 0.553, blue: 0.698)     // #F28DB2
        case .black: Color(red: 0.549, green: 0.549, blue: 0.549)    // #8C8C8C, a ring
        }
    }
}

/// The eight themes (`docs/1.2_plan.md` §3), shown by their Latin names; the identifiers
/// stay English (`CLAUDE.md`). Each colour has at least 4.5:1 contrast on its background.
enum ThemeChoice: String, CaseIterable, Identifiable {
    case classicDark, midnightBlue, charcoal, light, sepia, vellum, forest, rose

    var id: Self { self }

    var name: String {
        switch self {
        case .classicDark: "Nox"
        case .midnightBlue: "Media nox"
        case .charcoal: "Carbo"
        case .light: "Lux"
        case .sepia: "Sepia"
        case .vellum: "Vellum"
        case .forest: "Silva"
        case .rose: "Rosa"
        }
    }

    var theme: Theme {
        switch self {
        case .classicDark:
            // The colours as sampled since the alpha, unchanged.
            Theme(
                background: .black, liturgicalText: .white,
                rubric: Color(red: 1.0, green: 0.502, blue: 0.502),     // #FF8080
                icon: Color(red: 1.0, green: 0.302, blue: 0.200),       // #FF4D33
                chrome: Color(red: 0.698, green: 0.698, blue: 0.698),   // #B2B2B2
                isLight: false
            )
        case .midnightBlue: Theme(hex: 0x0B1530, text: 0xFFFFFF, rubric: 0x8CB8FF, icon: 0x5C9DFF, chrome: 0x98A3BC, isLight: false)
        case .charcoal: Theme(hex: 0x1C1C1E, text: 0xF2F2F2, rubric: 0xFF8A80, icon: 0xFF5A45, chrome: 0xA1A1A6, isLight: false)
        case .light: Theme(hex: 0xFFFFFF, text: 0x000000, rubric: 0xB3261E, icon: 0xC62828, chrome: 0x6B6B6B, isLight: true)
        case .sepia: Theme(hex: 0xF3E9D2, text: 0x3A2E22, rubric: 0x9E2A1E, icon: 0xA8321F, chrome: 0x6B5A45, isLight: true)
        case .vellum: Theme(hex: 0xFBF7EE, text: 0x000000, rubric: 0x8B1A1A, icon: 0xA61E1E, chrome: 0x6E675C, isLight: true)
        case .forest: Theme(hex: 0xF2F7EE, text: 0x000000, rubric: 0x1B5E20, icon: 0x1B5E20, chrome: 0x4D5E4F, isLight: true)
        case .rose: Theme(hex: 0xFCF1F5, text: 0x000000, rubric: 0x9C1352, icon: 0xB0175E, chrome: 0x6B5560, isLight: true)
        }
    }
}

extension Theme {
    /// A theme from its five sRGB colours, as `docs/1.2_plan.md` §3 lists them.
    init(hex background: UInt32, text: UInt32, rubric: UInt32, icon: UInt32, chrome: UInt32, isLight: Bool) {
        func color(_ hex: UInt32) -> Color {
            Color(
                red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255
            )
        }
        self.init(
            background: color(background), liturgicalText: color(text), rubric: color(rubric), icon: color(icon),
            chrome: color(chrome), isLight: isLight
        )
    }
}

extension EnvironmentValues {
    /// The chosen theme, set once at the root (`ContentView`); sheets inherit it.
    @Entry var theme: Theme = ThemeChoice.classicDark.theme
}

/// The text-size setting `CLAUDE.md` lists under Settings -- scales every serif size and
/// the vertical spacing proportionally; chrome text scales "more gently" per the spec.
/// `.standard` is what `design/reference/Format.png` was measured at.
enum TextSizeSetting: String, CaseIterable {
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
    /// Space below a section rule, down to the heading (measured 44.3pt in `Format.png`).
    var separatorSpacing: CGFloat { 44 * scale }
    /// Space above a section rule, from the last line of the section before it. Smaller than
    /// `separatorSpacing` because it is added below that line's own leading: measured
    /// against `Format.png`, the gap from the text above to the rule is 37pt, which 28
    /// here reproduces (44 gave 53.4pt).
    var separatorSpacingAbove: CGFloat { 28 * scale }
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

/// The same faces as `LiturgicalFont`, as `UIFont`s for `OfficeTypesetter`'s TextKit
/// rendering. Falls back to the system font only if Hoefler Text is ever missing.
enum LiturgicalUIFont {
    static func regular(_ size: CGFloat) -> UIFont { font(LiturgicalFont.regularName, size) }
    static func italic(_ size: CGFloat) -> UIFont { font(LiturgicalFont.italicName, size) }
    static func black(_ size: CGFloat) -> UIFont { font(LiturgicalFont.blackName, size) }
    static func blackItalic(_ size: CGFloat) -> UIFont { font(LiturgicalFont.blackItalicName, size) }

    private static func font(_ name: String, _ size: CGFloat) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }
}
