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

import AppKit
import SwiftUI

/// Provides NSAttributedString styling attributes (fonts, colors, paragraph styles)
/// for the NSTextView-based markdown renderer. Replaces MarkdownUI's theme builders
/// with native AppKit types.
struct AttributedStringTheme: Sendable {

    // MARK: - Constants

    /// Base body font size in points.
    static let bodyFontSize: CGFloat = 16.0

    /// Heading size multipliers relative to body font size (h1-h6).
    /// Matches the MarkdownUI theme: 2em, 1.5em, 1.25em, 1em, 0.875em, 0.85em.
    static let headingSizeMultipliers: [CGFloat] = [2.0, 1.5, 1.25, 1.0, 0.875, 0.85]

    /// Code font size multiplier (0.85em of body).
    static let codeFontSizeMultiplier: CGFloat = 0.85

    // MARK: - Properties

    /// Text color for body content.
    let textColor: NSColor

    /// Background color for the window/view, or nil for system default.
    let windowBackground: NSColor?

    /// Subtle/secondary text color (used for h6, blockquote text, thematic breaks).
    let subtleColor: NSColor

    /// Link color.
    let linkColor: NSColor

    /// Code inline/block text color (same as body text in current themes).
    let codeTextColor: NSColor

    /// Code block background color.
    let codeBlockBackground: NSColor

    /// Blockquote accent bar color.
    let blockquoteBarColor: NSColor

    /// Blockquote text color (subtle).
    let blockquoteTextColor: NSColor

    /// Heading colors for levels 1-6. Most headings use text color; h6 uses subtle.
    let headingColors: [NSColor]

    /// Table border color.
    let tableBorderColor: NSColor

    /// Table alternating row backgrounds: [even, odd].
    let tableRowBackgrounds: [NSColor]

    /// Thematic break (horizontal rule) color.
    let thematicBreakColor: NSColor

    /// Syntax highlighting palette.
    let syntaxPalette: SyntaxColorPalette

    /// Whether this theme is for dark mode.
    let isDark: Bool

    // MARK: - Fonts

    /// Body font (system, 16pt).
    var bodyFont: NSFont {
        .systemFont(ofSize: Self.bodyFontSize)
    }

    /// Bold body font.
    var boldFont: NSFont {
        .systemFont(ofSize: Self.bodyFontSize, weight: .semibold)
    }

    /// Italic body font.
    var italicFont: NSFont {
        let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
            .withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: Self.bodyFontSize)
            ?? NSFont.systemFont(ofSize: Self.bodyFontSize)
    }

    /// Bold-italic body font.
    var boldItalicFont: NSFont {
        let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
            .withSymbolicTraits([.italic, .bold])
        return NSFont(descriptor: descriptor, size: Self.bodyFontSize)
            ?? NSFont.boldSystemFont(ofSize: Self.bodyFontSize)
    }

    /// Monospace font for code (0.85em of body = ~13.6pt).
    var codeFont: NSFont {
        let size = Self.bodyFontSize * Self.codeFontSizeMultiplier
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// Bold monospace font for code.
    var codeBoldFont: NSFont {
        let size = Self.bodyFontSize * Self.codeFontSizeMultiplier
        return NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
    }

    /// Returns the heading font for the given level (1-6).
    /// All headings use semibold weight.
    func headingFont(level: Int) -> NSFont {
        let index = max(0, min(level - 1, Self.headingSizeMultipliers.count - 1))
        let size = Self.bodyFontSize * Self.headingSizeMultipliers[index]
        return .systemFont(ofSize: size, weight: .semibold)
    }

    /// Returns the heading color for the given level (1-6).
    /// H6 uses subtle color; all others use text color.
    func headingColor(level: Int) -> NSColor {
        let index = max(0, min(level - 1, headingColors.count - 1))
        return headingColors[index]
    }

    /// Returns whether the heading at this level should have a divider beneath it.
    /// H1 and H2 have dividers in the Solarized/GitHub themes.
    func headingHasDivider(level: Int) -> Bool {
        level == 1 || level == 2
    }

    // MARK: - Paragraph Styles

    /// Body paragraph style: line spacing ~0.25em (4pt at 16pt base).
    /// paragraphSpacing is the space AFTER this paragraph (before the next).
    /// Combined with heading's paragraphSpacingBefore, produces the correct gaps.
    var bodyParagraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Self.bodyFontSize * 0.25  // 4pt
        style.paragraphSpacing = 12.0
        return style
    }

    /// Heading paragraph style: extra space before so headings get visual breathing room
    /// from the preceding block, and a moderate gap after for the heading rule + body.
    /// NSTextView stacks paragraphSpacing + paragraphSpacingBefore (unlike CSS margin
    /// collapse), so the effective body→heading gap is body.paragraphSpacing + this value.
    var headingParagraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Self.bodyFontSize * 0.125  // 2pt
        style.paragraphSpacingBefore = 18.0
        style.paragraphSpacing = 14.0
        return style
    }

    /// Code block paragraph style: line spacing ~0.225em, no per-paragraph spacing
    /// (each newline inside a code block is its own NSTextView paragraph; non-zero
    /// paragraphSpacing here would create visible gaps between every line).
    /// Includes head indent so text sits inside the visual background padding drawn
    /// by MarkdownNSTextView.
    var codeBlockParagraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let codeFontSize = Self.bodyFontSize * Self.codeFontSizeMultiplier
        style.lineSpacing = codeFontSize * 0.225  // ~3pt
        style.firstLineHeadIndent = codeBlockPadding
        style.headIndent = codeBlockPadding
        style.tailIndent = -codeBlockPadding
        return style
    }

    /// Blockquote paragraph style: indented to account for accent bar + padding.
    /// Left indent ~1.2em per nesting level (bar width 0.2em + padding 1em).
    /// - Parameter level: Nesting level (1-based). Each level adds additional indent.
    func blockquoteParagraphStyle(level: Int = 1) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let perLevel = Self.bodyFontSize * 1.2  // 0.2em bar + 1em padding
        let indent = perLevel * CGFloat(level)
        style.headIndent = indent
        style.firstLineHeadIndent = indent
        style.lineSpacing = Self.bodyFontSize * 0.25
        style.paragraphSpacing = 16.0
        return style
    }

    /// List item paragraph style with indent for bullets/numbers.
    /// - Parameter level: Nesting level (0-based). Each level adds ~1.5em indent.
    func listItemParagraphStyle(level: Int) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let baseIndent = Self.bodyFontSize * 1.5  // ~24pt per level
        let indent = baseIndent * CGFloat(level + 1)
        style.headIndent = indent
        style.firstLineHeadIndent = indent - Self.bodyFontSize  // hang the bullet/number
        style.lineSpacing = Self.bodyFontSize * 0.25
        style.paragraphSpacingBefore = Self.bodyFontSize * 0.25  // margin top 0.25em
        style.paragraphSpacing = 2.0  // small gap after each item; list→next-block gap stacks with next block's spacingBefore
        let tabStop = NSTextTab(textAlignment: .left, location: indent)
        style.tabStops = [tabStop]
        style.defaultTabInterval = 36.0
        return style
    }

    /// Table cell paragraph style.
    var tableCellParagraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = Self.bodyFontSize * 0.25
        return style
    }

    // MARK: - Layout Constants

    /// Code block corner radius.
    let codeBlockCornerRadius: CGFloat = 6.0

    /// Code block padding.
    let codeBlockPadding: CGFloat = 16.0

    /// Blockquote accent bar width (0.2em).
    var blockquoteBarWidth: CGFloat {
        Self.bodyFontSize * 0.2  // ~3.2pt
    }

    /// Blockquote horizontal padding (1em).
    var blockquoteHorizontalPadding: CGFloat {
        Self.bodyFontSize * 1.0  // 16pt
    }

    /// Thematic break height (0.25em).
    var thematicBreakHeight: CGFloat {
        Self.bodyFontSize * 0.25  // 4pt
    }

    /// Thematic break vertical margin.
    let thematicBreakMargin: CGFloat = 24.0

    /// Table cell vertical padding.
    let tableCellVerticalPadding: CGFloat = 6.0

    /// Table cell horizontal padding.
    let tableCellHorizontalPadding: CGFloat = 13.0

    // MARK: - Syntax Color Helpers

    /// Returns an NSColor for a syntax color palette entry.
    /// Converts the SwiftUI Color from SyntaxColorPalette to NSColor.
    func syntaxNSColor(for keyPath: KeyPath<SyntaxColorPalette, Color>) -> NSColor {
        NSColor(syntaxPalette[keyPath: keyPath])
    }
}

// MARK: - AppTheme Extension

extension AppTheme {
    /// Creates an AttributedStringTheme for the NSTextView-based renderer.
    func attributedStringTheme(isDark: Bool) -> AttributedStringTheme {
        switch self {
        case .default:
            return defaultAttributedStringTheme(isDark: isDark)
        case .solarized:
            return solarizedAttributedStringTheme(isDark: isDark)
        }
    }

    private func defaultAttributedStringTheme(isDark: Bool) -> AttributedStringTheme {
        let textColor = NSColor.textColor
        let subtleColor = NSColor.secondaryLabelColor

        return AttributedStringTheme(
            textColor: textColor,
            windowBackground: nil,
            subtleColor: subtleColor,
            linkColor: .linkColor,
            codeTextColor: textColor,
            codeBlockBackground: NSColor.textBackgroundColor.withAlphaComponent(0.5),
            blockquoteBarColor: subtleColor,
            blockquoteTextColor: subtleColor,
            headingColors: Array(repeating: textColor, count: 5) + [subtleColor],
            tableBorderColor: subtleColor,
            tableRowBackgrounds: [
                NSColor.textBackgroundColor,
                NSColor.textBackgroundColor.withAlphaComponent(0.5),
            ],
            thematicBreakColor: subtleColor,
            syntaxPalette: syntaxColors(isDark: isDark),
            isDark: isDark
        )
    }

    private func solarizedAttributedStringTheme(isDark: Bool) -> AttributedStringTheme {
        let textColor = isDark ? NSColor(Solarized.base0) : NSColor(Solarized.base00)
        let backgroundColor = isDark ? NSColor(Solarized.base03) : NSColor(Solarized.base3)
        let codeBackground = isDark ? NSColor(Solarized.base02) : NSColor(Solarized.base2)
        let subtleColor = isDark ? NSColor(Solarized.base01) : NSColor(Solarized.base1)

        return AttributedStringTheme(
            textColor: textColor,
            windowBackground: backgroundColor,
            subtleColor: subtleColor,
            linkColor: NSColor(Solarized.blue),
            codeTextColor: textColor,
            codeBlockBackground: codeBackground,
            blockquoteBarColor: NSColor(Solarized.cyan),
            blockquoteTextColor: subtleColor,
            headingColors: Array(repeating: textColor, count: 5) + [subtleColor],
            tableBorderColor: subtleColor,
            tableRowBackgrounds: [backgroundColor, codeBackground],
            thematicBreakColor: subtleColor,
            syntaxPalette: syntaxColors(isDark: isDark),
            isDark: isDark
        )
    }
}
