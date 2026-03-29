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
import Markdown
@testable import Pellucid

final class MarkdownRendererTests: XCTestCase {

    // Use the default theme for all tests.
    private var theme: AttributedStringTheme {
        AppTheme.default.attributedStringTheme(isDark: false)
    }

    private func render(_ markdown: String) -> RenderResult {
        let doc = Document(parsing: markdown)
        return MarkdownRenderer.render(document: doc, theme: theme)
    }

    // MARK: - Plain Text

    func testPlainTextParagraph() {
        let result = render("Hello world")
        XCTAssertEqual(result.attributedString.string, "Hello world")

        // Should use body font.
        let attrs = result.attributedString.attributes(at: 0, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        XCTAssertNotNil(font)
        XCTAssertEqual(font, theme.bodyFont)
    }

    func testPlainTextColor() {
        let result = render("Hello world")
        let attrs = result.attributedString.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertNotNil(color)
        XCTAssertEqual(color, theme.textColor)
    }

    // MARK: - Emphasis (Italic)

    func testEmphasis() {
        let result = render("Hello *world*")
        XCTAssertEqual(result.attributedString.string, "Hello world")

        // "Hello " at offset 0 should be body font.
        let normalAttrs = result.attributedString.attributes(at: 0, effectiveRange: nil)
        let normalFont = normalAttrs[.font] as? NSFont
        XCTAssertEqual(normalFont, theme.bodyFont)

        // "world" at offset 6 should be italic.
        let italicAttrs = result.attributedString.attributes(at: 6, effectiveRange: nil)
        let italicFont = italicAttrs[.font] as? NSFont
        XCTAssertEqual(italicFont, theme.italicFont)
    }

    // MARK: - Strong (Bold)

    func testStrong() {
        let result = render("Hello **world**")
        XCTAssertEqual(result.attributedString.string, "Hello world")

        // "world" at offset 6 should be bold.
        let boldAttrs = result.attributedString.attributes(at: 6, effectiveRange: nil)
        let boldFont = boldAttrs[.font] as? NSFont
        XCTAssertEqual(boldFont, theme.boldFont)
    }

    // MARK: - Bold + Italic

    func testBoldItalicNested() {
        let result = render("Hello ***world***")
        XCTAssertEqual(result.attributedString.string, "Hello world")

        // "world" at offset 6 should be bold-italic.
        let biAttrs = result.attributedString.attributes(at: 6, effectiveRange: nil)
        let biFont = biAttrs[.font] as? NSFont
        XCTAssertEqual(biFont, theme.boldItalicFont)
    }

    func testBoldInsideItalic() {
        // *italic **bold-italic** italic*
        let result = render("*italic **bold-italic** italic*")
        XCTAssertEqual(result.attributedString.string, "italic bold-italic italic")

        // "italic " at offset 0 should be italic.
        let italicFont = result.attributedString.attributes(at: 0, effectiveRange: nil)[.font] as? NSFont
        XCTAssertEqual(italicFont, theme.italicFont)

        // "bold-italic" at offset 7 should be bold-italic.
        let biFont = result.attributedString.attributes(at: 7, effectiveRange: nil)[.font] as? NSFont
        XCTAssertEqual(biFont, theme.boldItalicFont)

        // " italic" at the end should be italic again.
        let endFont = result.attributedString.attributes(at: 19, effectiveRange: nil)[.font] as? NSFont
        XCTAssertEqual(endFont, theme.italicFont)
    }

    // MARK: - Strikethrough

    func testStrikethrough() {
        let result = render("Hello ~~world~~")
        XCTAssertEqual(result.attributedString.string, "Hello world")

        // "world" at offset 6 should have strikethrough.
        let attrs = result.attributedString.attributes(at: 6, effectiveRange: nil)
        let strikethrough = attrs[.strikethroughStyle] as? Int
        XCTAssertEqual(strikethrough, NSUnderlineStyle.single.rawValue)

        // "Hello " should NOT have strikethrough.
        let normalAttrs = result.attributedString.attributes(at: 0, effectiveRange: nil)
        XCTAssertNil(normalAttrs[.strikethroughStyle])
    }

    // MARK: - Inline Code

    func testInlineCode() {
        let result = render("Use `map` here")
        XCTAssertEqual(result.attributedString.string, "Use map here")

        // "map" at offset 4 should be monospace.
        let codeAttrs = result.attributedString.attributes(at: 4, effectiveRange: nil)
        let codeFont = codeAttrs[.font] as? NSFont
        XCTAssertEqual(codeFont, theme.codeFont)

        // Should have code text color.
        let codeColor = codeAttrs[.foregroundColor] as? NSColor
        XCTAssertEqual(codeColor, theme.codeTextColor)

        // Should have inline code background marker.
        let hasBg = codeAttrs[.inlineCodeBackground] as? Bool
        XCTAssertEqual(hasBg, true)
    }

    // MARK: - Link

    func testLink() {
        let result = render("[Click here](https://example.com)")
        XCTAssertEqual(result.attributedString.string, "Click here")

        let attrs = result.attributedString.attributes(at: 0, effectiveRange: nil)

        // Should have .link attribute with correct URL.
        let link = attrs[.link] as? URL
        XCTAssertEqual(link, URL(string: "https://example.com"))

        // Should have link color.
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertEqual(color, theme.linkColor)

        // Should have underline.
        let underline = attrs[.underlineStyle] as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
    }

    func testLinkWithFormattedText() {
        let result = render("[**bold link**](https://example.com)")
        XCTAssertEqual(result.attributedString.string, "bold link")

        let attrs = result.attributedString.attributes(at: 0, effectiveRange: nil)

        // Should have bold font.
        let font = attrs[.font] as? NSFont
        XCTAssertEqual(font, theme.boldFont)

        // Should have link attribute.
        let link = attrs[.link] as? URL
        XCTAssertEqual(link, URL(string: "https://example.com"))
    }

    // MARK: - Image

    func testImagePlaceholder() {
        let result = render("![Alt text](image.png)")
        XCTAssertEqual(result.attributedString.string, "[image: Alt text]")
    }

    func testImageWithoutAlt() {
        let result = render("![](image.png)")
        XCTAssertEqual(result.attributedString.string, "[image]")
    }

    // MARK: - Breaks

    func testSoftBreak() {
        // In markdown, a line break without two trailing spaces is a soft break.
        let result = render("Hello\nworld")
        XCTAssertEqual(result.attributedString.string, "Hello world")
    }

    func testLineBreak() {
        // Two trailing spaces before newline = hard line break.
        let result = render("Hello  \nworld")
        XCTAssertEqual(result.attributedString.string, "Hello\nworld")
    }

    // MARK: - Multiple Paragraphs

    func testMultipleParagraphs() {
        let result = render("First paragraph.\n\nSecond paragraph.")
        XCTAssertEqual(result.attributedString.string, "First paragraph.\n\nSecond paragraph.")
    }

    func testThreeParagraphs() {
        let result = render("One.\n\nTwo.\n\nThree.")
        XCTAssertEqual(result.attributedString.string, "One.\n\nTwo.\n\nThree.")
    }

    // MARK: - Source Map

    func testSourceMapPopulated() {
        let result = render("Hello world")
        XCTAssertFalse(result.sourceMap.isEmpty)
        XCTAssertEqual(result.sourceMap.count, 1)

        let entry = result.sourceMap.entries[0]
        XCTAssertEqual(entry.nodeType, .paragraph)
        XCTAssertEqual(entry.attributedStringRange, NSRange(location: 0, length: 11))
    }

    func testSourceMapMultipleParagraphs() {
        let result = render("First.\n\nSecond.")
        XCTAssertEqual(result.sourceMap.count, 2)

        let first = result.sourceMap.entries[0]
        XCTAssertEqual(first.nodeType, .paragraph)
        XCTAssertEqual(first.sourceLineRange, 0..<1)

        let second = result.sourceMap.entries[1]
        XCTAssertEqual(second.nodeType, .paragraph)
        XCTAssertEqual(second.sourceLineRange, 2..<3)
    }

    func testSourceMapLineRanges() {
        let markdown = "First paragraph.\n\nSecond paragraph."
        let result = render(markdown)

        // First paragraph is on line 1 (0-based: 0).
        let firstEntry = result.sourceMap.entries[0]
        XCTAssertTrue(firstEntry.sourceLineRange.contains(0))

        // Second paragraph is on line 3 (0-based: 2).
        let secondEntry = result.sourceMap.entries[1]
        XCTAssertTrue(secondEntry.sourceLineRange.contains(2))
    }

    // MARK: - Empty Document

    func testEmptyDocument() {
        let result = render("")
        XCTAssertEqual(result.attributedString.string, "")
        XCTAssertTrue(result.sourceMap.isEmpty)
    }

    // MARK: - Mixed Inline Formatting

    func testMixedInlineFormatting() {
        let result = render("Normal **bold** *italic* `code`")
        XCTAssertEqual(result.attributedString.string, "Normal bold italic code")

        // "Normal " = body
        let normalFont = result.attributedString.attributes(at: 0, effectiveRange: nil)[.font] as? NSFont
        XCTAssertEqual(normalFont, theme.bodyFont)

        // "bold" = bold (at offset 7)
        let boldFont = result.attributedString.attributes(at: 7, effectiveRange: nil)[.font] as? NSFont
        XCTAssertEqual(boldFont, theme.boldFont)

        // "italic" = italic (at offset 12)
        let italicFont = result.attributedString.attributes(at: 12, effectiveRange: nil)[.font] as? NSFont
        XCTAssertEqual(italicFont, theme.italicFont)

        // "code" = monospace (at offset 19)
        let codeFont = result.attributedString.attributes(at: 19, effectiveRange: nil)[.font] as? NSFont
        XCTAssertEqual(codeFont, theme.codeFont)
    }
}
