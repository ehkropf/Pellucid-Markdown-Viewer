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

import Markdown

enum SourceBlockType: Sendable {
    case heading
    case paragraph
    case codeBlock
    case blockquote
    case listItem
    case table
    case thematicBreak
}

struct SourceLocationEntry: Sendable {
    let blockType: SourceBlockType
    let contentKey: String
    let line: Int
}

/// Maps rendered block content back to source line numbers by walking the swift-markdown AST.
struct SourceLocationMap: Sendable {
    static let empty = SourceLocationMap(entries: [])

    private let entries: [SourceLocationEntry]

    init(entries: [SourceLocationEntry]) {
        self.entries = entries
    }

    static func extract(from document: Document) -> SourceLocationMap {
        var walker = SourceLocationWalker()
        walker.visit(document)
        return SourceLocationMap(entries: walker.entries)
    }

    /// Find the source line for a block matching the given type and content key.
    /// Returns nil if no match is found.
    func sourceLine(for blockType: SourceBlockType, contentKey: String) -> Int? {
        entries.first { $0.blockType == blockType && $0.contentKey == contentKey }?.line
    }
}

// MARK: - AST Walker

private struct SourceLocationWalker: MarkupWalker {
    var entries: [SourceLocationEntry] = []
    private var thematicBreakCount = 0

    mutating func visitHeading(_ heading: Heading) {
        if let line = heading.range?.lowerBound.line {
            let text = heading.plainText
            entries.append(SourceLocationEntry(blockType: .heading, contentKey: text, line: line))
        }
        descendInto(heading)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if let line = paragraph.range?.lowerBound.line {
            let text = paragraph.children.compactMap { extractInlineText(from: $0) }.joined()
            let key = String(text.prefix(200))
            entries.append(SourceLocationEntry(blockType: .paragraph, contentKey: key, line: line))
        }
        descendInto(paragraph)
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        if let line = codeBlock.range?.lowerBound.line {
            let key = String(codeBlock.code.prefix(200))
            entries.append(SourceLocationEntry(blockType: .codeBlock, contentKey: key, line: line))
        }
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        if let line = blockQuote.range?.lowerBound.line {
            let text = blockQuote.children.compactMap { child -> String? in
                guard let paragraph = child as? Paragraph else { return nil }
                return paragraph.children.compactMap { extractInlineText(from: $0) }.joined()
            }.joined(separator: " ")
            let key = String(text.prefix(200))
            entries.append(SourceLocationEntry(blockType: .blockquote, contentKey: key, line: line))
        }
        descendInto(blockQuote)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        if let line = listItem.range?.lowerBound.line {
            let text = listItem.children.compactMap { child -> String? in
                guard let paragraph = child as? Paragraph else { return nil }
                return paragraph.children.compactMap { extractInlineText(from: $0) }.joined()
            }.joined(separator: " ")
            let key = String(text.prefix(200))
            entries.append(SourceLocationEntry(blockType: .listItem, contentKey: key, line: line))
        }
        descendInto(listItem)
    }

    mutating func visitTable(_ table: Markdown.Table) {
        if let line = table.range?.lowerBound.line {
            let firstCell = table.head.cells.first(where: { _ in true })
            let text = firstCell.map { cell in
                cell.children.compactMap { extractInlineText(from: $0) }.joined()
            } ?? ""
            let key = String(text.prefix(200))
            entries.append(SourceLocationEntry(blockType: .table, contentKey: key, line: line))
        }
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        if let line = thematicBreak.range?.lowerBound.line {
            entries.append(SourceLocationEntry(blockType: .thematicBreak, contentKey: "\(thematicBreakCount)", line: line))
            thematicBreakCount += 1
        }
    }
}
