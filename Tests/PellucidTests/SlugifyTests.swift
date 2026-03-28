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

final class SlugifyTests: XCTestCase {
    func testBasicHeading() {
        XCTAssertEqual(slugify("Hello World"), "hello-world")
    }

    func testSingleWord() {
        XCTAssertEqual(slugify("Introduction"), "introduction")
    }

    func testPunctuation() {
        XCTAssertEqual(slugify("What's New?"), "what-s-new-")
    }

    func testNumbersPreserved() {
        XCTAssertEqual(slugify("Step 1 Setup"), "step-1-setup")
    }

    func testMixedCase() {
        XCTAssertEqual(slugify("CamelCase Heading"), "camelcase-heading")
    }

    func testMultipleSpaces() {
        // components(separatedBy:) splits each non-alphanumeric char individually
        XCTAssertEqual(slugify("Hello   World"), "hello---world")
    }

    func testSpecialCharacters() {
        XCTAssertEqual(slugify("C++ and C#"), "c---and-c-")
    }

    func testLeadingTrailingPunctuation() {
        XCTAssertEqual(slugify("--Introduction--"), "--introduction--")
    }

    func testEmptyString() {
        XCTAssertEqual(slugify(""), "")
    }

    func testHyphensPassThrough() {
        XCTAssertEqual(slugify("kebab-case-already"), "kebab-case-already")
    }

    func testNumbersOnly() {
        XCTAssertEqual(slugify("123"), "123")
    }

    func testColonInHeading() {
        XCTAssertEqual(slugify("Step 1: Setup"), "step-1--setup")
    }

    func testParentheses() {
        XCTAssertEqual(slugify("Function (deprecated)"), "function--deprecated-")
    }

    func testBacktickContent() {
        // Inline code backticks are stripped by plainText extraction before slugify
        // but if they reach slugify, they're treated as non-alphanumeric
        XCTAssertEqual(slugify("Using `map` in Swift"), "using--map--in-swift")
    }
}
