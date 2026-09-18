import BreviariumKit
import SwiftUI

/// Renders one `BreviariumKit.Unit` per `CLAUDE.md`'s visual spec (§ "Body"):
/// versicle/response pairs indent and italicise the response; psalm-verse second halves
/// indent and italicise too (confirmed against a real rendering: the doxology's own
/// "Sicut erat..." response half reads the same way); rubrics are red italic and hidden
/// when the rubrics toggle is off. `+`, DO's own source-text placeholder for the
/// sign-of-the-cross gesture (e.g. "Deus + in adiutórium", the Magnificat's own
/// "Magníficat * + ánima mea Dóminum" -- confirmed present in the real Bea psalter
/// file), is substituted with the real ✠ glyph here rather than in BreviariumKit's own
/// (deliberately raw) text data, since which glyph to draw is a presentation choice, not
/// liturgical content. Parallel English (side-by-side verse, stacked prose) isn't wired
/// up yet -- `unit`'s own `english` fields are simply not read here; every unit renders
/// Latin-only for now.
struct UnitView: View {
    let unit: BreviariumKit.Unit
    let metrics: Metrics
    var showRubrics: Bool = true

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
            VStack(alignment: .leading, spacing: 0) {
                latinText(firstHalf, font: LiturgicalFont.regular(metrics.bodySize), color: Theme.liturgicalText)
                if !secondHalf.isEmpty {
                    latinText(secondHalf, font: LiturgicalFont.italic(metrics.bodySize), color: Theme.liturgicalText)
                        .padding(.leading, metrics.versicleIndent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .antiphon(let text, _), .prose(let text, _):
            latinText(text, font: LiturgicalFont.regular(metrics.bodySize), color: Theme.liturgicalText)
        }
    }

    private func latinText(_ text: String, font: Font, color: Color) -> some View {
        Text(Self.substitutingCrossGlyph(text))
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(metrics.extraLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func substitutingCrossGlyph(_ text: String) -> String {
        text.replacingOccurrences(of: "+", with: "✠")
    }
}
