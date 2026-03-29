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

final class AttributedStringThemeTests: XCTestCase {

    // MARK: - Font sizes

    func testBodyFontSize() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        XCTAssertEqual(theme.bodyFont.pointSize, 16.0)
    }

    func testCodeFontSize() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let expected = 16.0 * 0.85  // 13.6pt
        XCTAssertEqual(theme.codeFont.pointSize, expected, accuracy: 0.1)
    }

    func testCodeFontIsMonospaced() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        XCTAssertTrue(theme.codeFont.isFixedPitch)
    }

    func testHeadingFontSizes() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let expectedSizes: [CGFloat] = [32.0, 24.0, 20.0, 16.0, 14.0, 13.6]
        for level in 1...6 {
            let font = theme.headingFont(level: level)
            XCTAssertEqual(
                font.pointSize,
                expectedSizes[level - 1],
                accuracy: 0.1,
                "H\(level) font size mismatch"
            )
        }
    }

    func testHeadingFontIsSemibold() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        for level in 1...6 {
            let font = theme.headingFont(level: level)
            let traits = font.fontDescriptor.symbolicTraits
            XCTAssertTrue(
                traits.contains(.bold),
                "H\(level) should have bold trait (semibold weight)"
            )
        }
    }

    func testHeadingFontClampsBelowOne() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let font = theme.headingFont(level: 0)
        // Should clamp to level 1 (index 0)
        XCTAssertEqual(font.pointSize, 32.0, accuracy: 0.1)
    }

    func testHeadingFontClampsAboveSix() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let font = theme.headingFont(level: 10)
        // Should clamp to level 6 (index 5)
        XCTAssertEqual(font.pointSize, 13.6, accuracy: 0.1)
    }

    // MARK: - Colors

    func testSolarizedDarkTextColor() {
        let theme = AppTheme.solarized.attributedStringTheme(isDark: true)
        let expected = NSColor(Solarized.base0)
        assertColorsEqual(theme.textColor, expected)
    }

    func testSolarizedLightTextColor() {
        let theme = AppTheme.solarized.attributedStringTheme(isDark: false)
        let expected = NSColor(Solarized.base00)
        assertColorsEqual(theme.textColor, expected)
    }

    func testSolarizedLinkColorIsBlue() {
        let theme = AppTheme.solarized.attributedStringTheme(isDark: false)
        let expected = NSColor(Solarized.blue)
        assertColorsEqual(theme.linkColor, expected)
    }

    func testSolarizedBlockquoteBarColorIsCyan() {
        let theme = AppTheme.solarized.attributedStringTheme(isDark: true)
        let expected = NSColor(Solarized.cyan)
        assertColorsEqual(theme.blockquoteBarColor, expected)
    }

    func testDefaultThemeHasNilWindowBackground() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        XCTAssertNil(theme.windowBackground)
    }

    func testSolarizedThemeHasWindowBackground() {
        let darkTheme = AppTheme.solarized.attributedStringTheme(isDark: true)
        XCTAssertNotNil(darkTheme.windowBackground)
        let lightTheme = AppTheme.solarized.attributedStringTheme(isDark: false)
        XCTAssertNotNil(lightTheme.windowBackground)
    }

    func testH6UsesSubtleColor() {
        let theme = AppTheme.solarized.attributedStringTheme(isDark: true)
        // H6 color should be the subtle color, different from headings 1-5
        assertColorsEqual(theme.headingColor(level: 6), theme.subtleColor)
        // H1-H5 should use text color
        for level in 1...5 {
            assertColorsEqual(
                theme.headingColor(level: level),
                theme.textColor,
                "H\(level) should use text color"
            )
        }
    }

    func testDefaultThemeUsesLinkColor() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        assertColorsEqual(theme.linkColor, .linkColor)
    }

    // MARK: - Paragraph styles

    func testBodyParagraphSpacing() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let style = theme.bodyParagraphStyle
        XCTAssertEqual(style.paragraphSpacing, 16.0)
        XCTAssertEqual(style.lineSpacing, 4.0)  // 0.25 * 16
    }

    func testHeadingParagraphSpacing() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let style = theme.headingParagraphStyle
        XCTAssertEqual(style.paragraphSpacingBefore, 24.0)
        XCTAssertEqual(style.paragraphSpacing, 16.0)
        XCTAssertEqual(style.lineSpacing, 2.0)  // 0.125 * 16
    }

    func testBlockquoteParagraphIndent() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let style = theme.blockquoteParagraphStyle
        let expectedIndent = 16.0 * 1.2  // 0.2em bar + 1em padding
        XCTAssertEqual(style.headIndent, expectedIndent, accuracy: 0.1)
        XCTAssertEqual(style.firstLineHeadIndent, expectedIndent, accuracy: 0.1)
    }

    func testListItemParagraphNesting() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let level0 = theme.listItemParagraphStyle(level: 0)
        let level1 = theme.listItemParagraphStyle(level: 1)
        // Level 1 should be indented further than level 0
        XCTAssertGreaterThan(level1.headIndent, level0.headIndent)
    }

    func testListItemHangingIndent() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        let style = theme.listItemParagraphStyle(level: 0)
        // firstLineHeadIndent should be less than headIndent (hanging bullet)
        XCTAssertLessThan(style.firstLineHeadIndent, style.headIndent)
    }

    // MARK: - Heading dividers

    func testH1AndH2HaveDividers() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        XCTAssertTrue(theme.headingHasDivider(level: 1))
        XCTAssertTrue(theme.headingHasDivider(level: 2))
    }

    func testH3ThroughH6HaveNoDividers() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        for level in 3...6 {
            XCTAssertFalse(
                theme.headingHasDivider(level: level),
                "H\(level) should not have a divider"
            )
        }
    }

    // MARK: - Layout constants

    func testCodeBlockCornerRadius() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        XCTAssertEqual(theme.codeBlockCornerRadius, 6.0)
    }

    func testCodeBlockPadding() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        XCTAssertEqual(theme.codeBlockPadding, 16.0)
    }

    func testBlockquoteBarWidth() {
        let theme = AppTheme.default.attributedStringTheme(isDark: false)
        XCTAssertEqual(theme.blockquoteBarWidth, 3.2, accuracy: 0.1)  // 0.2 * 16
    }

    // MARK: - isDark flag

    func testIsDarkFlagPreserved() {
        let dark = AppTheme.solarized.attributedStringTheme(isDark: true)
        XCTAssertTrue(dark.isDark)
        let light = AppTheme.solarized.attributedStringTheme(isDark: false)
        XCTAssertFalse(light.isDark)
    }

    // MARK: - Syntax palette

    func testSyntaxPaletteMatchesAppTheme() {
        let theme = AppTheme.solarized.attributedStringTheme(isDark: true)
        let direct = AppTheme.solarized.syntaxColors(isDark: true)
        XCTAssertEqual(theme.syntaxPalette.keyword, direct.keyword)
        XCTAssertEqual(theme.syntaxPalette.comment, direct.comment)
    }

    // MARK: - Helpers

    /// Compare two NSColors by converting to sRGB and checking components.
    private func assertColorsEqual(
        _ a: NSColor,
        _ b: NSColor,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let aRGB = a.usingColorSpace(.sRGB),
              let bRGB = b.usingColorSpace(.sRGB)
        else {
            XCTFail(
                "Could not convert colors to sRGB for comparison. \(message)",
                file: file,
                line: line
            )
            return
        }
        XCTAssertEqual(aRGB.redComponent, bRGB.redComponent, accuracy: 0.01, message, file: file, line: line)
        XCTAssertEqual(aRGB.greenComponent, bRGB.greenComponent, accuracy: 0.01, message, file: file, line: line)
        XCTAssertEqual(aRGB.blueComponent, bRGB.blueComponent, accuracy: 0.01, message, file: file, line: line)
    }
}
