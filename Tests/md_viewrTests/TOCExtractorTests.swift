// md_viewr — Native macOS markdown viewer
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
@testable import md_viewr

final class TOCExtractorTests: XCTestCase {

    private func extractTOC(_ markdown: String) -> [TOCEntry] {
        let doc = Document(parsing: markdown)
        return TOCExtractor.extractTOC(from: doc)
    }

    // MARK: - Basic extraction

    func testEmptyDocument() {
        XCTAssertEqual(extractTOC(""), [])
    }

    func testNoHeadings() {
        XCTAssertEqual(extractTOC("Just a paragraph.\n\nAnother one."), [])
    }

    func testSingleHeading() {
        let toc = extractTOC("# Hello World")
        XCTAssertEqual(toc.count, 1)
        XCTAssertEqual(toc[0].title, "Hello World")
        XCTAssertEqual(toc[0].id, "hello-world")
        XCTAssertEqual(toc[0].level, 1)
        XCTAssertTrue(toc[0].children.isEmpty)
    }

    func testFlatSameLevel() {
        let toc = extractTOC("""
        ## First
        ## Second
        ## Third
        """)
        XCTAssertEqual(toc.count, 3)
        XCTAssertEqual(toc[0].title, "First")
        XCTAssertEqual(toc[1].title, "Second")
        XCTAssertEqual(toc[2].title, "Third")
        XCTAssertTrue(toc.allSatisfy { $0.children.isEmpty })
    }

    // MARK: - Tree structure

    func testNestedHeadings() {
        let toc = extractTOC("""
        # Top
        ## Child 1
        ## Child 2
        ### Grandchild
        """)
        XCTAssertEqual(toc.count, 1)
        XCTAssertEqual(toc[0].title, "Top")
        XCTAssertEqual(toc[0].children.count, 2)
        XCTAssertEqual(toc[0].children[0].title, "Child 1")
        XCTAssertEqual(toc[0].children[1].title, "Child 2")
        XCTAssertEqual(toc[0].children[1].children.count, 1)
        XCTAssertEqual(toc[0].children[1].children[0].title, "Grandchild")
    }

    func testSkippedLevels() {
        // H1 followed directly by H3 (no H2)
        let toc = extractTOC("""
        # Top
        ### Deep
        """)
        XCTAssertEqual(toc.count, 1)
        XCTAssertEqual(toc[0].children.count, 1)
        XCTAssertEqual(toc[0].children[0].title, "Deep")
        XCTAssertEqual(toc[0].children[0].level, 3)
    }

    func testMultipleTopLevel() {
        let toc = extractTOC("""
        # First
        ## Sub
        # Second
        """)
        XCTAssertEqual(toc.count, 2)
        XCTAssertEqual(toc[0].title, "First")
        XCTAssertEqual(toc[0].children.count, 1)
        XCTAssertEqual(toc[1].title, "Second")
        XCTAssertTrue(toc[1].children.isEmpty)
    }

    // MARK: - Inline markup in headings

    func testBoldHeading() {
        let toc = extractTOC("## **Bold** Heading")
        XCTAssertEqual(toc[0].title, "Bold Heading")
        XCTAssertEqual(toc[0].id, slugify("Bold Heading"))
    }

    func testItalicHeading() {
        let toc = extractTOC("## *Italic* Heading")
        XCTAssertEqual(toc[0].title, "Italic Heading")
    }

    func testInlineCodeHeading() {
        let toc = extractTOC("## Using `map` Function")
        XCTAssertEqual(toc[0].title, "Using map Function")
        XCTAssertEqual(toc[0].id, slugify("Using map Function"))
    }

    func testNestedInlineMarkup() {
        let toc = extractTOC("## ***Bold Italic*** Text")
        XCTAssertEqual(toc[0].title, "Bold Italic Text")
    }

    func testAscendingLevelAfterDeepNesting() {
        // H1 -> H3 -> H2: the H2 should pop back up as a child of H1
        let toc = extractTOC("""
        # Top
        ### Deep
        ## Mid
        """)
        XCTAssertEqual(toc.count, 1)
        XCTAssertEqual(toc[0].children.count, 2)
        XCTAssertEqual(toc[0].children[0].title, "Deep")
        XCTAssertEqual(toc[0].children[0].level, 3)
        XCTAssertEqual(toc[0].children[1].title, "Mid")
        XCTAssertEqual(toc[0].children[1].level, 2)
    }

    func testDocumentStartingAtH3() {
        // No H1 or H2 — all become top-level entries
        let toc = extractTOC("""
        ### First
        ### Second
        """)
        XCTAssertEqual(toc.count, 2)
        XCTAssertEqual(toc[0].title, "First")
        XCTAssertEqual(toc[1].title, "Second")
    }

    func testHeadingWithLink() {
        let toc = extractTOC("## [Link Text](https://example.com)")
        XCTAssertEqual(toc[0].title, "Link Text")
        XCTAssertEqual(toc[0].id, slugify("Link Text"))
    }

    func testHeadingWithStrikethrough() {
        let toc = extractTOC("## ~~deleted~~ text")
        XCTAssertEqual(toc[0].title, "deleted text")
    }

    // MARK: - ID alignment with slugify

    func testIDMatchesSlugify() {
        let headings = [
            "Hello World",
            "Step 1: Setup",
            "What's New?",
            "C++ and C#",
        ]
        for heading in headings {
            let toc = extractTOC("# \(heading)")
            XCTAssertEqual(toc[0].id, slugify(heading), "ID mismatch for heading: \(heading)")
        }
    }
}
