# Text Selection Workarounds

Pragmatic improvements to text copying in Pellucid while keeping MarkdownUI as the rendering engine.

## Context

MarkdownUI renders each block element (paragraph, heading, code block, list item) as a separate SwiftUI `Text` view. SwiftUI's `.textSelection(.enabled)` works within a single `Text` view but cannot span across independent views. This means users cannot drag-select across paragraphs like they would in a browser or native document viewer.

A full fix requires replacing MarkdownUI with a custom `NSTextView`-based renderer (roadmap item). These workarounds provide meaningful copy functionality in the meantime.

Existing capability: "Copy All" (Cmd+Shift+C) copies raw markdown to clipboard.

## Feature 1: Cmd+A "Select All" with Visual Feedback

### Behavior

- Cmd+A copies `rawMarkdown` to `NSPasteboard` (same content as Copy All)
- A brief overlay toast ("Copied to clipboard") appears and fades out after ~1.5s
- Menu item added to Edit command group: "Select All" with Cmd+A shortcut
- Disabled when no document is loaded (same guard as Copy All)

### Rationale

Cmd+A is the instinctive shortcut users reach for. Since SwiftUI cannot programmatically select text across MarkdownUI's block views, copying to clipboard with visual confirmation is the next best thing. Both Cmd+A and Cmd+Shift+C remain available — Cmd+A for muscle memory, Cmd+Shift+C for menu discoverability.

### Changes

- **AppCommands.swift**: Override the standard "Select All" (Cmd+A) using `CommandGroup(replacing: .textEditing)`. The default Cmd+A does nothing useful in a read-only viewer, so replacing it is appropriate. Reuses existing `copyToClipboard` helper. Posts a `Notification` to trigger the toast.
- **ContentView.swift**: Add a toast overlay on the detail area. Listens for the copy notification to show/fade the toast. Both Cmd+A and Cmd+Shift+C post the same notification.

### Toast Design

- Centered in the detail area, not the full window
- Rounded rectangle with semi-transparent background, "Copied to clipboard" label
- Appears with fade-in, disappears after 1.5s with fade-out
- Shared between Cmd+A, Cmd+Shift+C (both Copy All actions show the toast)

## Feature 2: TOC "Copy Section" Context Menu

### Behavior

- Right-click a heading in the TOC sidebar shows a context menu with "Copy Section"
- Copies the raw markdown from that heading to (but not including) the next heading at the same or higher level, or end of document
- Same toast feedback as Cmd+A

### Section Extraction

The swift-markdown AST provides `SourceLocation` on `Heading` nodes, which includes line numbers (1-based). The extraction approach:

1. **TOCEntry** gains a `lineOffset: Int` field — the 0-based line index of the heading in the source
2. **TOCExtractor** captures `heading.range?.lowerBound.line` during the walk and stores it (converting from 1-based to 0-based)
3. At copy time, flatten the TOCEntry tree to get all headings in document order with their levels and line offsets
4. Find the target heading's line offset and scan forward for the next heading at the same or higher level
5. Slice `rawMarkdown` by line range: from the heading's line to the boundary line (or end of document)

### Flattening Strategy

`TOCEntry` keeps its recursive `children` structure (no change to tree semantics). A helper function flattens on demand for section boundary lookup. The flatten is O(n) on heading count, which is trivially fast.

### Changes

- **TOCEntry.swift**: Add `lineOffset: Int` field
- **TOCExtractor.swift**: Capture `heading.range?.lowerBound.line` during `visitHeading`, store as `lineOffset` (0-based)
- **TOCSidebarView.swift**: Add `.contextMenu` modifier to `TOCButton` with "Copy Section" item
- **TOCSidebarView.swift** or new utility: Section extraction logic (flatten tree, find line range, slice raw markdown)
- TOCSidebarView needs access to `rawMarkdown` — access via `@EnvironmentObject` on `MarkdownDocument` (already available in ContentView's environment)
- TOCSidebarView posts the same copy notification to trigger the toast in the detail area

### Edge Cases

- Heading is the last in the document: copy from heading to end of file
- Multiple headings at the same line (shouldn't happen, but defensive): use first match
- Empty section (heading immediately followed by same-or-higher-level heading): copies just the heading line
