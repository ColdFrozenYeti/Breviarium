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
/// which glyph to draw is a presentation choice, not liturgical content. A leading or
/// trailing "‡" (the antiphon/psalm-verse dagger rule -- see
/// `HourAssembler.assemblePsalmodia`'s own doc comment) renders in the rubric colour
/// while the rest of the line stays normal, via `Text` concatenation rather than a
/// separate view, so it stays inline with the surrounding text. Parallel English
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
    /// segment, concatenated with the rest of the line so it stays inline (`Text + Text`
    /// preserves each segment's own styling) -- the rest of the modifiers (line spacing,
    /// frame) apply to the combined result afterward in `latinText`.
    private func styledText(_ text: String, font: Font, color: Color) -> Text {
        if text.hasPrefix("‡ ") {
            let rest = String(text.dropFirst(2))
            return Text("‡ ").font(font).foregroundStyle(Theme.rubric) + Text(rest).font(font).foregroundStyle(color)
        }
        if text.hasSuffix(" ‡") {
            let rest = String(text.dropLast(2))
            return Text(rest).font(font).foregroundStyle(color) + Text(" ‡").font(font).foregroundStyle(Theme.rubric)
        }
        return Text(text).font(font).foregroundStyle(color)
    }

    private static func substitutingCrossGlyph(_ text: String) -> String {
        text.replacingOccurrences(of: "+", with: "✠")
    }
}
