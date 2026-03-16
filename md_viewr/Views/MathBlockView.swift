import SwiftUI
import SwiftMath

/// Renders a LaTeX math expression using SwiftMath (Core Graphics, no JS).
struct MathBlockView: NSViewRepresentable {
    let latex: String

    func makeNSView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.latex = latex
        label.labelMode = .display
        label.textAlignment = .center
        label.fontSize = 18
        return label
    }

    func updateNSView(_ label: MTMathUILabel, context: Context) {
        label.latex = latex
    }
}
