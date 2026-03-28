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

/// Walks the swift-markdown AST and extracts headings into a nested TOCEntry tree.
struct TOCExtractor: MarkupWalker {
    private var flatEntries: [(level: Int, title: String, id: String)] = []

    static func extractTOC(from document: Document) -> [TOCEntry] {
        var extractor = TOCExtractor()
        extractor.visit(document)
        return buildTree(from: extractor.flatEntries)
    }

    mutating func visitHeading(_ heading: Heading) {
        let title = heading.plainText
        let id = slugify(title)
        flatEntries.append((level: heading.level, title: title, id: id))
        descendInto(heading)
    }

    /// Build a nested tree from a flat heading list.
    /// Consumes entries recursively: children are entries with level > parent's level,
    /// stopping when we hit a same-or-lower level entry.
    private static func buildTree(
        from entries: [(level: Int, title: String, id: String)]
    ) -> [TOCEntry] {
        var index = 0
        return buildChildren(from: entries, index: &index, parentLevel: 0)
    }

    private static func buildChildren(
        from entries: [(level: Int, title: String, id: String)],
        index: inout Int,
        parentLevel: Int
    ) -> [TOCEntry] {
        var result: [TOCEntry] = []
        while index < entries.count, entries[index].level > parentLevel {
            let entry = entries[index]
            index += 1
            let children = buildChildren(from: entries, index: &index, parentLevel: entry.level)
            result.append(TOCEntry(
                id: entry.id,
                level: entry.level,
                title: entry.title,
                children: children
            ))
        }
        return result
    }
}

// MARK: - Heading plain text extraction

extension Heading {
    /// Extracts the plain text content, stripping inline markup.
    /// Matches MarkdownUI's `renderPlainText()` behavior.
    var plainText: String {
        children.compactMap { extractPlainText(from: $0) }.joined()
    }
}

private func extractPlainText(from markup: any Markup) -> String? {
    if let text = markup as? Markdown.Text {
        return text.string
    } else if let code = markup as? InlineCode {
        return code.code
    } else if markup is SoftBreak {
        return " "
    } else if markup is LineBreak {
        return "\n"
    } else if let container = markup as? (any InlineContainer) {
        return container.children.compactMap { extractPlainText(from: $0) }.joined()
    }
    return nil
}
