import SwiftUI
import TextMorph

private let results = [(24, 1208), (24, 986), (12, 986), (12, 47)]

/// A number inside a sentence.
struct ResultsSummaryDemo: View {
    @Environment(ShowcaseSettings.self) private var settings

    var body: some View {
        Cycling(count: results.count, interval: 2) { index in
            let (shown, total) = results[index]
            Stage {
                TextMorph(
                    "Showing \(shown) of \(grouped(total)) results",
                    options: settings.options(ease: ShowcaseSettings.upstreamSpring)
                )
                .textMorphFont(stageFont(size: 20))
            }
        }
    }

    @MainActor static var entry: Demo {
        Demo(
            id: "results",
            name: "Results summary",
            summary: "Two numbers buried in a sentence. The words hold completely still while "
                + "the counts roll, which is the case that makes the word path worth having: a "
                + "cross-fade here would flicker the whole line to change two digits.",
            capability: "quantities inside prose",
            code: """
            TextMorph("Showing \\(shown) of \\(total) results")
            """
        ) { ResultsSummaryDemo() }
    }
}
