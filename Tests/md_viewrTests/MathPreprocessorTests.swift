// md_viewr — Native macOS markdown viewer
// Copyright (C) 2026 Everett Kropf
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import XCTest
@testable import md_viewr

final class MathPreprocessorTests: XCTestCase {
    func testBasicBlockMath() {
        let input = "$$\nx^2 + y^2 = z^2\n$$"
        let expected = "```math\nx^2 + y^2 = z^2\n```"
        XCTAssertEqual(preprocessBlockMath(input), expected)
    }

    func testMultipleMathBlocks() {
        let input = "Text\n\n$$\na + b\n$$\n\nMore text\n\n$$\nc + d\n$$"
        let expected = "Text\n\n```math\na + b\n```\n\nMore text\n\n```math\nc + d\n```"
        XCTAssertEqual(preprocessBlockMath(input), expected)
    }

    func testDollarSignsInsideFencedCodeBlock() {
        let input = "```python\nprint(\"$$\")\n$$\nsome text\n$$\n```"
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testDollarSignsInsideTildeFencedBlock() {
        let input = "~~~\n$$\nsome math\n$$\n~~~"
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testExistingFencedMathUnchanged() {
        let input = "```math\nx^2\n```"
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testExistingFencedLatexUnchanged() {
        let input = "```latex\n\\frac{1}{2}\n```"
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testUnclosedMathBlockAutoCloses() {
        let input = "$$\nx^2 + y^2"
        let expected = "```math\nx^2 + y^2\n```"
        XCTAssertEqual(preprocessBlockMath(input), expected)
    }

    func testWhitespaceAroundDollarSigns() {
        let input = "  $$  \nx^2\n  $$  "
        let expected = "```math\nx^2\n```"
        XCTAssertEqual(preprocessBlockMath(input), expected)
    }

    func testEmptyMathBlock() {
        let input = "$$\n$$"
        let expected = "```math\n```"
        XCTAssertEqual(preprocessBlockMath(input), expected)
    }

    func testInlineDollarSignsNotConverted() {
        let input = "The price is $5 and $$10 total."
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testMixedContent() {
        let input = """
            # Heading

            Some paragraph text.

            $$
            E = mc^2
            $$

            ```python
            x = 42
            $$
            not math
            $$
            ```

            ```math
            \\alpha + \\beta
            ```

            More text.
            """
        let expected = """
            # Heading

            Some paragraph text.

            ```math
            E = mc^2
            ```

            ```python
            x = 42
            $$
            not math
            $$
            ```

            ```math
            \\alpha + \\beta
            ```

            More text.
            """
        XCTAssertEqual(preprocessBlockMath(input), expected)
    }

    func testNoMathBlocksPassesThrough() {
        let input = "# Hello\n\nJust regular markdown.\n\n```swift\nlet x = 1\n```"
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testMultilineMathContent() {
        let input = "$$\n\\begin{align}\na &= b \\\\\nc &= d\n\\end{align}\n$$"
        let expected = "```math\n\\begin{align}\na &= b \\\\\nc &= d\n\\end{align}\n```"
        XCTAssertEqual(preprocessBlockMath(input), expected)
    }

    func testSingleLineDollarSignContentNotConverted() {
        let input = "$$ x^2 $$"
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testFourBacktickFenceProtectsDollarSigns() {
        let input = "````\n$$\nstuff\n$$\n````"
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testUnclosedFencedCodeBlockProtectsDollarSigns() {
        let input = "```python\nprint('hello')\n$$\nx^2\n$$"
        XCTAssertEqual(preprocessBlockMath(input), input)
    }

    func testEmptyInput() {
        XCTAssertEqual(preprocessBlockMath(""), "")
    }
}
