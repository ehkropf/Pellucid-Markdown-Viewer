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

final class SourceLocationMapTests: XCTestCase {

    private func makeMap(_ markdown: String) -> SourceLocationMap {
        let doc = Document(parsing: markdown)
        return SourceLocationMap.extract(from: doc)
    }

    // MARK: - Headings

    func testHeadingSourceLine() {
        let map = makeMap("""
        # Title

        Some text.

        ## Subtitle
        """)
        XCTAssertEqual(map.sourceLine(for: .heading, contentKey: "Title"), 1)
        XCTAssertEqual(map.sourceLine(for: .heading, contentKey: "Subtitle"), 5)
    }

    func testHeadingWithInlineMarkup() {
        let map = makeMap("## **Bold** Heading")
        XCTAssertEqual(map.sourceLine(for: .heading, contentKey: "Bold Heading"), 1)
    }

    // MARK: - Paragraphs

    func testParagraphSourceLine() {
        let map = makeMap("""
        # Title

        First paragraph.

        Second paragraph.
        """)
        XCTAssertEqual(map.sourceLine(for: .paragraph, contentKey: "First paragraph."), 3)
        XCTAssertEqual(map.sourceLine(for: .paragraph, contentKey: "Second paragraph."), 5)
    }

    func testLongParagraphTruncated() {
        let longText = String(repeating: "word ", count: 100)
        let map = makeMap(longText)
        let key = String(longText.prefix(200))
        XCTAssertEqual(map.sourceLine(for: .paragraph, contentKey: key), 1)
    }

    // MARK: - Code blocks

    func testCodeBlockSourceLine() {
        let map = makeMap("""
        Some text.

        ```swift
        let x = 1
        ```
        """)
        XCTAssertEqual(map.sourceLine(for: .codeBlock, contentKey: "let x = 1\n"), 3)
    }

    // MARK: - Blockquotes

    func testBlockquoteSourceLine() {
        let map = makeMap("""
        Text before.

        > This is a quote.

        Text after.
        """)
        XCTAssertEqual(map.sourceLine(for: .blockquote, contentKey: "This is a quote."), 3)
    }

    // MARK: - List items

    func testListItemSourceLine() {
        let map = makeMap("""
        - First item
        - Second item
        - Third item
        """)
        XCTAssertEqual(map.sourceLine(for: .listItem, contentKey: "First item"), 1)
        XCTAssertEqual(map.sourceLine(for: .listItem, contentKey: "Second item"), 2)
        XCTAssertEqual(map.sourceLine(for: .listItem, contentKey: "Third item"), 3)
    }

    // MARK: - Tables

    func testTableSourceLine() {
        let map = makeMap("""
        | Name | Value |
        |------|-------|
        | foo  | bar   |
        """)
        XCTAssertEqual(map.sourceLine(for: .table, contentKey: "Name"), 1)
    }

    // MARK: - Thematic breaks

    func testThematicBreakSourceLine() {
        let map = makeMap("""
        Text above.

        ---

        Text below.

        ---
        """)
        XCTAssertEqual(map.sourceLine(for: .thematicBreak, contentKey: "0"), 3)
        XCTAssertEqual(map.sourceLine(for: .thematicBreak, contentKey: "1"), 7)
    }

    // MARK: - No match falls back to line 1

    func testNoMatchReturnsLine1() {
        let map = makeMap("# Title\n\nSome text.")
        XCTAssertEqual(map.sourceLine(for: .codeBlock, contentKey: "nonexistent"), 1)
    }

    func testEmptyMap() {
        let map = SourceLocationMap.empty
        XCTAssertEqual(map.sourceLine(for: .heading, contentKey: "anything"), 1)
    }
}
