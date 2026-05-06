// Pellucid — Native macOS markdown viewer
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
@testable import Pellucid

final class BlockAttachmentTests: XCTestCase {

    // MARK: - ImageAttachment.scaledSize

    func testScaledSize_narrowerThanMax_returnsOriginal() {
        let original = CGSize(width: 400, height: 300)
        let result = ImageAttachment.scaledSize(for: original, maxWidth: 860)
        XCTAssertEqual(result.width, 400, accuracy: 0.01)
        XCTAssertEqual(result.height, 300, accuracy: 0.01)
    }

    func testScaledSize_widerThanMax_scalesDown() {
        let original = CGSize(width: 1720, height: 860)
        let result = ImageAttachment.scaledSize(for: original, maxWidth: 860)
        XCTAssertEqual(result.width, 860, accuracy: 0.01)
        XCTAssertEqual(result.height, 430, accuracy: 0.01)
    }

    func testScaledSize_exactlyMaxWidth_returnsOriginal() {
        let original = CGSize(width: 860, height: 500)
        let result = ImageAttachment.scaledSize(for: original, maxWidth: 860)
        XCTAssertEqual(result.width, 860, accuracy: 0.01)
        XCTAssertEqual(result.height, 500, accuracy: 0.01)
    }

    func testScaledSize_zeroWidth_returnsOriginal() {
        let original = CGSize(width: 0, height: 100)
        let result = ImageAttachment.scaledSize(for: original, maxWidth: 860)
        XCTAssertEqual(result.width, 0, accuracy: 0.01)
        XCTAssertEqual(result.height, 100, accuracy: 0.01)
    }

    // MARK: - ImageAttachment from NSImage

    func testImageAttachment_fromNSImage_setsImage() {
        let testImage = NSImage(size: CGSize(width: 200, height: 100))
        let attachment = ImageAttachment(nsImage: testImage, maxWidth: 860)

        XCTAssertNotNil(attachment.attachmentImage)
        XCTAssertNil(attachment.sourceURL)
        XCTAssertNil(attachment.sourceMarkdown)
    }

    func testImageAttachment_fromNSImage_scalesDown() {
        let testImage = NSImage(size: CGSize(width: 1720, height: 860))
        let attachment = ImageAttachment(nsImage: testImage, maxWidth: 860)

        XCTAssertNotNil(attachment.attachmentImage)
        XCTAssertEqual(attachment.bounds.width, 860, accuracy: 0.01)
        XCTAssertEqual(attachment.bounds.height, 430, accuracy: 0.01)
    }

    func testImageAttachment_storesSourceURL() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let testImage = NSImage(size: CGSize(width: 100, height: 100))
        let attachment = ImageAttachment(
            nsImage: testImage,
            sourceURL: url,
            sourceMarkdown: "![test](/tmp/test.png)"
        )

        XCTAssertEqual(attachment.sourceURL, url)
        XCTAssertEqual(attachment.sourceMarkdown, "![test](/tmp/test.png)")
    }

    // MARK: - DiagramAttachment

    func testDiagramAttachment_storesPlantUMLSource() {
        let source = "@startuml\nA -> B\n@enduml"
        let testImage = NSImage(size: CGSize(width: 300, height: 200))
        let attachment = DiagramAttachment(
            renderedImage: testImage,
            plantUMLSource: source,
            isDarkMode: false
        )

        XCTAssertEqual(attachment.plantUMLSource, source)
        XCTAssertEqual(attachment.sourceMarkdown, "```plantuml\n\(source)\n```")
    }

    func testDiagramAttachment_lightMode_noPadding() {
        let testImage = NSImage(size: CGSize(width: 300, height: 200))
        let attachment = DiagramAttachment(
            renderedImage: testImage,
            plantUMLSource: "@startuml\nA -> B\n@enduml",
            isDarkMode: false,
            maxWidth: 860
        )

        // Diagrams scale to fill maxWidth (SVG content is resolution-independent).
        // 300x200 scaled to 860 width: height = 200 * (860/300) = 573.33
        XCTAssertEqual(attachment.bounds.width, 860, accuracy: 0.01)
        XCTAssertEqual(attachment.bounds.height, 573.33, accuracy: 0.01)
    }

    func testDiagramAttachment_darkMode_addsPadding() {
        let testImage = NSImage(size: CGSize(width: 300, height: 200))
        let attachment = DiagramAttachment(
            renderedImage: testImage,
            plantUMLSource: "@startuml\nA -> B\n@enduml",
            isDarkMode: true,
            maxWidth: 860
        )

        // Diagrams scale to fill maxWidth, then dark mode adds 8pt padding on each side.
        // 300x200 scaled to 860 width: height = 573.33, then +16pt padding each dimension.
        XCTAssertEqual(attachment.bounds.width, 876, accuracy: 0.01)
        XCTAssertEqual(attachment.bounds.height, 589.33, accuracy: 0.01)
    }

    // MARK: - MathAttachment

    func testMathAttachment_simpleExpression_rendersImage() {
        let attachment = MathAttachment(latex: "x^2 + y^2 = z^2")

        XCTAssertEqual(attachment.latexSource, "x^2 + y^2 = z^2")
        XCTAssertEqual(attachment.sourceMarkdown, "```math\nx^2 + y^2 = z^2\n```")
        // SwiftMath should render this successfully.
        XCTAssertNotNil(attachment.attachmentImage, "Simple LaTeX should render to an image")
        if let image = attachment.attachmentImage {
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }

    func testMathAttachment_invalidLatex_fallsBackToPlaceholder() {
        // Deliberately broken LaTeX — unmatched brace.
        let attachment = MathAttachment(latex: "\\frac{x}{")

        XCTAssertNotNil(attachment.attachmentImage, "Invalid LaTeX should produce a placeholder")
    }

    // MARK: - TableAttachment

    func testTableAttachment_rendersImage() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let header = [
            NSAttributedString(string: "Name"),
            NSAttributedString(string: "Value"),
        ]
        let body = [
            [NSAttributedString(string: "x"), NSAttributedString(string: "1")],
            [NSAttributedString(string: "y"), NSAttributedString(string: "2")],
        ]
        let attachment = TableAttachment(
            headerRow: header,
            bodyRows: body,
            columnAlignments: [.left, .right],
            theme: theme,
            sourceMarkdown: "| Name | Value |\n|------|-------|\n| x | 1 |\n| y | 2 |"
        )

        XCTAssertNotNil(attachment.attachmentImage)
        if let image = attachment.attachmentImage {
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
        XCTAssertNotNil(attachment.sourceMarkdown)
    }

    func testTableAttachment_emptyHeader_returns() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let attachment = TableAttachment(
            headerRow: [],
            bodyRows: [],
            columnAlignments: [],
            theme: theme
        )

        // Should still produce an image (1x1 fallback).
        XCTAssertNotNil(attachment.attachmentImage)
    }

    // MARK: - TableColumnAlignment

    func testTableColumnAlignment_cases() {
        // Verify the enum has the expected cases (compile-time check mostly).
        let alignments: [TableColumnAlignment] = [.left, .center, .right]
        XCTAssertEqual(alignments.count, 3)
    }
}
