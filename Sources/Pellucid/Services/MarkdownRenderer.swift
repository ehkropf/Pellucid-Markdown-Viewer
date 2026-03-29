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

    /// Marks code block ranges for custom background/border drawing (Step 4).
    static let codeBlockRange = NSAttributedString.Key("pellucid.codeBlockRange")

    /// Stores the 0-based source line range for Cmd+click → editor integration.
    static let sourceLineRange = NSAttributedString.Key("pellucid.sourceLineRange")
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
/// This implementation handles inline nodes. Block-level rendering (headings,
/// lists, blockquotes, etc.) will be added in Step 4.
struct MarkdownRenderer: MarkupVisitor {

    typealias Result = NSMutableAttributedString

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pellucid",
        category: "MarkdownRenderer"
    )

    // MARK: - State

    private let theme: AttributedStringTheme
    private var sourceMap = SourceMap()

    /// Font trait stack for composing bold/italic through nested inline markup.
    private var fontTraits: NSFontDescriptor.SymbolicTraits = []

    /// Whether we are currently inside a link (to suppress nested link styling).
    private var insideLink = false

    // MARK: - Public API

    /// Renders a markdown document into an attributed string with source mapping.
    ///
    /// - Parameters:
    ///   - document: A parsed swift-markdown `Document`.
    ///   - theme: The `AttributedStringTheme` controlling fonts and colors.
    /// - Returns: A `RenderResult` containing the attributed string and source map.
    static func render(document: Document, theme: AttributedStringTheme) -> RenderResult {
        var renderer = MarkdownRenderer(theme: theme)
        let result = renderer.visit(document)
        return RenderResult(
            attributedString: result,
            sourceMap: renderer.sourceMap
        )
    }

    private init(theme: AttributedStringTheme) {
        self.theme = theme
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
            .foregroundColor: theme.textColor,
        ]
    }

    // MARK: - MarkupVisitor — Document & Block Stubs

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
                // Separate top-level blocks with double-newline.
                result.append(NSAttributedString(string: "\n\n", attributes: currentAttributes))
            }
            let blockStart = result.length
            result.append(visit(child))

            // Record source map entry for block-level nodes that have source ranges.
            addSourceMapEntry(for: child, atOffset: blockStart, inResult: result)

            isFirstBlock = false
        }
        return result
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for child in paragraph.children {
            result.append(visit(child))
        }
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

        let placeholder = altText.isEmpty ? "[image]" : "[image: \(altText)]"
        return NSMutableAttributedString(string: placeholder, attributes: currentAttributes)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> NSMutableAttributedString {
        NSMutableAttributedString(string: " ", attributes: currentAttributes)
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> NSMutableAttributedString {
        NSMutableAttributedString(string: "\n", attributes: currentAttributes)
    }

    // MARK: - Helpers

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
