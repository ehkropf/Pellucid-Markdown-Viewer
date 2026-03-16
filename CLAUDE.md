# md_viewr

Native macOS markdown viewer. Swift 6 + SwiftUI, macOS 14+. No JavaScript. No Xcode project — SPM only.

## Build & Run

- `swift build` — debug build (parallel by default, `-j N` to limit)
- `swift build -c release` — release build
- `bash scripts/build-app.sh` — build + assemble .app bundle to `build/md_viewr.app`
- `bash scripts/build-app.sh debug` — debug .app bundle
- `open build/md_viewr.app` — launch app
- `swift test` — run tests
- Clean: `rm -rf .build build` or `swift package clean` (only clears `.build`)

## Architecture

```
md_viewr/
  App/           — @main entry point (md_viewrApp), menu commands (AppCommands)
  Models/        — MarkdownDocument (central ObservableObject), TOCEntry, FileWatcher
  Views/         — ContentView, TOCSidebarView, MathBlockView, DiagramBlockView
  Services/      — TOCExtractor, SyntaxHighlighter, PlantUMLRenderer
  Utilities/     — Slugify
md_viewrTests/   — test target (logic tests only, no UI tests)
Resources/       — Info.plist, AppIcon.{svg,png,icns}
scripts/         — build-app.sh, generate-icon.py
```

- `MarkdownDocument` is the central `@MainActor ObservableObject` — owns file URL, raw text, TOC, FileWatcher
- MarkdownUI renders GFM with `.markdownTheme(.gitHub)`
- Code blocks dispatch via `.markdownBlockStyle(\.codeBlock)`: `math`/`latex` → MathBlockView, `plantuml` → DiagramBlockView, else → syntax-highlighted
- TOC extracted from swift-markdown AST via `MarkupWalker`, displayed in `NavigationSplitView` sidebar
- `ScrollViewReader` handles click-to-scroll from TOC to heading
- FileWatcher uses `DispatchSource` with 200ms debounce; handles atomic writes (delete+recreate)

## Key Constraints

- **Swift 6 strict concurrency** — `swift-tools-version: 6.0`. Use `@MainActor`, `Sendable`, `@preconcurrency import` as needed
- **No JavaScript** — all rendering is native Swift/SwiftUI
- **MacPorts over Homebrew** — PlantUML at `/opt/local/bin/plantuml`
- **slugify() must match MarkdownUI's internal `kebabCased()`** — TOC scroll-to-heading depends on ID alignment
- **MarkdownUI already attaches `.id()` to headings** — no custom theme heading override needed
- PlantUML uses `-pipe -tsvg` (not `-tpng` — PNG is pixelated)

## Dependencies (SPM)

- `swift-markdown` (swiftlang) — GFM AST parsing
- `swift-markdown-ui` (gonzalezreal) — SwiftUI markdown rendering, `MarkdownUI` module
- `SwiftMath` (mgriebling) — LaTeX math via `MTMathUILabel` (NSViewRepresentable)

## Gotchas

- Running bare executable (not .app bundle) causes window focus/z-order issues — always test with `build/md_viewr.app`
- `NavigationSplitView` adds its own sidebar toggle — don't add a manual one
- `@preconcurrency import Foundation` needed in MarkdownDocument for `NSObjectProtocol` Sendable workaround
- `nonisolated deinit` with local variable capture pattern for removing NotificationCenter observers in `@MainActor` classes
- `build-app.sh` copies SwiftMath's `.bundle` resources — math rendering breaks without them
- TOCExtractor uses `Heading.plainText` (custom extension) that must match MarkdownUI's `renderPlainText()`

## Testing

- No TDD — unit tests for logic only
- Visual acceptance testing via `test.md` (covers GFM, code blocks, math, PlantUML)
- Test target has placeholder test; add logic tests as needed

## Code Style

- Prefer `@ViewBuilder` computed properties for view composition
- Use `Group` wrapper for conditional content in SwiftUI views
- Keep view logic in the view file; business logic in Models/Services
- Actor isolation for async services (e.g., `PlantUMLRenderer` is an `actor`)

## License

GPL-3.0-or-later. All source files must include the copyright header (see any `.swift` file for the template).
