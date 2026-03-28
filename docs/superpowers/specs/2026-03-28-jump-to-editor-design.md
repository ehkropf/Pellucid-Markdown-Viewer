# Jump-to-Editor (Cmd+click)

Cmd+click on any rendered block in the markdown viewer opens the source file at that line in MacVim.

## Components

### SourceLocationMap

A `MarkupWalker` that extracts block content → source line number mappings from the swift-markdown AST. Built alongside the TOC in `MarkdownDocument.reloadFile()`.

Each entry is `(blockType: SourceBlockType, contentKey: String, line: Int)`:
- `blockType`: enum — `.heading`, `.paragraph`, `.codeBlock`, `.blockquote`, `.listItem`, `.table`, `.thematicBreak`
- `contentKey`: plain text or raw content of the block, truncated to 200 characters for large blocks
- `line`: 1-based source line number from `heading.range?.lowerBound.line`

Lookup: `sourceLine(for blockType: SourceBlockType, contentKey: String) -> Int?` returns the first matching entry's line number. If no exact match is found, falls back to the nearest preceding entry's line number (any block type). Returns line 1 in the limit (nothing above).

File: `Sources/Pellucid/Services/SourceLocationMap.swift`

### ExternalEditor

A protocol for launching external editors at a specific file + line:

```swift
protocol ExternalEditor: Sendable {
    var displayName: String { get }
    func isAvailable() -> Bool
    func openFile(_ url: URL, atLine line: Int) throws
}
```

`MacVimEditor` implementation:
- Finds `mvim` using `findExecutable(name:fallbackPaths:)` (see below)
- Fallback paths: `/opt/local/bin/mvim` (MacPorts), `/usr/local/bin/mvim` (Homebrew legacy), `/opt/homebrew/bin/mvim` (Homebrew Apple Silicon), `/Applications/MacVim.app/Contents/bin/mvim`
- Launches `mvim --remote-silent +{line} {path}`

File: `Sources/Pellucid/Services/ExternalEditor.swift`

### Tool Resolution Utility

Shared function for finding external executables:

```swift
func findExecutable(named name: String, fallbackPaths: [String]) -> String?
```

1. Try `which {name}` via `/usr/bin/which` — resolves from PATH (works when running bare executable during development)
2. Fall back to provided known paths, checking `FileManager.isExecutableFile(atPath:)` for each
3. Return the first found path, or nil

File: `Sources/Pellucid/Utilities/ExecutableFinder.swift`

Used by both `MacVimEditor` and `PlantUMLRenderer`. The existing `PlantUMLRenderer.findPlantUML()` method is updated to use this shared utility, reversing its current order (currently checks hardcoded paths first, `which` second).

### Gesture Wiring (ContentView)

Cmd+click behavior is added to all block types via `.markdownBlockStyle` overrides that wrap `configuration.label` with `.onTapGesture`:

```swift
.markdownBlockStyle(\.paragraph) { configuration in
    configuration.label
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                jumpToSource(blockType: .paragraph, contentKey: configuration.content.renderPlainText())
            }
        }
}
```

Block types wired:
- **Headings** (`.heading1` through `.heading6`): content key is `configuration.content.renderPlainText()`
- **Code blocks**: already overridden for math/plantuml dispatch — add `.onTapGesture` to the entire `codeBlockView` output (all branches: math, plantuml, and syntax-highlighted). Content key is `String(configuration.content.prefix(200))`.
- **Paragraphs** (`.paragraph`): content key is `configuration.content.renderPlainText()`, truncated to 200 chars
- **Blockquotes** (`.blockquote`): same pattern
- **List items** (`.listItem`): content key is rendered plain text, truncated
- **Tables** (`.table`): content key is first cell content, truncated

- **Thematic breaks** (`.thematicBreak`): content key is the occurrence index (e.g., `"0"`, `"1"`) since there's no text content. SourceLocationMap walker counts thematic breaks in order; gesture handler counts occurrences to build the matching key.

Not wired:
- **Images**: `![alt](path)` is inline content within paragraphs — Cmd+clicking the paragraph containing an image jumps to that paragraph's source line, which is at or near the image. No separate block style exists for images.

`configuration.label` preserves the theme's rendering — we don't reimplement any styles. The `.id()` that MarkdownUI attaches to headings for TOC scroll should be preserved since it's part of the already-rendered label.

If heading `.id()` is lost (tested during implementation), re-attach explicitly with `.id(slugify(configuration.content.renderPlainText()))`.

### jumpToSource helper

In `ContentView`:

```swift
private func jumpToSource(blockType: SourceBlockType, contentKey: String) {
    guard let url = document.fileURL,
          let line = document.sourceLocationMap.sourceLine(for: blockType, contentKey: contentKey)
    else { return }
    let editor = MacVimEditor()
    try? editor.openFile(url, atLine: line)
}
```

### MarkdownDocument changes

Add `sourceLocationMap` property (`SourceLocationMap`, default `.empty`). Populated in `reloadFile()` alongside the TOC extraction:

```swift
let document = Document(parsing: content)
tocEntries = TOCExtractor.extractTOC(from: document)
sourceLocationMap = SourceLocationMap.extract(from: document)
```

## Edge Cases

- `mvim` not installed: `isAvailable()` returns false, Cmd+click does nothing (silent — no error toast)
- Block not found in source map: `sourceLine` returns nil, Cmd+click does nothing
- File has been externally modified since last reload: line numbers may be stale, but FileWatcher will trigger a reload shortly
- Multiple blocks with identical content: first match is used (consistent with document order)

## Testing

- **SourceLocationMap**: tests for all block types — headings, paragraphs, code blocks, blockquotes, list items, tables, thematic breaks. Verify content keys, line numbers, and nearest-preceding fallback.
- **ExecutableFinder**: test `which` resolution and fallback path checking
- No UI tests (per project convention)
