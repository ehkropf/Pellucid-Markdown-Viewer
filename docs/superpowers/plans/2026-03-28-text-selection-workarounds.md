# Text Selection Workarounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Cmd+A copy-all-to-clipboard with visual toast feedback, and right-click "Copy Section" on TOC sidebar headings.

**Architecture:** A `Notification`-based approach connects menu commands and sidebar actions to a toast overlay in the detail view. Section extraction slices raw markdown by heading line offsets captured during TOC extraction.

**Tech Stack:** Swift 6, SwiftUI, swift-markdown AST, XCTest

---

### Task 1: Add copy notification and toast overlay

**Files:**
- Modify: `Sources/Pellucid/Views/ContentView.swift`

- [ ] **Step 1: Add notification name and toast state to ContentView**

Add a static notification name at module level (above `ContentView`), and add toast state + overlay to the detail view:

```swift
// At top of file, after the FocusedValues extension
extension Notification.Name {
    static let didCopyToClipboard = Notification.Name("didCopyToClipboard")
}
```

In `ContentView`, add state:

```swift
@State private var showCopiedToast = false
```

- [ ] **Step 2: Add toast overlay to the detail view**

Wrap the existing `detail` body in a `ZStack` with the toast overlay:

```swift
private var detail: some View {
    ZStack {
        Group {
            // ... existing if/else chain unchanged ...
        }

        if showCopiedToast {
            Text("Copied to clipboard")
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: .didCopyToClipboard)) { _ in
        withAnimation(.easeIn(duration: 0.15)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCopiedToast = false
            }
        }
    }
}
```

- [ ] **Step 3: Build and verify**

Run: `swift build`
Expected: Clean build, no errors.

- [ ] **Step 4: Commit**

```bash
git add Sources/Pellucid/Views/ContentView.swift
git commit -m "Add copy-to-clipboard notification and toast overlay"
```

---

### Task 2: Cmd+A Select All and toast on Copy All

**Files:**
- Modify: `Sources/Pellucid/App/AppCommands.swift`

- [ ] **Step 1: Add Select All command and post notification from both copy actions**

Replace the `copyToClipboard` helper to also post the notification. Add a "Select All" command that overrides the default Cmd+A:

In the `body` computed property, add a new command group replacing `.textEditing`:

```swift
CommandGroup(replacing: .textEditing) {
    Button("Select All") {
        copyToClipboard(rawMarkdown ?? "")
    }
    .keyboardShortcut("a", modifiers: .command)
    .disabled(rawMarkdown == nil || rawMarkdown!.isEmpty)
}
```

Update `copyToClipboard` to post the notification:

```swift
private func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    NotificationCenter.default.post(name: .didCopyToClipboard, object: nil)
}
```

Note: `Notification.Name.didCopyToClipboard` is defined in `ContentView.swift` — `AppCommands.swift` is in the same module so it's visible.

- [ ] **Step 2: Build and verify**

Run: `swift build`
Expected: Clean build. Cmd+A now copies raw markdown and triggers toast. Cmd+Shift+C also triggers toast.

- [ ] **Step 3: Commit**

```bash
git add Sources/Pellucid/App/AppCommands.swift
git commit -m "Add Cmd+A select all and toast feedback on copy"
```

---

### Task 3: Add lineOffset to TOCEntry and TOCExtractor

**Files:**
- Modify: `Sources/Pellucid/Models/TOCEntry.swift`
- Modify: `Sources/Pellucid/Services/TOCExtractor.swift`
- Modify: `Tests/PellucidTests/TOCExtractorTests.swift`

- [ ] **Step 1: Add lineOffset to TOCEntry**

```swift
struct TOCEntry: Identifiable, Equatable, Sendable {
    let id: String
    let level: Int
    let title: String
    let lineOffset: Int
    let children: [TOCEntry]
}
```

- [ ] **Step 2: Capture line offset in TOCExtractor**

In `visitHeading`, capture the 0-based line offset from the heading's source range:

```swift
mutating func visitHeading(_ heading: Heading) {
    let title = heading.plainText
    let id = slugify(title)
    let line = (heading.range?.lowerBound.line ?? 1) - 1  // 0-based
    flatEntries.append((level: heading.level, title: title, id: id, lineOffset: line))
    descendInto(heading)
}
```

Update the `flatEntries` type and `buildChildren`/`buildTree` to carry `lineOffset`:

```swift
private var flatEntries: [(level: Int, title: String, id: String, lineOffset: Int)] = []
```

In `buildChildren`, pass `lineOffset` through to `TOCEntry`:

```swift
result.append(TOCEntry(
    id: entry.id,
    level: entry.level,
    title: entry.title,
    lineOffset: entry.lineOffset,
    children: children
))
```

Update the type annotations on `buildTree` and `buildChildren` parameters to match.

- [ ] **Step 3: Fix existing tests**

Every `TOCEntry` assertion that checks properties still works — `lineOffset` is a new field. But the `extractTOC` helper in tests should still work since it just parses markdown and returns entries. Add a quick test to verify line offsets are captured:

```swift
func testHeadingLineOffsets() {
    let toc = extractTOC("""
    # First

    Some text.

    ## Second

    More text.

    ## Third
    """)
    XCTAssertEqual(toc[0].lineOffset, 0)
    XCTAssertEqual(toc[0].children[0].lineOffset, 4)
    XCTAssertEqual(toc[0].children[1].lineOffset, 8)
}
```

- [ ] **Step 4: Run tests**

Run: `swift test`
Expected: All tests pass including the new `testHeadingLineOffsets`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Pellucid/Models/TOCEntry.swift Sources/Pellucid/Services/TOCExtractor.swift Tests/PellucidTests/TOCExtractorTests.swift
git commit -m "Add lineOffset to TOCEntry for section extraction"
```

---

### Task 4: Section extraction logic

**Files:**
- Modify: `Sources/Pellucid/Services/TOCExtractor.swift`
- Modify: `Tests/PellucidTests/TOCExtractorTests.swift`

- [ ] **Step 1: Add section extraction functions to TOCExtractor**

Add two static helpers to `TOCExtractor`:

```swift
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
```

- [ ] **Step 2: Add tests for section extraction**

```swift
func testExtractSectionFirstHeading() {
    let markdown = """
    # Title

    Intro paragraph.

    ## Section One

    Content one.

    ## Section Two

    Content two.
    """
    let entries = extractTOC(markdown)
    let section = TOCExtractor.extractSection(for: entries[0], allEntries: entries, rawMarkdown: markdown)
    XCTAssertTrue(section.hasPrefix("# Title"))
    XCTAssertTrue(section.contains("Intro paragraph."))
    XCTAssertTrue(section.contains("Content one."))
    XCTAssertTrue(section.contains("Content two."))
}

func testExtractSectionMiddle() {
    let markdown = """
    # Title

    ## Section One

    Content one.

    ## Section Two

    Content two.
    """
    let entries = extractTOC(markdown)
    let flat = TOCExtractor.flatten(entries)
    let sectionOne = flat.first(where: { $0.title == "Section One" })!
    let section = TOCExtractor.extractSection(for: sectionOne, allEntries: entries, rawMarkdown: markdown)
    XCTAssertTrue(section.hasPrefix("## Section One"))
    XCTAssertTrue(section.contains("Content one."))
    XCTAssertFalse(section.contains("Content two."))
}

func testExtractSectionLast() {
    let markdown = """
    # Title

    ## Section One

    Content one.

    ## Section Two

    Content two.
    """
    let entries = extractTOC(markdown)
    let flat = TOCExtractor.flatten(entries)
    let sectionTwo = flat.first(where: { $0.title == "Section Two" })!
    let section = TOCExtractor.extractSection(for: sectionTwo, allEntries: entries, rawMarkdown: markdown)
    XCTAssertTrue(section.hasPrefix("## Section Two"))
    XCTAssertTrue(section.contains("Content two."))
    XCTAssertFalse(section.contains("Content one."))
}

func testExtractSectionIncludesSubheadings() {
    let markdown = """
    # Title

    ## Section

    Content.

    ### Subsection

    Sub content.

    ## Next Section

    Next content.
    """
    let entries = extractTOC(markdown)
    let flat = TOCExtractor.flatten(entries)
    let section = flat.first(where: { $0.title == "Section" })!
    let result = TOCExtractor.extractSection(for: section, allEntries: entries, rawMarkdown: markdown)
    XCTAssertTrue(result.contains("### Subsection"))
    XCTAssertTrue(result.contains("Sub content."))
    XCTAssertFalse(result.contains("Next content."))
}

func testExtractSectionEmpty() {
    let markdown = """
    ## One
    ## Two
    """
    let entries = extractTOC(markdown)
    let section = TOCExtractor.extractSection(for: entries[0], allEntries: entries, rawMarkdown: markdown)
    XCTAssertEqual(section, "## One")
}
```

- [ ] **Step 3: Run tests**

Run: `swift test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/Pellucid/Services/TOCExtractor.swift Tests/PellucidTests/TOCExtractorTests.swift
git commit -m "Add section extraction logic for TOC copy"
```

---

### Task 5: TOC "Copy Section" context menu

**Files:**
- Modify: `Sources/Pellucid/Views/TOCSidebarView.swift`
- Modify: `Sources/Pellucid/Views/ContentView.swift`

- [ ] **Step 1: Pass rawMarkdown and tocEntries to TOCSidebarView**

`TOCSidebarView` needs access to `rawMarkdown` and the full `tocEntries` for section extraction. Add these as parameters:

In `TOCSidebarView`:
```swift
struct TOCSidebarView: View {
    let entries: [TOCEntry]
    let rawMarkdown: String
    @Binding var selectedID: String?

    // ...
}
```

Pass `rawMarkdown` through to child views. Update `TOCRootEntry`, `TOCChildEntry`, and `TOCButton` to carry `entries` (the full top-level array) and `rawMarkdown`:

```swift
private struct TOCRootEntry: View {
    let entry: TOCEntry
    let allEntries: [TOCEntry]
    let rawMarkdown: String
    @Binding var selectedID: String?
    @State private var isExpanded = true
    // ...
}

private struct TOCChildEntry: View {
    let entry: TOCEntry
    let allEntries: [TOCEntry]
    let rawMarkdown: String
    @Binding var selectedID: String?
    // ...
}

private struct TOCButton: View {
    let entry: TOCEntry
    let allEntries: [TOCEntry]
    let rawMarkdown: String
    @Binding var selectedID: String?
    // ...
}
```

- [ ] **Step 2: Add context menu to TOCButton**

```swift
private struct TOCButton: View {
    let entry: TOCEntry
    let allEntries: [TOCEntry]
    let rawMarkdown: String
    @Binding var selectedID: String?

    var body: some View {
        Button(action: { selectedID = entry.id }) {
            Text(entry.title)
                .font(fontForLevel(entry.level))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tag(entry.id)
        .contextMenu {
            Button("Copy Section") {
                let section = TOCExtractor.extractSection(
                    for: entry,
                    allEntries: allEntries,
                    rawMarkdown: rawMarkdown
                )
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(section, forType: .string)
                NotificationCenter.default.post(name: .didCopyToClipboard, object: nil)
            }
        }
    }
}
```

- [ ] **Step 3: Update ContentView to pass rawMarkdown to TOCSidebarView**

In `ContentView.sidebar`:

```swift
TOCSidebarView(
    entries: document.tocEntries,
    rawMarkdown: document.rawMarkdown,
    selectedID: $selectedHeadingID
)
```

- [ ] **Step 4: Update all call sites within TOCSidebarView**

In `TOCSidebarView.body`, pass through to `TOCRootEntry`:
```swift
TOCRootEntry(entry: entry, allEntries: entries, rawMarkdown: rawMarkdown, selectedID: $selectedID)
```

In `TOCRootEntry.body`, pass through to `TOCButton` and `TOCChildEntry`:
```swift
TOCButton(entry: entry, allEntries: allEntries, rawMarkdown: rawMarkdown, selectedID: $selectedID)
// and
TOCChildEntry(entry: child, allEntries: allEntries, rawMarkdown: rawMarkdown, selectedID: $selectedID)
```

In `TOCChildEntry.body`, pass through to `TOCButton` and recursive `TOCChildEntry`:
```swift
TOCButton(entry: entry, allEntries: allEntries, rawMarkdown: rawMarkdown, selectedID: $selectedID)
// and
TOCChildEntry(entry: child, allEntries: allEntries, rawMarkdown: rawMarkdown, selectedID: $selectedID)
```

- [ ] **Step 5: Build and verify**

Run: `swift build`
Expected: Clean build.

- [ ] **Step 6: Run all tests**

Run: `swift test`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/Pellucid/Views/TOCSidebarView.swift Sources/Pellucid/Views/ContentView.swift
git commit -m "Add Copy Section context menu to TOC sidebar"
```
