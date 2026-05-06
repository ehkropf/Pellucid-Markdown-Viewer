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

final class SourceMapTests: XCTestCase {

    // MARK: - Empty map

    func testEmptyMapSourceLinesReturnsNil() {
        let map = SourceMap()
        XCTAssertNil(map.sourceLines(for: NSRange(location: 0, length: 10)))
    }

    func testEmptyMapCharacterRangeReturnsNil() {
        let map = SourceMap()
        XCTAssertNil(map.characterRange(for: 0))
    }

    func testEmptyMapEntryAtReturnsNil() {
        let map = SourceMap()
        XCTAssertNil(map.entry(at: 0))
    }

    func testEmptyMapProperties() {
        let map = SourceMap()
        XCTAssertTrue(map.isEmpty)
        XCTAssertEqual(map.count, 0)
    }

    // MARK: - Single entry

    func testSingleEntrySourceLines() {
        var map = SourceMap()
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 20),
            sourceLineRange: 0..<3,
            nodeType: .heading(level: 1)
        )

        // Exact match
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 0, length: 20)), 0..<3)
        // Partial overlap from start
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 0, length: 5)), 0..<3)
        // Partial overlap from middle
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 5, length: 5)), 0..<3)
        // Partial overlap at end
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 15, length: 10)), 0..<3)
        // No overlap before
        XCTAssertNil(map.sourceLines(for: NSRange(location: 20, length: 5)))
        // No overlap — zero-length range at boundary
        XCTAssertNil(map.sourceLines(for: NSRange(location: 20, length: 0)))
    }

    func testSingleEntryCharacterRange() {
        var map = SourceMap()
        map.addEntry(
            attributedStringRange: NSRange(location: 10, length: 30),
            sourceLineRange: 5..<8,
            nodeType: .paragraph
        )

        // Line within range
        XCTAssertEqual(map.characterRange(for: 5), NSRange(location: 10, length: 30))
        XCTAssertEqual(map.characterRange(for: 6), NSRange(location: 10, length: 30))
        XCTAssertEqual(map.characterRange(for: 7), NSRange(location: 10, length: 30))
        // Line outside range
        XCTAssertNil(map.characterRange(for: 4))
        XCTAssertNil(map.characterRange(for: 8))
    }

    func testSingleEntryAt() {
        var map = SourceMap()
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 50),
            sourceLineRange: 0..<5,
            nodeType: .codeBlock
        )

        // Within range
        let result = map.entry(at: 25)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.nodeType, .codeBlock)
        XCTAssertEqual(result?.sourceLineRange, 0..<5)

        // At start boundary
        XCTAssertNotNil(map.entry(at: 0))
        // At last valid index
        XCTAssertNotNil(map.entry(at: 49))
        // Past end
        XCTAssertNil(map.entry(at: 50))
        // Before start (only relevant if entry doesn't start at 0)
    }

    func testSingleEntryProperties() {
        var map = SourceMap()
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 10),
            sourceLineRange: 0..<1,
            nodeType: .paragraph
        )
        XCTAssertFalse(map.isEmpty)
        XCTAssertEqual(map.count, 1)
    }

    // MARK: - Multiple entries

    /// Helper to build a map simulating a typical document:
    ///   - Heading at chars 0..<15, source lines 0..<1
    ///   - Paragraph at chars 15..<60, source lines 2..<5
    ///   - Code block at chars 60..<120, source lines 6..<12
    ///   - Paragraph at chars 120..<180, source lines 13..<16
    private func typicalMap() -> SourceMap {
        var map = SourceMap()
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 15),
            sourceLineRange: 0..<1,
            nodeType: .heading(level: 1)
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 15, length: 45),
            sourceLineRange: 2..<5,
            nodeType: .paragraph
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 60, length: 60),
            sourceLineRange: 6..<12,
            nodeType: .codeBlock
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 120, length: 60),
            sourceLineRange: 13..<16,
            nodeType: .paragraph
        )
        return map
    }

    func testMultipleEntriesSourceLinesExactMatch() {
        let map = typicalMap()
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 0, length: 15)), 0..<1)
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 60, length: 60)), 6..<12)
    }

    func testMultipleEntriesSourceLinesSpanningEntries() {
        let map = typicalMap()
        // Selection spanning heading + paragraph
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 10, length: 20)), 0..<5)
        // Selection spanning all entries
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 0, length: 180)), 0..<16)
        // Selection spanning code block + second paragraph
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 100, length: 50)), 6..<16)
    }

    func testMultipleEntriesSourceLinesNoOverlap() {
        let map = typicalMap()
        // Beyond all entries
        XCTAssertNil(map.sourceLines(for: NSRange(location: 200, length: 10)))
    }

    func testMultipleEntriesCharacterRange() {
        let map = typicalMap()
        // Each source line maps to the correct entry
        XCTAssertEqual(map.characterRange(for: 0), NSRange(location: 0, length: 15))
        XCTAssertEqual(map.characterRange(for: 3), NSRange(location: 15, length: 45))
        XCTAssertEqual(map.characterRange(for: 10), NSRange(location: 60, length: 60))
        XCTAssertEqual(map.characterRange(for: 14), NSRange(location: 120, length: 60))
        // Line in gap between entries (line 1 — between heading and paragraph)
        XCTAssertNil(map.characterRange(for: 1))
        // Line beyond all entries
        XCTAssertNil(map.characterRange(for: 20))
    }

    func testMultipleEntriesEntryAt() {
        let map = typicalMap()

        // First entry
        let first = map.entry(at: 5)
        XCTAssertEqual(first?.nodeType, .heading(level: 1))

        // Second entry
        let second = map.entry(at: 30)
        XCTAssertEqual(second?.nodeType, .paragraph)

        // Third entry
        let third = map.entry(at: 80)
        XCTAssertEqual(third?.nodeType, .codeBlock)

        // Fourth entry
        let fourth = map.entry(at: 150)
        XCTAssertEqual(fourth?.nodeType, .paragraph)

        // Past all entries
        XCTAssertNil(map.entry(at: 200))
    }

    // MARK: - Insertion order independence

    func testOutOfOrderInsertionMaintainsSortOrder() {
        var map = SourceMap()
        // Insert in reverse order
        map.addEntry(
            attributedStringRange: NSRange(location: 100, length: 50),
            sourceLineRange: 10..<15,
            nodeType: .paragraph
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 20),
            sourceLineRange: 0..<2,
            nodeType: .heading(level: 1)
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 50, length: 30),
            sourceLineRange: 5..<8,
            nodeType: .codeBlock
        )

        // Verify sorted order
        XCTAssertEqual(map.entries[0].attributedStringRange.location, 0)
        XCTAssertEqual(map.entries[1].attributedStringRange.location, 50)
        XCTAssertEqual(map.entries[2].attributedStringRange.location, 100)

        // Verify queries still work
        XCTAssertEqual(map.entry(at: 10)?.nodeType, .heading(level: 1))
        XCTAssertEqual(map.entry(at: 60)?.nodeType, .codeBlock)
        XCTAssertEqual(map.entry(at: 120)?.nodeType, .paragraph)
    }

    // MARK: - Boundary conditions

    func testEntryAtBoundariesBetweenEntries() {
        var map = SourceMap()
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 10),
            sourceLineRange: 0..<1,
            nodeType: .heading(level: 1)
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 10, length: 10),
            sourceLineRange: 2..<3,
            nodeType: .paragraph
        )

        // Last char of first entry
        XCTAssertEqual(map.entry(at: 9)?.nodeType, .heading(level: 1))
        // First char of second entry
        XCTAssertEqual(map.entry(at: 10)?.nodeType, .paragraph)
    }

    func testSourceLinesWithGapBetweenEntries() {
        var map = SourceMap()
        // Gap in attributed string between entries (chars 10..<20 unmapped)
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 10),
            sourceLineRange: 0..<2,
            nodeType: .heading(level: 1)
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 20, length: 10),
            sourceLineRange: 4..<6,
            nodeType: .paragraph
        )

        // Selection in the gap
        XCTAssertNil(map.sourceLines(for: NSRange(location: 12, length: 5)))
        // Selection spanning gap and second entry
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 12, length: 15)), 4..<6)
        // Selection spanning first entry and gap
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 5, length: 10)), 0..<2)
        // Selection spanning both entries (across gap)
        XCTAssertEqual(map.sourceLines(for: NSRange(location: 5, length: 22)), 0..<6)
    }

    func testEntryAtInGapReturnsNil() {
        var map = SourceMap()
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 10),
            sourceLineRange: 0..<1,
            nodeType: .heading(level: 1)
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 20, length: 10),
            sourceLineRange: 3..<4,
            nodeType: .paragraph
        )

        XCTAssertNil(map.entry(at: 15))
    }

    // MARK: - NodeType variants

    func testAllNodeTypes() {
        var map = SourceMap()
        let types: [NodeType] = [
            .heading(level: 1), .heading(level: 2), .heading(level: 3),
            .heading(level: 4), .heading(level: 5), .heading(level: 6),
            .paragraph, .codeBlock, .blockquote, .list, .listItem,
            .table, .thematicBreak, .image, .math, .htmlBlock,
        ]

        for (i, nodeType) in types.enumerated() {
            map.addEntry(
                attributedStringRange: NSRange(location: i * 100, length: 80),
                sourceLineRange: (i * 10)..<(i * 10 + 5),
                nodeType: nodeType
            )
        }

        XCTAssertEqual(map.count, types.count)

        // Verify each type is retrievable
        for (i, expectedType) in types.enumerated() {
            let result = map.entry(at: i * 100 + 40)
            XCTAssertEqual(result?.nodeType, expectedType,
                           "Mismatch at index \(i)")
        }
    }

    func testHeadingLevelEquality() {
        XCTAssertEqual(NodeType.heading(level: 1), NodeType.heading(level: 1))
        XCTAssertNotEqual(NodeType.heading(level: 1), NodeType.heading(level: 2))
        XCTAssertNotEqual(NodeType.heading(level: 1), NodeType.paragraph)
    }

    // MARK: - SourceMapEntry Equatable

    func testSourceMapEntryEquality() {
        let entry1 = SourceMapEntry(
            attributedStringRange: NSRange(location: 0, length: 10),
            sourceLineRange: 0..<2,
            nodeType: .paragraph
        )
        let entry2 = SourceMapEntry(
            attributedStringRange: NSRange(location: 0, length: 10),
            sourceLineRange: 0..<2,
            nodeType: .paragraph
        )
        let entry3 = SourceMapEntry(
            attributedStringRange: NSRange(location: 0, length: 10),
            sourceLineRange: 0..<2,
            nodeType: .codeBlock
        )

        XCTAssertEqual(entry1, entry2)
        XCTAssertNotEqual(entry1, entry3)
    }

    // MARK: - characterRange returns first match

    func testCharacterRangeReturnsFirstMatchForOverlappingSourceLines() {
        var map = SourceMap()
        // Two entries that cover the same source line (e.g., nested list items)
        map.addEntry(
            attributedStringRange: NSRange(location: 0, length: 50),
            sourceLineRange: 0..<5,
            nodeType: .list
        )
        map.addEntry(
            attributedStringRange: NSRange(location: 50, length: 30),
            sourceLineRange: 3..<7,
            nodeType: .listItem
        )

        // Source line 3 is in both entries; should return the first one
        let result = map.characterRange(for: 3)
        XCTAssertEqual(result, NSRange(location: 0, length: 50))
    }

    // MARK: - Zero-length attributed string range

    func testZeroLengthAttributedStringRange() {
        var map = SourceMap()
        // A thematic break might render as zero-length or very small
        map.addEntry(
            attributedStringRange: NSRange(location: 50, length: 0),
            sourceLineRange: 5..<6,
            nodeType: .thematicBreak
        )

        // entry(at:) should not match zero-length ranges
        XCTAssertNil(map.entry(at: 50))

        // characterRange should still find it by source line
        XCTAssertEqual(map.characterRange(for: 5), NSRange(location: 50, length: 0))

        // sourceLines with zero-length query range should not match
        XCTAssertNil(map.sourceLines(for: NSRange(location: 50, length: 0)))
    }

    // MARK: - Large map performance (sanity check)

    func testLargeMapEntryLookupPerformance() {
        var map = SourceMap()
        let entryCount = 10_000

        for i in 0..<entryCount {
            map.addEntry(
                attributedStringRange: NSRange(location: i * 100, length: 80),
                sourceLineRange: (i * 5)..<(i * 5 + 3),
                nodeType: .paragraph
            )
        }

        XCTAssertEqual(map.count, entryCount)

        // Binary search should find entry near the end quickly
        let result = map.entry(at: 9_999 * 100 + 40)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sourceLineRange, (9_999 * 5)..<(9_999 * 5 + 3))

        // Verify first and last entries
        XCTAssertNotNil(map.entry(at: 0))
        XCTAssertNotNil(map.entry(at: (entryCount - 1) * 100 + 40))
        XCTAssertNil(map.entry(at: entryCount * 100))
    }
}
