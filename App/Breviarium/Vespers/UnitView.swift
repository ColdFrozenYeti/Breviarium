import BreviariumKit
import SwiftUI

/// Renders one `BreviariumKit.Unit` per `CLAUDE.md`'s visual spec (§ "Body"):
/// versicle/response pairs indent and italicise the response; psalm verses alternate
/// whole-verse italic, "as if said by one person and then another" (direct feedback --
/// see `ContentBlock.alternateVerse`'s own doc comment for the confirmed odd/even
/// verse-number pairing); rubrics are red italic and hidden when the rubrics toggle is
/// off. `+`, DO's own source-text placeholder for the sign-of-the-cross gesture (e.g.
/// "Deus + in adiutórium", the Magnificat's own "Magníficat * + ánima mea Dóminum" --
/// confirmed present in the real Bea psalter file), is substituted with the real ✠
/// glyph here rather than in BreviariumKit's own (deliberately raw) text data, since
/// which glyph to draw is a presentation choice, not liturgical content. The ✠ itself
/// renders in the rubric colour (it's a rubric gesture, not liturgical text), and so does
/// a leading or trailing "‡" (the antiphon/psalm-verse dagger rule -- see
/// `HourAssembler.assemblePsalmodia`'s own doc comment), while the rest of the line stays
/// normal -- both via `Text` concatenation rather than a separate view, so they stay
/// inline with the surrounding text (see `styledText`/`crossColoredText`). Parallel English
/// (side-by-side verse, stacked prose) isn't wired up yet -- `unit`'s own `english`
/// fields are simply not read here; every unit renders Latin-only for now.
struct UnitView: View {
    let unit: BreviariumKit.Unit
    let metrics: Metrics
    var showRubrics: Bool = true
    var italicizeWholeVerse: Bool = false

    var body: some View {
        switch unit {
        case .rubric(let text, _):
            if showRubrics {
                latinText(text, font: LiturgicalFont.italic(metrics.bodySize), color: Theme.rubric)
            }
        case .versicleResponse(let versicle, let response, _, _):
            VStack(alignment: .leading, spacing: 0) {
                latinText(versicle, font: LiturgicalFont.regular(metrics.bodySize), color: Theme.liturgicalText)
                latinText(response, font: LiturgicalFont.italic(metrics.bodySize), color: Theme.liturgicalText)
                    .padding(.leading, metrics.versicleIndent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .verse(_, let firstHalf, let secondHalf, _, _):
            let font = italicizeWholeVerse ? LiturgicalFont.italic(metrics.bodySize) : LiturgicalFont.regular(metrics.bodySize)
            VStack(alignment: .leading, spacing: 0) {
                latinText(firstHalf, font: font, color: Theme.liturgicalText)
                if !secondHalf.isEmpty {
                    latinText(secondHalf, font: font, color: Theme.liturgicalText)
                        .padding(.leading, metrics.versicleIndent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .antiphon(let text, _):
            latinText(text, font: LiturgicalFont.blackItalic(metrics.bodySize), color: Theme.liturgicalText)
                // Extra separation so the antiphon doesn't read as part of the psalm
                // that follows -- direct feedback comparing a real rendering.
                .padding(.bottom, metrics.bodySize * 0.5)
        case .prose(let text, _):
            latinText(text, font: LiturgicalFont.regular(metrics.bodySize), color: Theme.liturgicalText)
        case .psalmTitle(let text):
            latinText(text, font: LiturgicalFont.italic(metrics.bodySize), color: Theme.chrome)
                .padding(.bottom, metrics.bodySize * 0.3)
        }
    }

    private func latinText(_ text: String, font: Font, color: Color) -> some View {
        styledText(Self.substitutingCrossGlyph(text), font: font, color: color)
            .lineSpacing(metrics.extraLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Splits off a leading or trailing "‡ "/" ‡" into its own red-coloured `Text`
    /// segment, then hands the remainder to `crossColoredText` for the sign-of-the-cross
    /// glyph -- `Text + Text` preserves each segment's own styling, so both markers stay
    /// inline with the surrounding text. The rest of the modifiers (line spacing, frame)
    /// apply to the combined result afterward in `latinText`.
    private func styledText(_ text: String, font: Font, color: Color) -> Text {
        var rest = text
        var leadingDagger = false
        var trailingDagger = false
        if rest.hasPrefix("‡ ") {
            leadingDagger = true
            rest = String(rest.dropFirst(2))
        }
        if rest.hasSuffix(" ‡") {
            trailingDagger = true
            rest = String(rest.dropLast(2))
        }

        var result = Text("")
        if leadingDagger {
            result = result + Text("‡ ").font(font).foregroundStyle(Theme.rubric)
        }
        result = result + crossColoredText(rest, font: font, color: color)
        if trailingDagger {
            result = result + Text(" ‡").font(font).foregroundStyle(Theme.rubric)
        }
        return result
    }

    /// Colours every "✠" (the sign-of-the-cross gesture marker) in the rubric colour
    /// while the rest of the text keeps its normal colour -- it's technically a rubric,
    /// per direct feedback, even though it sits inline within otherwise-normal text
    /// (e.g. "Deus ✠ in adiutórium meum inténde.") rather than only leading or trailing a
    /// whole line the way the dagger does, so this splits on every occurrence rather than
    /// just checking the ends.
    private func crossColoredText(_ text: String, font: Font, color: Color) -> Text {
        let parts = text.components(separatedBy: "✠")
        guard parts.count > 1 else {
            return Text(text).font(font).foregroundStyle(color)
        }
        var result = Text(parts[0]).font(font).foregroundStyle(color)
        for part in parts.dropFirst() {
            result = result + Text("✠").font(font).foregroundStyle(Theme.rubric)
            result = result + Text(part).font(font).foregroundStyle(color)
        }
        return result
    }

    private static func substitutingCrossGlyph(_ text: String) -> String {
        text.replacingOccurrences(of: "+", with: "✠")
    }
}
