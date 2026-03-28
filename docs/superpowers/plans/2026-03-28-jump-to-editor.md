# Jump-to-Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cmd+click on any rendered markdown block opens the source file at that line in MacVim.

**Architecture:** A SourceLocationMap (MarkupWalker) maps rendered block content to source line numbers. Block style overrides wrap `configuration.label` with an `onTapGesture` that checks for Cmd modifier and calls MacVim via an ExternalEditor protocol. A shared ExecutableFinder utility resolves tool paths via PATH first, then known install locations.

**Tech Stack:** Swift 6, SwiftUI, swift-markdown AST, MarkdownUI block styles, XCTest

---

### Task 1: ExecutableFinder utility

**Files:**
- Create: `Sources/Pellucid/Utilities/ExecutableFinder.swift`
- Create: `Tests/PellucidTests/ExecutableFinderTests.swift`

- [ ] **Step 1: Create ExecutableFinder with tests**

`Sources/Pellucid/Utilities/ExecutableFinder.swift`:

```swift
// Pellucid — Native macOS markdown viewer
// Copyright (C) 2026 Everett Kropf
// [GPL header]

import Foundation

/// Finds an executable by name, trying PATH resolution first, then known install locations.
func findExecutable(named name: String, fallbackPaths: [String] = []) -> String? {
    // Try PATH resolution via `which`
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [name]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let result, !result.isEmpty, FileManager.default.isExecutableFile(atPath: result) {
            return result
        }
    } catch {
        // `which` not found or process launch failure — fall through to known paths
    }

    // Fall back to known install locations
    for path in fallbackPaths {
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }

    return nil
}
```

`Tests/PellucidTests/ExecutableFinderTests.swift`:

```swift
// Pellucid — Native macOS markdown viewer
// Copyright (C) 2026 Everett Kropf
// [GPL header]

import XCTest
@testable import Pellucid

final class ExecutableFinderTests: XCTestCase {

    func testFindsExecutableOnPath() {
        // `ls` should always be available on macOS
        let result = findExecutable(named: "ls")
        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: result!))
    }

    func testFallsBackToKnownPath() {
        // Use a name that won't be on PATH, with a fallback to a known executable
        let result = findExecutable(named: "nonexistent_tool_xyz", fallbackPaths: ["/bin/ls"])
        XCTAssertEqual(result, "/bin/ls")
    }

    func testReturnsNilWhenNotFound() {
        let result = findExecutable(named: "nonexistent_tool_xyz", fallbackPaths: ["/nonexistent/path"])
        XCTAssertNil(result)
    }

    func testPathResolutionTakesPrecedenceOverFallback() {
        // `ls` is on PATH; the fallback should not be used
        let result = findExecutable(named: "ls", fallbackPaths: ["/some/other/ls"])
        XCTAssertNotNil(result)
        XCTAssertNotEqual(result, "/some/other/ls")
    }
}
```

- [ ] **Step 2: Build and test**

Run: `swift test --filter ExecutableFinderTests`
Expected: All 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/Pellucid/Utilities/ExecutableFinder.swift Tests/PellucidTests/ExecutableFinderTests.swift
git commit -m "Add ExecutableFinder utility for PATH-first tool resolution"
```

---

### Task 2: Update PlantUMLRenderer to use ExecutableFinder

**Files:**
- Modify: `Sources/Pellucid/Services/PlantUMLRenderer.swift:85-118`

- [ ] **Step 1: Replace findPlantUML with findExecutable**

Replace the entire `findPlantUML()` method:

```swift
private func findPlantUML() -> String? {
    findExecutable(named: "plantuml", fallbackPaths: [
        "/opt/local/bin/plantuml",      // MacPorts
        "/usr/local/bin/plantuml",       // manual install / older Homebrew
        "/opt/homebrew/bin/plantuml",    // Homebrew on Apple Silicon
    ])
}
```

- [ ] **Step 2: Build and test**

Run: `swift build && swift test`
Expected: Clean build, all tests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/Pellucid/Services/PlantUMLRenderer.swift
git commit -m "Use shared ExecutableFinder in PlantUMLRenderer"
```

---

### Task 3: SourceLocationMap

**Files:**
- Create: `Sources/Pellucid/Services/SourceLocationMap.swift`
- Create: `Tests/PellucidTests/SourceLocationMapTests.swift`

- [ ] **Step 1: Create SourceLocationMap**

`Sources/Pellucid/Services/SourceLocationMap.swift`:

```swift
// Pellucid — Native macOS markdown viewer
// Copyright (C) 2026 Everett Kropf
// [GPL header]

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
    /// Returns the first exact match, or 1 (top of file) if no match is found.
    func sourceLine(for blockType: SourceBlockType, contentKey: String) -> Int {
        entries.first { $0.blockType == blockType && $0.contentKey == contentKey }?.line ?? 1
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
            // Use first cell content as key
            let firstCell = table.head.cells.first
            let text = firstCell?.children.compactMap { extractInlineText(from: $0) }.joined() ?? ""
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

// MARK: - Inline text extraction (reuses pattern from TOCExtractor)

private func extractInlineText(from markup: any Markup) -> String? {
    if let text = markup as? Markdown.Text {
        return text.string
    } else if let code = markup as? InlineCode {
        return code.code
    } else if markup is SoftBreak {
        return " "
    } else if markup is LineBreak {
        return "\n"
    } else if let container = markup as? (any InlineContainer) {
        return container.children.compactMap { extractInlineText(from: $0) }.joined()
    }
    return nil
}
```

Note: The `Heading.plainText` extension (from TOCExtractor.swift) is used for heading content keys to match the same text that `configuration.content.renderPlainText()` produces. The `extractInlineText` function here duplicates the same pattern from TOCExtractor for other block types.

- [ ] **Step 2: Create tests**

`Tests/PellucidTests/SourceLocationMapTests.swift`:

```swift
// Pellucid — Native macOS markdown viewer
// Copyright (C) 2026 Everett Kropf
// [GPL header]

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
```

- [ ] **Step 3: Build and test**

Run: `swift test --filter SourceLocationMapTests`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/Pellucid/Services/SourceLocationMap.swift Tests/PellucidTests/SourceLocationMapTests.swift
git commit -m "Add SourceLocationMap for mapping rendered blocks to source lines"
```

---

### Task 4: ExternalEditor protocol and MacVimEditor

**Files:**
- Create: `Sources/Pellucid/Services/ExternalEditor.swift`

- [ ] **Step 1: Create ExternalEditor and MacVimEditor**

`Sources/Pellucid/Services/ExternalEditor.swift`:

```swift
// Pellucid — Native macOS markdown viewer
// Copyright (C) 2026 Everett Kropf
// [GPL header]

import Foundation
import os

private let logger = Logger(subsystem: "com.pellucid.app", category: "ExternalEditor")

protocol ExternalEditor: Sendable {
    var displayName: String { get }
    func isAvailable() -> Bool
    func openFile(_ url: URL, atLine line: Int) throws
}

enum ExternalEditorError: LocalizedError {
    case notInstalled(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let name):
            "\(name) is not installed"
        case .launchFailed(let message):
            "Failed to launch editor: \(message)"
        }
    }
}

/// Opens files in MacVim using `mvim --remote-silent +{line}`.
struct MacVimEditor: ExternalEditor {
    let displayName = "MacVim"

    private static let fallbackPaths = [
        "/opt/local/bin/mvim",                                  // MacPorts
        "/usr/local/bin/mvim",                                  // Homebrew (legacy / Intel)
        "/opt/homebrew/bin/mvim",                               // Homebrew (Apple Silicon)
        "/Applications/MacVim.app/Contents/bin/mvim",           // Direct app install
    ]

    func isAvailable() -> Bool {
        findMvim() != nil
    }

    func openFile(_ url: URL, atLine line: Int) throws {
        guard let mvimPath = findMvim() else {
            throw ExternalEditorError.notInstalled(displayName)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mvimPath)
        process.arguments = ["--remote-silent", "+\(line)", url.path]

        do {
            try process.run()
        } catch {
            logger.error("Failed to launch MacVim: \(error.localizedDescription)")
            throw ExternalEditorError.launchFailed(error.localizedDescription)
        }
    }

    private func findMvim() -> String? {
        findExecutable(named: "mvim", fallbackPaths: Self.fallbackPaths)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Clean build.

- [ ] **Step 3: Commit**

```bash
git add Sources/Pellucid/Services/ExternalEditor.swift
git commit -m "Add ExternalEditor protocol and MacVimEditor implementation"
```

---

### Task 5: Wire SourceLocationMap into MarkdownDocument

**Files:**
- Modify: `Sources/Pellucid/Models/MarkdownDocument.swift`

- [ ] **Step 1: Add sourceLocationMap property and populate on reload**

Add the property after `processedMarkdown`:

```swift
@Published private(set) var sourceLocationMap: SourceLocationMap = .empty
```

In `reloadFile()`, add after the `tocEntries` line:

```swift
sourceLocationMap = SourceLocationMap.extract(from: document)
```

And in the `catch` block, add:

```swift
sourceLocationMap = .empty
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Clean build.

- [ ] **Step 3: Commit**

```bash
git add Sources/Pellucid/Models/MarkdownDocument.swift
git commit -m "Populate SourceLocationMap in MarkdownDocument on file load"
```

---

### Task 6: Gesture wiring in ContentView

**Files:**
- Modify: `Sources/Pellucid/Views/ContentView.swift`

- [ ] **Step 1: Add block style overrides for all block types**

Add new `.markdownBlockStyle` modifiers to the `Markdown` view, BEFORE the existing `.markdownTheme()` modifier. The existing `.markdownBlockStyle(\.codeBlock)` should also be moved before `.markdownTheme()` if it isn't already.

The modifier chain on the `MarkdownUI.Markdown` view becomes:

```swift
MarkdownUI.Markdown(document.processedMarkdown, imageBaseURL: document.fileURL?.deletingLastPathComponent())
    .markdownCodeSyntaxHighlighter(AppCodeSyntaxHighlighter(palette: themeManager.selectedTheme.syntaxColors(isDark: isDark)))
    .markdownBlockStyle(\.codeBlock) { configuration in
        codeBlockView(configuration: configuration)
    }
    .markdownBlockStyle(\.heading1) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .heading, contentKey: configuration.content.renderPlainText())
            }
        }
    }
    .markdownBlockStyle(\.heading2) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .heading, contentKey: configuration.content.renderPlainText())
            }
        }
    }
    .markdownBlockStyle(\.heading3) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .heading, contentKey: configuration.content.renderPlainText())
            }
        }
    }
    .markdownBlockStyle(\.heading4) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .heading, contentKey: configuration.content.renderPlainText())
            }
        }
    }
    .markdownBlockStyle(\.heading5) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .heading, contentKey: configuration.content.renderPlainText())
            }
        }
    }
    .markdownBlockStyle(\.heading6) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .heading, contentKey: configuration.content.renderPlainText())
            }
        }
    }
    .markdownBlockStyle(\.paragraph) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .paragraph, contentKey: String(configuration.content.renderPlainText().prefix(200)))
            }
        }
    }
    .markdownBlockStyle(\.blockquote) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .blockquote, contentKey: String(configuration.content.renderPlainText().prefix(200)))
            }
        }
    }
    .markdownBlockStyle(\.listItem) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .listItem, contentKey: String(configuration.content.renderPlainText().prefix(200)))
            }
        }
    }
    .markdownBlockStyle(\.table) { configuration in
        configuration.label.onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .table, contentKey: String(configuration.content.renderPlainText().prefix(200)))
            }
        }
    }
    .markdownImageProvider(.local)
    .markdownTheme(themeManager.selectedTheme.markdownTheme(isDark: isDark))
    .padding(.horizontal, 32)
    .padding(.vertical, 24)
    .frame(maxWidth: 860, alignment: .leading)
    .frame(maxWidth: .infinity)
    .textSelection(.enabled)
```

- [ ] **Step 2: Update codeBlockView to add Cmd+click gesture**

Wrap the entire return of `codeBlockView` with a gesture. Add `.onTapGesture` to each branch:

```swift
@ViewBuilder
private func codeBlockView(configuration: CodeBlockConfiguration) -> some View {
    let lang = configuration.language?.lowercased()
    if lang == "math" || lang == "latex" {
        MathBlockView(latex: configuration.content.trimmingCharacters(in: .whitespacesAndNewlines), textColor: themeManager.selectedTheme.mathTextColor(isDark: isDark))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .markdownMargin(top: .em(0.8), bottom: .em(0.8))
            .onTapGesture {
                if NSEvent.modifierFlags.contains(.command) {
                    jumpToSource(blockType: .codeBlock, contentKey: String(configuration.content.prefix(200)))
                }
            }
    } else if lang == "plantuml" {
        DiagramBlockView(source: configuration.content)
            .onTapGesture {
                if NSEvent.modifierFlags.contains(.command) {
                    jumpToSource(blockType: .codeBlock, contentKey: String(configuration.content.prefix(200)))
                }
            }
    } else {
        configuration.label
            .relativeLineSpacing(.em(0.225))
            .markdownTextStyle {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
            }
            .padding(16)
            .background(themeManager.selectedTheme.codeBlockBackground(isDark: isDark))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .markdownMargin(top: .zero, bottom: .em(0.8))
            .onTapGesture {
                if NSEvent.modifierFlags.contains(.command) {
                    jumpToSource(blockType: .codeBlock, contentKey: String(configuration.content.prefix(200)))
                }
            }
    }
}
```

- [ ] **Step 3: Add jumpToSource helper**

Add the `jumpToSource` helper method to `ContentView`:

```swift
private func jumpToSource(blockType: SourceBlockType, contentKey: String) {
    guard let url = document.fileURL else { return }
    let line = document.sourceLocationMap.sourceLine(for: blockType, contentKey: contentKey)
    let editor = MacVimEditor()
    guard editor.isAvailable() else { return }
    try? editor.openFile(url, atLine: line)
}
```

- [ ] **Step 4: Add `import AppKit` if not present**

ContentView needs `NSEvent.modifierFlags` — ensure `import AppKit` or `import SwiftUI` (which includes AppKit on macOS) is present. `NSEvent` is available via `import AppKit`. Check if it's already imported; if not, add it.

- [ ] **Step 5: Build and verify**

Run: `swift build`
Expected: Clean build.

- [ ] **Step 6: Run all tests**

Run: `swift test`
Expected: All tests pass (existing + new SourceLocationMap + ExecutableFinder tests).

- [ ] **Step 7: Commit**

```bash
git add Sources/Pellucid/Views/ContentView.swift
git commit -m "Wire Cmd+click jump-to-source for all block types"
```
