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
@preconcurrency import Markdown
import os

// MARK: - Custom Attributed String Keys

extension NSAttributedString.Key {
    /// Marks inline code spans for custom background drawing in the text view.
    static let inlineCodeBackground = NSAttributedString.Key("pellucid.inlineCodeBackground")

    /// Marks code block ranges for custom background/border drawing.
    static let codeBlockRange = NSAttributedString.Key("pellucid.codeBlockRange")

    /// Stores the language tag for a code block (e.g., "swift", "python").
    static let codeBlockLanguage = NSAttributedString.Key("pellucid.codeBlockLanguage")

    /// Stores the 0-based source line range for Cmd+click → editor integration.
    static let sourceLineRange = NSAttributedString.Key("pellucid.sourceLineRange")

    /// Stores the slugified heading anchor ID for scroll-to-heading.
    static let headingAnchorID = NSAttributedString.Key("pellucid.headingAnchorID")

    /// Marks a heading that should have a divider drawn beneath it (H1, H2).
    static let headingDivider = NSAttributedString.Key("pellucid.headingDivider")

    /// Marks a thematic break for custom drawing.
    static let thematicBreak = NSAttributedString.Key("pellucid.thematicBreak")

    /// Marks a blockquote range for accent bar drawing.
    static let blockquoteRange = NSAttributedString.Key("pellucid.blockquoteRange")
}

// MARK: - Render Result

/// The output of rendering a markdown document to an attributed string.
///
/// NSAttributedString is not Sendable, but RenderResult is only produced and
/// consumed on @MainActor, so we mark it @unchecked Sendable to satisfy
/// Swift 6 strict concurrency without unnecessary copying.
struct RenderResult: @unchecked Sendable {
    let attributedString: NSAttributedString
    let sourceMap: SourceMap
}

// MARK: - MarkdownRenderer

/// Walks a swift-markdown AST `Document` and produces an `NSAttributedString`
/// with a companion `SourceMap` for bidirectional source ↔ rendered mapping.
///
/// Handles both inline nodes (text, emphasis, strong, code, links, images) and
/// block-level nodes (headings, paragraphs, lists, blockquotes, code blocks,
/// thematic breaks, HTML blocks).
struct MarkdownRenderer: MarkupVisitor {

    typealias Result = NSMutableAttributedString

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pellucid",
        category: "MarkdownRenderer"
    )

    // MARK: - State

    private let theme: AttributedStringTheme
    private var sourceMap = SourceMap()

    /// Base URL for resolving relative image paths (directory containing the markdown file).
    private let baseURL: URL?

    /// Font trait stack for composing bold/italic through nested inline markup.
    private var fontTraits: NSFontDescriptor.SymbolicTraits = []

    /// Whether we are currently inside a link (to suppress nested link styling).
    private var insideLink = false

    /// Current list nesting depth (0-based). Incremented for each nested list.
    private var listNestingLevel = -1

    /// Whether we are currently inside a blockquote (to apply blockquote text color).
    private var insideBlockquote = false

    // MARK: - Public API

    /// Renders a markdown document into an attributed string with source mapping.
    ///
    /// - Parameters:
    ///   - document: A parsed swift-markdown `Document`.
    ///   - theme: The `AttributedStringTheme` controlling fonts and colors.
    ///   - baseURL: Base directory URL for resolving relative image paths.
    /// - Returns: A `RenderResult` containing the attributed string and source map.
    static func render(
        document: Document,
        theme: AttributedStringTheme,
        baseURL: URL? = nil
    ) -> RenderResult {
        var renderer = MarkdownRenderer(theme: theme, baseURL: baseURL)
        let result = renderer.visit(document)
        return RenderResult(
            attributedString: result,
            sourceMap: renderer.sourceMap
        )
    }

    private init(theme: AttributedStringTheme, baseURL: URL? = nil) {
        self.theme = theme
        self.baseURL = baseURL
    }

    // MARK: - Font Resolution

    /// Returns the appropriate font based on the current trait stack.
    private var currentFont: NSFont {
        let isBold = fontTraits.contains(.bold)
        let isItalic = fontTraits.contains(.italic)
        switch (isBold, isItalic) {
        case (true, true):
            return theme.boldItalicFont
        case (true, false):
            return theme.boldFont
        case (false, true):
            return theme.italicFont
        case (false, false):
            return theme.bodyFont
        }
    }

    /// Base attributes for the current inline context (font + text color).
    private var currentAttributes: [NSAttributedString.Key: Any] {
        [
            .font: currentFont,
            .foregroundColor: insideBlockquote ? theme.blockquoteTextColor : theme.textColor,
        ]
    }

    // MARK: - MarkupVisitor — Document

    mutating func defaultVisit(_ markup: Markup) -> NSMutableAttributedString {
        // Walk children by default, concatenating results.
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    mutating func visitDocument(_ document: Document) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        var isFirstBlock = true
        for child in document.children {
            if !isFirstBlock {
                // Single newline between blocks — paragraph styles handle visual spacing.
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: theme.bodyFont,
                    .foregroundColor: theme.textColor,
                ]))
            }
            let blockStart = result.length
            result.append(visit(child))

            // Record source map entry for block-level nodes that have source ranges.
            addSourceMapEntry(for: child, atOffset: blockStart, inResult: result)

            isFirstBlock = false
        }
        return result
    }

    // MARK: - MarkupVisitor — Block Nodes

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for child in paragraph.children {
            result.append(visit(child))
        }
        // Apply body or blockquote paragraph style to the entire paragraph.
        let paragraphStyle = insideBlockquote ? theme.blockquoteParagraphStyle : theme.bodyParagraphStyle
        result.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }

    mutating func visitHeading(_ heading: Heading) -> NSMutableAttributedString {
        let level = heading.level
        let headingFont = theme.headingFont(level: level)
        let headingColor = theme.headingColor(level: level)
        let anchorID = slugify(heading.plainText)

        let result = visitChildren(of: heading)
        let fullRange = NSRange(location: 0, length: result.length)

        // Apply heading font and color.
        result.addAttribute(.font, value: headingFont, range: fullRange)
        result.addAttribute(.foregroundColor, value: headingColor, range: fullRange)

        // Apply heading paragraph style.
        result.addAttribute(.paragraphStyle, value: theme.headingParagraphStyle, range: fullRange)

        // Anchor ID for scroll-to-heading.
        result.addAttribute(.headingAnchorID, value: anchorID, range: fullRange)

        // Divider marker for H1/H2.
        if theme.headingHasDivider(level: level) {
            result.addAttribute(.headingDivider, value: true, range: fullRange)
        }

        return result
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSMutableAttributedString {
        let previousInsideBlockquote = insideBlockquote
        insideBlockquote = true

        let result = NSMutableAttributedString()
        var isFirstChild = true
        for child in blockQuote.children {
            if !isFirstChild {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: theme.bodyFont,
                    .foregroundColor: theme.blockquoteTextColor,
                ]))
            }
            result.append(visit(child))
            isFirstChild = false
        }

        let fullRange = NSRange(location: 0, length: result.length)

        // Mark the entire blockquote for accent bar drawing.
        result.addAttribute(.blockquoteRange, value: true, range: fullRange)

        insideBlockquote = previousInsideBlockquote
        return result
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSMutableAttributedString {
        // Strip trailing newline from code (CodeBlock.code often ends with \n).
        var code = codeBlock.code
        while code.hasSuffix("\n") {
            code.removeLast()
        }

        let language = codeBlock.language?.lowercased()

        // Math/LaTeX blocks → MathAttachment (rendered via SwiftMath).
        if language == "math" || language == "latex" {
            return renderMathBlock(latex: code)
        }

        // PlantUML blocks → DiagramAttachment placeholder.
        if language == "plantuml" {
            return renderPlantUMLPlaceholder(source: code)
        }

        let result: NSMutableAttributedString

        // Attempt syntax highlighting if a language grammar is available.
        if let language, let grammar = grammars[language] {
            let tokens = tokenize(code: code, grammar: grammar)
            result = buildSyntaxHighlightedString(code: code, tokens: tokens)
        } else {
            result = NSMutableAttributedString(string: code, attributes: [
                .font: theme.codeFont,
                .foregroundColor: theme.codeTextColor,
            ])
        }

        let fullRange = NSRange(location: 0, length: result.length)

        // Apply code block paragraph style.
        result.addAttribute(.paragraphStyle, value: theme.codeBlockParagraphStyle, range: fullRange)

        // Mark the entire range for code block background/border drawing.
        result.addAttribute(.codeBlockRange, value: true, range: fullRange)

        // Store the language tag.
        if let language {
            result.addAttribute(.codeBlockLanguage, value: language, range: fullRange)
        }

        return result
    }

    /// Renders a LaTeX math expression as a MathAttachment centered in a paragraph.
    private func renderMathBlock(latex: String) -> NSMutableAttributedString {
        let attachment = MathAttachment(
            latex: latex,
            fontSize: 18,
            textColor: theme.textColor
        )

        let result = NSMutableAttributedString(attachment: attachment)

        // Wrap in a centered paragraph style with vertical spacing.
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = .center
        paraStyle.paragraphSpacingBefore = 8
        paraStyle.paragraphSpacing = 8

        result.addAttribute(
            .paragraphStyle,
            value: paraStyle,
            range: NSRange(location: 0, length: result.length)
        )

        return result
    }

    /// Renders a PlantUML placeholder as a DiagramAttachment.
    /// The actual rendering is async; ContentView replaces the placeholder.
    private func renderPlantUMLPlaceholder(source: String) -> NSMutableAttributedString {
        let placeholderSize = CGSize(width: 300, height: 60)
        let placeholderImage = NSImage(size: placeholderSize, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            context.setFillColor(NSColor.separatorColor.withAlphaComponent(0.2).cgColor)
            let bgPath = CGPath(roundedRect: bounds, cornerWidth: 8, cornerHeight: 8, transform: nil)
            context.addPath(bgPath)
            context.fillPath()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            let text = NSAttributedString(string: "Rendering diagram\u{2026}", attributes: attrs)
            let textSize = text.size()
            let textOrigin = CGPoint(
                x: (bounds.width - textSize.width) / 2,
                y: (bounds.height - textSize.height) / 2
            )
            text.draw(at: textOrigin)
            context.restoreGState()
            return true
        }

        let attachment = DiagramAttachment(
            renderedImage: placeholderImage,
            plantUMLSource: source,
            isDarkMode: theme.isDark
        )

        let result = NSMutableAttributedString(attachment: attachment)
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = .center
        paraStyle.paragraphSpacingBefore = 8
        paraStyle.paragraphSpacing = 8
        result.addAttribute(
            .paragraphStyle,
            value: paraStyle,
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSMutableAttributedString {
        listNestingLevel += 1
        let result = NSMutableAttributedString()
        var isFirstItem = true

        for child in unorderedList.children {
            if !isFirstItem {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: theme.bodyFont,
                    .foregroundColor: insideBlockquote ? theme.blockquoteTextColor : theme.textColor,
                ]))
            }
            if let listItem = child as? ListItem {
                let itemResult = renderListItem(listItem, ordered: false, index: 0)
                result.append(itemResult)
            } else {
                result.append(visit(child))
            }
            isFirstItem = false
        }

        listNestingLevel -= 1
        return result
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> NSMutableAttributedString {
        listNestingLevel += 1
        let result = NSMutableAttributedString()
        var isFirstItem = true
        var index = Int(orderedList.startIndex)

        for child in orderedList.children {
            if !isFirstItem {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: theme.bodyFont,
                    .foregroundColor: insideBlockquote ? theme.blockquoteTextColor : theme.textColor,
                ]))
            }
            if let listItem = child as? ListItem {
                let itemResult = renderListItem(listItem, ordered: true, index: index)
                result.append(itemResult)
                index += 1
            } else {
                result.append(visit(child))
            }
            isFirstItem = false
        }

        listNestingLevel -= 1
        return result
    }

    mutating func visitListItem(_ listItem: ListItem) -> NSMutableAttributedString {
        // ListItems are normally handled via renderListItem from the list visitor.
        // This fallback handles the case where a ListItem appears outside a list context.
        return renderListItem(listItem, ordered: false, index: 0)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSMutableAttributedString {
        // Use invisible placeholder text — the actual line is drawn by
        // MarkdownNSTextView.drawThematicBreaks(). The text reserves vertical
        // space so the layout manager knows where to position the drawn rule.
        let separator = String(repeating: "\u{2500}", count: 40)  // "─" box drawing
        let thematicBreakStyle = NSMutableParagraphStyle()
        thematicBreakStyle.paragraphSpacingBefore = theme.thematicBreakMargin
        thematicBreakStyle.paragraphSpacing = theme.thematicBreakMargin
        let attrs: [NSAttributedString.Key: Any] = [
            .font: theme.bodyFont,
            .foregroundColor: NSColor.clear,
            .thematicBreak: true,
            .paragraphStyle: thematicBreakStyle,
        ]
        return NSMutableAttributedString(string: separator, attributes: attrs)
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> NSMutableAttributedString {
        var html = htmlBlock.rawHTML
        // Strip trailing newline.
        while html.hasSuffix("\n") {
            html.removeLast()
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: theme.codeFont,
            .foregroundColor: theme.subtleColor,
            .paragraphStyle: theme.codeBlockParagraphStyle,
        ]
        return NSMutableAttributedString(string: html, attributes: attrs)
    }

    mutating func visitTable(_ table: Table) -> NSMutableAttributedString {
        // Collect column alignments.
        let columnAlignments: [TableColumnAlignment] = table.columnAlignments.map { alignment in
            switch alignment {
            case .left: .left
            case .center: .center
            case .right: .right
            case nil: .left
            }
        }

        // Render header cells with bold font.
        let previousTraits = fontTraits
        fontTraits.insert(.bold)
        var headerCells: [NSAttributedString] = []
        let head = table.head
        for cell in head.cells {
            let cellContent = visitChildren(of: cell)
            headerCells.append(cellContent)
        }
        fontTraits = previousTraits

        // Render body cells.
        var bodyRows: [[NSAttributedString]] = []
        let body = table.body
        for row in body.rows {
            var rowCells: [NSAttributedString] = []
            for cell in row.cells {
                let cellContent = visitChildren(of: cell)
                rowCells.append(cellContent)
            }
            bodyRows.append(rowCells)
        }

        // Create the TableAttachment.
        let attachment = TableAttachment(
            headerRow: headerCells,
            bodyRows: bodyRows,
            columnAlignments: columnAlignments,
            theme: theme,
            sourceMarkdown: nil
        )

        let result = NSMutableAttributedString(attachment: attachment)

        // Wrap in a centered paragraph style with vertical spacing.
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = .center
        paraStyle.paragraphSpacingBefore = 8
        paraStyle.paragraphSpacing = 8
        result.addAttribute(
            .paragraphStyle,
            value: paraStyle,
            range: NSRange(location: 0, length: result.length)
        )

        return result
    }

    // MARK: - MarkupVisitor — Inline Nodes

    mutating func visitText(_ text: Markdown.Text) -> NSMutableAttributedString {
        NSMutableAttributedString(string: text.string, attributes: currentAttributes)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSMutableAttributedString {
        let previousTraits = fontTraits
        fontTraits.insert(.italic)
        let result = visitChildren(of: emphasis)
        fontTraits = previousTraits
        return result
    }

    mutating func visitStrong(_ strong: Strong) -> NSMutableAttributedString {
        let previousTraits = fontTraits
        fontTraits.insert(.bold)
        let result = visitChildren(of: strong)
        fontTraits = previousTraits
        return result
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSMutableAttributedString {
        let result = visitChildren(of: strikethrough)
        result.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> NSMutableAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.codeFont,
            .foregroundColor: theme.codeTextColor,
            .inlineCodeBackground: true,
        ]
        return NSMutableAttributedString(string: inlineCode.code, attributes: attributes)
    }

    mutating func visitLink(_ link: Link) -> NSMutableAttributedString {
        let previousInsideLink = insideLink
        insideLink = true
        let result = visitChildren(of: link)
        insideLink = previousInsideLink

        let fullRange = NSRange(location: 0, length: result.length)

        // Apply link attributes.
        if let destination = link.destination, let url = URL(string: destination) {
            result.addAttribute(.link, value: url, range: fullRange)
        }
        result.addAttribute(.foregroundColor, value: theme.linkColor, range: fullRange)
        result.addAttribute(
            .underlineStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: fullRange
        )

        return result
    }

    mutating func visitImage(_ image: Markdown.Image) -> NSMutableAttributedString {
        // Collect alt text from children.
        let altText = image.children.compactMap { child -> String? in
            if let text = child as? Markdown.Text {
                return text.string
            }
            return nil
        }.joined()

        // Build the original markdown source for copy-as-markdown.
        let sourceMarkdown: String
        if let source = image.source {
            if altText.isEmpty {
                sourceMarkdown = "![](\(source))"
            } else {
                sourceMarkdown = "![\(altText)](\(source))"
            }
        } else {
            sourceMarkdown = altText.isEmpty ? "![]()" : "![\(altText)]()"
        }

        // Try to resolve and load the image from a local file.
        if let source = image.source, !source.isEmpty {
            let imageURL: URL?

            if source.hasPrefix("http://") || source.hasPrefix("https://") {
                // Remote images: show placeholder text (no network fetching in renderer).
                imageURL = nil
            } else if let base = baseURL {
                // Resolve relative path against the markdown file's directory.
                imageURL = base.appendingPathComponent(source)
            } else {
                imageURL = URL(fileURLWithPath: source)
            }

            if let url = imageURL, FileManager.default.fileExists(atPath: url.path) {
                let attachment = ImageAttachment(
                    url: url,
                    maxWidth: blockAttachmentDefaultMaxWidth,
                    sourceMarkdown: sourceMarkdown
                )
                let result = NSMutableAttributedString(attachment: attachment)

                // Center the image with paragraph spacing.
                let paraStyle = NSMutableParagraphStyle()
                paraStyle.alignment = .center
                paraStyle.paragraphSpacingBefore = 4
                paraStyle.paragraphSpacing = 4
                result.addAttribute(
                    .paragraphStyle,
                    value: paraStyle,
                    range: NSRange(location: 0, length: result.length)
                )

                return result
            }
        }

        // Fallback: show placeholder text for unresolvable images.
        let placeholder = altText.isEmpty ? "[image]" : "[image: \(altText)]"
        return NSMutableAttributedString(string: placeholder, attributes: currentAttributes)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSMutableAttributedString {
        NSMutableAttributedString(string: " ", attributes: currentAttributes)
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSMutableAttributedString {
        NSMutableAttributedString(string: "\n", attributes: currentAttributes)
    }

    // MARK: - List Item Helpers

    /// Renders a single list item with the appropriate bullet/number marker.
    private mutating func renderListItem(
        _ listItem: ListItem,
        ordered: Bool,
        index: Int
    ) -> NSMutableAttributedString {
        let level = max(0, listNestingLevel)
        let textColor = insideBlockquote ? theme.blockquoteTextColor : theme.textColor

        // Determine the marker.
        let marker: String
        if let checkbox = listItem.checkbox {
            marker = checkbox == .checked ? "\u{2611}\t" : "\u{2610}\t"  // ☑ / ☐
        } else if ordered {
            marker = "\(index).\t"
        } else {
            marker = "\u{2022}\t"  // •
        }

        let markerAttrs: [NSAttributedString.Key: Any] = [
            .font: theme.bodyFont,
            .foregroundColor: textColor,
        ]
        let result = NSMutableAttributedString(string: marker, attributes: markerAttrs)

        // Track where this item's own text starts (before nested lists).
        let itemContentStart = 0

        // Render children. List items contain block children (paragraphs, nested lists, etc.).
        var isFirstChild = true
        for child in listItem.children {
            if child is UnorderedList || child is OrderedList {
                // Apply paragraph style to content so far, before appending nested list.
                let paragraphStyle = theme.listItemParagraphStyle(level: level)
                let contentRange = NSRange(location: itemContentStart, length: result.length - itemContentStart)
                if contentRange.length > 0 {
                    result.addAttribute(.paragraphStyle, value: paragraphStyle, range: contentRange)
                }

                // Nested list — insert newline before it.
                result.append(NSAttributedString(string: "\n", attributes: markerAttrs))
                result.append(visit(child))
            } else {
                // Inline content (paragraph, etc.) — render inline, no extra newline for first child.
                if !isFirstChild {
                    result.append(NSAttributedString(string: "\n", attributes: markerAttrs))
                }
                // For paragraphs inside list items, render children directly (skip paragraph wrapper).
                if let paragraph = child as? Paragraph {
                    result.append(visitChildren(of: paragraph))
                } else {
                    result.append(visit(child))
                }
            }
            isFirstChild = false
        }

        // Apply list item paragraph style to any remaining un-styled content.
        // For items without nested lists, this covers the entire result.
        // For items with nested lists, this is a no-op if already applied above,
        // but covers trailing content after the last nested list.
        let paragraphStyle = theme.listItemParagraphStyle(level: level)

        // Check if there are nested list children. If not, apply to entire range.
        let hasNestedList = listItem.children.contains { $0 is UnorderedList || $0 is OrderedList }
        if !hasNestedList {
            result.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: result.length)
            )
        }

        return result
    }

    // MARK: - Syntax Highlighting Helper

    /// Builds an attributed string from tokenized code with syntax colors.
    private func buildSyntaxHighlightedString(
        code: String,
        tokens: [Token]
    ) -> NSMutableAttributedString {
        guard !tokens.isEmpty else {
            return NSMutableAttributedString(string: code, attributes: [
                .font: theme.codeFont,
                .foregroundColor: theme.codeTextColor,
            ])
        }

        let sorted = tokens.sorted { $0.range.lowerBound < $1.range.lowerBound }
        let result = NSMutableAttributedString()
        var currentIndex = code.startIndex

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: theme.codeFont,
            .foregroundColor: theme.codeTextColor,
        ]

        for token in sorted {
            guard let range = Range(token.range, in: code) else { continue }

            // Append un-highlighted text before this token.
            if currentIndex < range.lowerBound {
                let plain = String(code[currentIndex..<range.lowerBound])
                result.append(NSAttributedString(string: plain, attributes: baseAttrs))
            }

            // Append highlighted token.
            let tokenText = String(code[range])
            var tokenAttrs = baseAttrs
            tokenAttrs[.foregroundColor] = syntaxColor(for: token.kind)
            result.append(NSAttributedString(string: tokenText, attributes: tokenAttrs))

            currentIndex = range.upperBound
        }

        // Append any remaining text after the last token.
        if currentIndex < code.endIndex {
            let trailing = String(code[currentIndex...])
            result.append(NSAttributedString(string: trailing, attributes: baseAttrs))
        }

        return result
    }

    /// Maps a TokenKind to the corresponding NSColor from the theme's syntax palette.
    private func syntaxColor(for kind: TokenKind) -> NSColor {
        switch kind {
        case .keyword: theme.syntaxNSColor(for: \.keyword)
        case .string: theme.syntaxNSColor(for: \.string)
        case .comment: theme.syntaxNSColor(for: \.comment)
        case .number: theme.syntaxNSColor(for: \.number)
        case .type: theme.syntaxNSColor(for: \.type)
        case .function: theme.syntaxNSColor(for: \.function)
        case .operator_: theme.syntaxNSColor(for: \.operator_)
        case .attribute: theme.syntaxNSColor(for: \.attribute)
        case .constant: theme.syntaxNSColor(for: \.constant)
        }
    }

    // MARK: - General Helpers

    /// Visits all children of a markup node, concatenating their results.
    private mutating func visitChildren(of node: some Markup) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for child in node.children {
            result.append(visit(child))
        }
        return result
    }

    /// Adds a source map entry for a block-level node if it has a source range.
    private mutating func addSourceMapEntry(
        for node: Markup,
        atOffset offset: Int,
        inResult result: NSMutableAttributedString
    ) {
        guard let range = node.range else { return }
        let length = result.length - offset
        guard length > 0 else { return }

        let nodeType: NodeType? = nodeType(for: node)
        guard let nodeType else { return }

        let attrRange = NSRange(location: offset, length: length)
        // swift-markdown SourceRange is 1-based inclusive on both ends.
        // Convert to 0-based half-open range: lower - 1 for 0-based start,
        // upper stays as-is to form the exclusive upper bound.
        let sourceLineRange = (range.lowerBound.line - 1)..<range.upperBound.line

        sourceMap.addEntry(
            attributedStringRange: attrRange,
            sourceLineRange: sourceLineRange,
            nodeType: nodeType
        )
    }

    /// Maps a Markup node to a `NodeType` for source map entries.
    /// Returns nil for nodes that don't map to tracked block types.
    private func nodeType(for node: Markup) -> NodeType? {
        switch node {
        case let heading as Heading:
            return .heading(level: heading.level)
        case is Paragraph:
            return .paragraph
        case is CodeBlock:
            return .codeBlock
        case is BlockQuote:
            return .blockquote
        case is OrderedList, is UnorderedList:
            return .list
        case is ListItem:
            return .listItem
        case is Table:
            return .table
        case is ThematicBreak:
            return .thematicBreak
        case is HTMLBlock:
            return .htmlBlock
        default:
            return nil
        }
    }
}
