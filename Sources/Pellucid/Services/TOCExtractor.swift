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
    private var flatEntries: [(level: Int, title: String, id: String, lineOffset: Int)] = []

    static func extractTOC(from document: Document) -> [TOCEntry] {
        var extractor = TOCExtractor()
        extractor.visit(document)
        return buildTree(from: extractor.flatEntries)
    }

    mutating func visitHeading(_ heading: Heading) {
        let title = heading.plainText
        let id = slugify(title)
        let line = (heading.range?.lowerBound.line ?? 1) - 1  // 0-based
        flatEntries.append((level: heading.level, title: title, id: id, lineOffset: line))
        descendInto(heading)
    }

    /// Build a nested tree from a flat heading list.
    /// Consumes entries recursively: children are entries with level > parent's level,
    /// stopping when we hit a same-or-lower level entry.
    private static func buildTree(
        from entries: [(level: Int, title: String, id: String, lineOffset: Int)]
    ) -> [TOCEntry] {
        var index = 0
        return buildChildren(from: entries, index: &index, parentLevel: 0)
    }

    private static func buildChildren(
        from entries: [(level: Int, title: String, id: String, lineOffset: Int)],
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
                lineOffset: entry.lineOffset,
                children: children
            ))
        }
        return result
    }
    // MARK: - Section extraction

    /// Flattens a nested TOCEntry tree into document order.
    static func flatten(_ entries: [TOCEntry]) -> [TOCEntry] {
        var result: [TOCEntry] = []
        for entry in entries {
            result.append(entry)
            result.append(contentsOf: flatten(entry.children))
        }
        return result
    }

    /// Extracts the raw markdown for the section starting at the given TOCEntry.
    /// The section spans from the entry's heading line to just before the next
    /// heading at the same or higher (lower number) level, or end of document.
    static func extractSection(for entry: TOCEntry, allEntries: [TOCEntry], rawMarkdown: String) -> String {
        let flat = flatten(allEntries)
        guard let idx = flat.firstIndex(where: { $0.id == entry.id && $0.lineOffset == entry.lineOffset }) else {
            return ""
        }

        let startLine = entry.lineOffset
        var endLine: Int? = nil

        for i in (idx + 1)..<flat.count {
            if flat[i].level <= entry.level {
                endLine = flat[i].lineOffset
                break
            }
        }

        let lines = rawMarkdown.components(separatedBy: "\n")
        let end = endLine ?? lines.count
        guard startLine < lines.count else { return "" }
        let sectionLines = lines[startLine..<min(end, lines.count)]

        // Trim trailing blank lines
        let trimmed = sectionLines.reversed().drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        return trimmed.reversed().joined(separator: "\n")
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
