import BreviariumKit
import SwiftUI
import UIKit

// The widgets' faces (1.5, `docs/1.5_plan.md`), compiled into both the widget extension
// and the app, whose debug-only gallery draws them for the UI tests' snapshots. No
// liturgy here: every word comes from `WidgetDay`, which the Kit builds.

/// The seven widget faces: the day (small, medium), the hour (medium, large) and the
/// Lock Screen's three.
enum WidgetLayout: String, CaseIterable, Sendable {
    case daySmall, dayMedium, hourMedium, hourLarge, lockRectangular, lockInline, lockCircular

    var isLockScreen: Bool { self == .lockRectangular || self == .lockInline || self == .lockCircular }
}

/// How the system draws the widget: in its own colours, or tinted (the Home Screen's
/// tinted and clear looks, and the Lock Screen), where the system recolours everything
/// and only the shapes and the white levels survive.
enum WidgetLook: Sendable {
    case fullColor, tinted
}

/// The line limits (`docs/1.5_plan.md` §3, decided 2026-11-14): a text keeps its size and
/// past its limit ends with an ellipsis; nothing is shrunk to fit.
enum WidgetLines {
    static let daySmallName = 4
    static let dayMediumName = 2
    static let dayMediumCommemoration = 2
    static let hourMediumText = 5
    static let hourLargeText = 10
    static let lockRectangularName = 1
}

/// One widget's content, without its background: the widget sets that as its container
/// background, the gallery as the tile's.
struct WidgetFace: View {
    let day: WidgetDay?
    let layout: WidgetLayout
    let theme: Theme
    let font: FontChoice
    let look: WidgetLook

    private var fonts: LiturgicalUIFont { LiturgicalUIFont(choice: font) }
    private var text: Color { look == .fullColor ? theme.liturgicalText : .white }
    private var rubric: Color { look == .fullColor ? theme.rubric : .white.opacity(0.75) }
    private var chrome: Color { look == .fullColor ? theme.chrome : .white.opacity(0.6) }

    var body: some View {
        if let day {
            switch layout {
            case .daySmall: daySmall(day)
            case .dayMedium: dayMedium(day)
            case .hourMedium: hourMedium(day)
            case .hourLarge: hourLarge(day)
            case .lockRectangular: lockRectangular(day)
            // The system sets the inline face in its own font and tint.
            case .lockInline: Text(day.hourTitle).foregroundStyle(text)
            case .lockCircular: lockCircular(day)
            }
        } else {
            // The data failed to load: an empty face, never an explanation (`CLAUDE.md`).
            Color.clear
        }
    }

    // MARK: The faces

    private func daySmall(_ day: WidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            classLine(day)
            nameLine(day, size: 17)
                .lineLimit(WidgetLines.daySmallName)
            Spacer(minLength: 0)
            serif(day.hourTitle, size: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func dayMedium(_ day: WidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                classLine(day)
                Spacer(minLength: 8)
                dateLine(day, size: 14)
            }
            nameLine(day, size: 18)
                .lineLimit(WidgetLines.dayMediumName)
            if let commemoration = day.titleBlock.commemorationLine {
                serif(commemoration, size: 13)
                    .lineLimit(WidgetLines.dayMediumCommemoration)
            }
            Spacer(minLength: 0)
            serif(day.hourTitle, size: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func hourMedium(_ day: WidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                serif(day.hourTitle, size: 18)
                Spacer(minLength: 8)
                dot(day.color, size: 9)
            }
            hourText(day, size: 15)
                .lineLimit(WidgetLines.hourMediumText)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func hourLarge(_ day: WidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Spacer(minLength: 0)
                dateLine(day, size: 15)
            }
            classLine(day)
            nameLine(day, size: 18)
                .lineLimit(2)
            // The section rule of the page (`CLAUDE.md`, item 7), at a widget's scale.
            Rectangle()
                .fill(text)
                .frame(width: 60, height: 1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            serif(day.hourTitle, size: 22)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            hourText(day, size: 16)
                .lineLimit(WidgetLines.hourLargeText)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func lockRectangular(_ day: WidgetDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            serif(day.hourTitle, size: 15, face: .black)
            serif(day.titleBlock.nameLine, size: 14)
                .lineLimit(WidgetLines.lockRectangularName)
            if let classis = day.titleBlock.classisLine { serif(classis, size: 13) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lockCircular(_ day: WidgetDay) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.15))
            Circle().strokeBorder(Color.white, lineWidth: 2.5)
            serif(Self.initial(of: day.hourTitle), size: 26, face: .black)
        }
    }

    /// The hour's initial for the circular face: *V* for *Ad Vesperas*.
    static func initial(of hourTitle: String) -> String {
        let word = hourTitle.hasPrefix("Ad ") ? hourTitle.dropFirst(3) : Substring(hourTitle)
        return word.first.map(String.init) ?? ""
    }

    // MARK: Pieces

    /// The colour dot and the class (*III. classis*); a day without a class line (the
    /// Ambrosian days, the ferias) has its dot beside its name instead (`nameLine`).
    @ViewBuilder
    private func classLine(_ day: WidgetDay) -> some View {
        if let classis = day.titleBlock.classisLine {
            HStack(spacing: 6) {
                dot(day.color, size: 9)
                serif(classis, size: 13)
            }
        }
    }

    /// The day's name, in the title's black weight, after the dot when there's no class line.
    @ViewBuilder
    private func nameLine(_ day: WidgetDay, size: CGFloat) -> some View {
        if day.titleBlock.classisLine == nil {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                dot(day.color, size: 9)
                serif(day.titleBlock.nameLine, size: size, face: .black)
            }
        } else {
            serif(day.titleBlock.nameLine, size: size, face: .black)
        }
    }

    /// The antiphon, in the page's antiphon face (bold italic), or, when the hour has
    /// none, the day's title, in the title's face (decided 2026-11-14).
    private func hourText(_ day: WidgetDay, size: CGFloat) -> Text {
        if day.hourTextIsAntiphon {
            return Text(styled(day.hourText, font: fonts.blackItalic(size)))
        }
        return Text(styled(day.hourText, font: fonts.black(size)))
    }

    private func serif(_ string: String, size: CGFloat, face: LiturgicalUIFont.Face = .regular) -> Text {
        let uiFont: UIFont = switch face {
        case .regular: fonts.regular(size)
        case .italic: fonts.italic(size)
        case .black: fonts.black(size)
        case .blackItalic: fonts.blackItalic(size)
        }
        return Text(styled(string, font: uiFont))
    }

    /// The date line, as on page 1: SF italic, in the rubric colour.
    private func dateLine(_ day: WidgetDay, size: CGFloat) -> some View {
        Text(day.dateLine)
            .font(.system(size: size).italic())
            .foregroundStyle(rubric)
            .lineLimit(1)
    }

    /// The day's liturgical colour, as the Kalendarium's dots draw it; a ring when tinted,
    /// where a colour would be lost, and for white on a light theme, where it would vanish.
    @ViewBuilder
    private func dot(_ color: CalendarColor?, size: CGFloat) -> some View {
        if let color {
            if look == .tinted || color == .black || (color == .white && theme.isLight) {
                let ring = look == .tinted || color == .white ? text : theme.liturgical(color)
                Circle().strokeBorder(ring, lineWidth: 1.5).frame(width: size, height: size)
            } else {
                Circle().fill(theme.liturgical(color)).frame(width: size, height: size)
            }
        }
    }

    /// Liturgical text as the page sets it: the Kit's inline rubrics, and `+` as a red ✠,
    /// in the rubric colour; spelt for the face (`FontChoice.spelled`).
    private func styled(_ raw: String, font uiFont: UIFont) -> AttributedString {
        var result = AttributedString()
        var run = ""
        var inRubric = false
        func flush() {
            guard !run.isEmpty else { return }
            for (index, piece) in run.split(separator: "+", omittingEmptySubsequences: false).enumerated() {
                if index > 0 { result.append(attributed("✠", uiFont, rubric)) }
                if !piece.isEmpty { result.append(attributed(String(piece), uiFont, inRubric ? rubric : text)) }
            }
            run = ""
        }
        for character in font.spelled(raw) {
            if character == InlineRubrics.start {
                flush()
                inRubric = true
            } else if character == InlineRubrics.end {
                flush()
                inRubric = false
            } else {
                run.append(character)
            }
        }
        flush()
        return result
    }

    private func attributed(_ string: String, _ uiFont: UIFont, _ color: Color) -> AttributedString {
        var piece = AttributedString(string)
        // SwiftUI's own attributes, named by key: `.font` and `.foregroundColor` alone are
        // ambiguous with UIKit's when both are imported.
        piece[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = Font(uiFont as CTFont)
        piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = color
        return piece
    }
}

/// The widget's data and the app's link (1.5).
enum WidgetData {
    static let packName = "breviarium-widget"

    /// The office from the pack in a bundle directory (the app's own, which the
    /// extension reads from inside it), memory-mapped (`PackedBundle`).
    static func office(inBundleAt bundleURL: URL) -> WidgetOffice? {
        let url = bundleURL.appendingPathComponent("\(packName).pack")
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped), let pack = try? PackedBundle(data: data) else { return nil }
        return WidgetOffice(pack: pack)
    }

    /// `breviarium://open?hour=Vespera&date=2026-11-14`: a tap on a widget opens that hour
    /// and date (decided 2026-11-14).
    static func link(for day: WidgetDay) -> URL? {
        var components = URLComponents()
        components.scheme = "breviarium"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "hour", value: day.hour.doName),
            URLQueryItem(name: "date", value: String(format: "%04d-%02d-%02d", day.year, day.month, day.day)),
        ]
        return components.url
    }

    /// The hour and date a link names, for the app's `onOpenURL`.
    static func parse(_ url: URL) -> (hour: CanonicalHour, day: Int, month: Int, year: Int)? {
        guard url.scheme == "breviarium", url.host == "open",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let hour = items.first(where: { $0.name == "hour" })?.value.flatMap(CanonicalHour.init(rawValue:)),
              let date = items.first(where: { $0.name == "date" })?.value
        else { return nil }
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1 ... 12).contains(parts[1]), (1 ... 31).contains(parts[2]) else { return nil }
        return (hour, parts[2], parts[1], parts[0])
    }
}
