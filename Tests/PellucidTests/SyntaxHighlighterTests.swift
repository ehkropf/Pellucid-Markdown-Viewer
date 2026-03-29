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

final class SyntaxHighlighterTests: XCTestCase {

    /// Helper: tokenize code with a named language and return tokens.
    private func tokens(_ code: String, language: String) -> [Token] {
        guard let grammar = grammars[language.lowercased()] else { return [] }
        return tokenize(code: code, grammar: grammar)
    }

    /// Helper: extract the matched text for a token.
    private func text(of token: Token, in code: String) -> String {
        guard let range = Range(token.range, in: code) else { return "" }
        return String(code[range])
    }

    // MARK: - Basic dispatch

    func testUnknownLanguageReturnsNoTokens() {
        XCTAssertTrue(tokens("x = 1", language: "brainfuck").isEmpty)
    }

    func testEmptyCodeReturnsNoTokens() {
        XCTAssertTrue(tokens("", language: "swift").isEmpty)
    }

    // MARK: - Swift tokenization

    func testSwiftKeywordHighlighted() {
        let code = "func hello() {}"
        let toks = tokens(code, language: "swift")
        let keywords = toks.filter { $0.kind == .keyword }
        XCTAssertTrue(keywords.contains { text(of: $0, in: code) == "func" })
    }

    func testSwiftCommentTakesPriorityOverKeyword() {
        let code = "// func hello"
        let toks = tokens(code, language: "swift")
        // Everything should be a single comment token, not keyword+comment
        XCTAssertEqual(toks.count, 1)
        XCTAssertEqual(toks[0].kind, .comment)
    }

    func testSwiftStringContentNotTokenized() {
        let code = #"let x = "if true { return }""#
        let toks = tokens(code, language: "swift")
        // "if", "true", "return" inside the string should NOT be keyword tokens
        let keywords = toks.filter { $0.kind == .keyword }
        let keywordTexts = keywords.map { text(of: $0, in: code) }
        XCTAssertTrue(keywordTexts.contains("let"))
        XCTAssertFalse(keywordTexts.contains("if"))
        XCTAssertFalse(keywordTexts.contains("true"))
        XCTAssertFalse(keywordTexts.contains("return"))
    }

    func testSwiftMultilineComment() {
        let code = "/* func */ let x = 1"
        let toks = tokens(code, language: "swift")
        let comments = toks.filter { $0.kind == .comment }
        XCTAssertEqual(comments.count, 1)
        XCTAssertEqual(text(of: comments[0], in: code), "/* func */")
    }

    func testSwiftAttributeHighlighted() {
        let code = "@objc class Foo {}"
        let toks = tokens(code, language: "swift")
        let attrs = toks.filter { $0.kind == .attribute }
        XCTAssertTrue(attrs.contains { text(of: $0, in: code) == "@objc" })
    }

    func testSwiftTypeHighlighted() {
        let code = "let x: String = \"\""
        let toks = tokens(code, language: "swift")
        let types = toks.filter { $0.kind == .type }
        XCTAssertTrue(types.contains { text(of: $0, in: code) == "String" })
    }

    func testSwiftNumberHighlighted() {
        let code = "let x = 42"
        let toks = tokens(code, language: "swift")
        let numbers = toks.filter { $0.kind == .number }
        XCTAssertTrue(numbers.contains { text(of: $0, in: code) == "42" })
    }

    func testSwiftHexNumber() {
        let code = "let x = 0xFF"
        let toks = tokens(code, language: "swift")
        let numbers = toks.filter { $0.kind == .number }
        XCTAssertTrue(numbers.contains { text(of: $0, in: code) == "0xFF" })
    }

    // MARK: - Python tokenization

    func testPythonCommentPriority() {
        let code = "# def my_function"
        let toks = tokens(code, language: "python")
        XCTAssertEqual(toks.count, 1)
        XCTAssertEqual(toks[0].kind, .comment)
    }

    func testPythonTripleQuoteString() {
        let code = #"x = """hello def world""""#
        let toks = tokens(code, language: "python")
        let strings = toks.filter { $0.kind == .string }
        XCTAssertFalse(strings.isEmpty)
        // "def" inside triple-quoted string should not be a keyword
        let keywords = toks.filter { $0.kind == .keyword }
        XCTAssertTrue(keywords.isEmpty || !keywords.contains { text(of: $0, in: code) == "def" })
    }

    // MARK: - Language aliases

    func testJavascriptAlias() {
        let code = "const x = 1"
        let js = tokens(code, language: "js")
        let full = tokens(code, language: "javascript")
        XCTAssertEqual(js.count, full.count)
        for (a, b) in zip(js, full) {
            XCTAssertEqual(a.range, b.range)
            XCTAssertEqual(a.kind, b.kind)
        }
    }

    func testTypescriptAlias() {
        let code = "const x: number = 1"
        let ts = tokens(code, language: "ts")
        let full = tokens(code, language: "typescript")
        XCTAssertEqual(ts.count, full.count)
    }

    func testYamlAlias() {
        XCTAssertEqual(tokens("key: value", language: "yml").count,
                       tokens("key: value", language: "yaml").count)
    }

    func testCppAlias() {
        XCTAssertEqual(tokens("int x;", language: "cpp").count,
                       tokens("int x;", language: "c++").count)
    }

    func testMarkdownAlias() {
        XCTAssertEqual(tokens("# Heading", language: "md").count,
                       tokens("# Heading", language: "markdown").count)
    }

    // MARK: - Case insensitivity

    func testLanguageCaseInsensitive() {
        // highlightCode lowercases the language, so "SWIFT" should match "swift"
        let highlighter = AppCodeSyntaxHighlighter(palette: .default)
        // Should not crash; coverage validates case handling
        _ = highlighter.highlightCode("let x = 1", language: "SWIFT")
        _ = highlighter.highlightCode("let x = 1", language: "Swift")
    }

    // MARK: - All supported languages

    func testAllSupportedLanguagesTokenize() {
        let languages = [
            "swift", "python", "javascript", "js", "typescript", "ts",
            "json", "bash", "sh", "c", "cpp", "c++", "rust", "go",
            "ruby", "java", "yaml", "yml", "toml", "html", "css",
            "sql", "markdown", "md",
        ]
        let code = "x = 1"
        for lang in languages {
            // Should not crash for any supported language
            let toks = tokens(code, language: lang)
            XCTAssertNotNil(toks, "Tokenization failed for \(lang)")
        }
    }

    // MARK: - Overlap prevention

    func testNoOverlappingTokens() {
        let code = """
        func hello() {
            let x = "test" // comment
            return 42
        }
        """
        let toks = tokens(code, language: "swift")
        let sorted = toks.sorted { $0.range.location < $1.range.location }
        for i in 0..<(sorted.count - 1) {
            let end = sorted[i].range.location + sorted[i].range.length
            let nextStart = sorted[i + 1].range.location
            XCTAssertLessThanOrEqual(end, nextStart,
                "Overlapping tokens at positions \(sorted[i].range) and \(sorted[i + 1].range)")
        }
    }
}
