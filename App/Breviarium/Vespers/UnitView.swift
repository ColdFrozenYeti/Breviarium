import BreviariumKit
import SwiftUI

/// Renders one `BreviariumKit.Unit` per `CLAUDE.md`'s visual spec (§ "Body"):
/// versicle/response pairs indent and italicise the response; psalm-verse second halves
/// indent; rubrics are red italic and hidden when the rubrics toggle is off. Parallel
/// English (side-by-side verse, stacked prose) isn't wired up yet -- `unit`'s own
/// `english` fields are simply not read here; every unit renders Latin-only for now.
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
                    latinText(secondHalf, font: LiturgicalFont.regular(metrics.bodySize), color: Theme.liturgicalText)
                        .padding(.leading, metrics.versicleIndent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .antiphon(let text, _), .prose(let text, _):
            latinText(text, font: LiturgicalFont.regular(metrics.bodySize), color: Theme.liturgicalText)
        }
    }

    private func latinText(_ text: String, font: Font, color: Color) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(metrics.extraLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
