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

import Foundation

/// Type of markdown block node represented by a source map entry.
enum NodeType: Sendable, Equatable {
    case heading(level: Int)
    case paragraph
    case codeBlock
    case blockquote
    case list
    case listItem
    case table
    case thematicBreak
    case image
    case math
    case htmlBlock
}

/// A single entry in the source map, linking a range of characters in the
/// rendered NSAttributedString to a range of lines in the source markdown.
struct SourceMapEntry: Sendable, Equatable {
    /// Character range within the NSAttributedString.
    let attributedStringRange: NSRange
    /// 0-based source line range in the original markdown.
    let sourceLineRange: Range<Int>
    /// The type of markdown node this entry represents.
    let nodeType: NodeType
}

/// Bidirectional mapping between NSAttributedString character ranges and
/// source markdown line offsets. Entries are maintained in sorted order by
/// attributed string position, enabling efficient binary search lookups.
///
/// Populated during rendering by calling `addEntry(...)` for each block-level
/// node, then queried for copy-as-markdown, scroll-to-heading, and
/// Cmd+click-to-editor features.
struct SourceMap: Sendable {

    /// Entries sorted by `attributedStringRange.location`.
    private(set) var entries: [SourceMapEntry] = []

    /// Whether the source map contains no entries.
    var isEmpty: Bool { entries.isEmpty }

    /// The number of entries in the source map.
    var count: Int { entries.count }

    // MARK: - Builder

    /// Adds an entry, maintaining sort order by attributed string location.
    ///
    /// - Parameters:
    ///   - attributedStringRange: The character range in the attributed string.
    ///   - sourceLineRange: The 0-based line range in the source markdown.
    ///   - nodeType: The type of markdown block node.
    mutating func addEntry(
        attributedStringRange: NSRange,
        sourceLineRange: Range<Int>,
        nodeType: NodeType
    ) {
        let entry = SourceMapEntry(
            attributedStringRange: attributedStringRange,
            sourceLineRange: sourceLineRange,
            nodeType: nodeType
        )

        // Insert in sorted order by location for binary search.
        let index = insertionIndex(for: attributedStringRange.location)
        entries.insert(entry, at: index)
    }

    // MARK: - Queries

    /// Returns the source line range that overlaps the given character range
    /// in the attributed string. Used for copy-as-markdown: selection range
    /// to source lines.
    ///
    /// When the character range spans multiple entries, the returned range
    /// is the union of all overlapping source line ranges.
    func sourceLines(for characterRange: NSRange) -> Range<Int>? {
        guard !entries.isEmpty else { return nil }

        var lowerBound: Int?
        var upperBound: Int?

        for entry in entries {
            if NSIntersectionRange(entry.attributedStringRange, characterRange).length > 0 {
                let lo = entry.sourceLineRange.lowerBound
                let hi = entry.sourceLineRange.upperBound
                if let currentLo = lowerBound {
                    lowerBound = min(currentLo, lo)
                } else {
                    lowerBound = lo
                }
                if let currentHi = upperBound {
                    upperBound = max(currentHi, hi)
                } else {
                    upperBound = hi
                }
            }
        }

        guard let lo = lowerBound, let hi = upperBound else { return nil }
        return lo..<hi
    }

    /// Returns the character range in the attributed string that corresponds
    /// to the given source line. Used for scroll-to-heading: TOC line offset
    /// to scrollRangeToVisible.
    ///
    /// If multiple entries contain the source line, returns the first match.
    func characterRange(for sourceLine: Int) -> NSRange? {
        for entry in entries {
            if entry.sourceLineRange.contains(sourceLine) {
                return entry.attributedStringRange
            }
        }
        return nil
    }

    /// Returns the entry at the given character index in the attributed
    /// string. Used for Cmd+click: click position to node info.
    func entry(at characterIndex: Int) -> SourceMapEntry? {
        guard !entries.isEmpty else { return nil }

        // Binary search for the entry whose range contains characterIndex.
        var lo = 0
        var hi = entries.count - 1

        while lo <= hi {
            let mid = lo + (hi - lo) / 2
            let range = entries[mid].attributedStringRange
            let rangeEnd = range.location + range.length

            if characterIndex < range.location {
                if mid == 0 { break }
                hi = mid - 1
            } else if characterIndex >= rangeEnd {
                lo = mid + 1
            } else {
                // characterIndex is within this entry's range.
                return entries[mid]
            }
        }

        return nil
    }

    // MARK: - Private

    /// Binary search for the insertion index to maintain sort order by
    /// `attributedStringRange.location`.
    private func insertionIndex(for location: Int) -> Int {
        var lo = 0
        var hi = entries.count

        while lo < hi {
            let mid = lo + (hi - lo) / 2
            if entries[mid].attributedStringRange.location < location {
                lo = mid + 1
            } else {
                hi = mid
            }
        }

        return lo
    }
}
