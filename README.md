# Pellucid

![App icon](screenshots/AppIcon.png)

A native macOS markdown viewer built with Swift and SwiftUI. No web views, no JavaScript, no Electron — just fast, native rendering that feels like a first-class Mac app. Pellucid is a viewer, not an editor. Open a markdown file, see it rendered beautifully, and let your editor of choice handle the writing while Pellucid live-reloads on every save.

<p align="center">
  <img src="screenshots/empty-state.png" width="45%" alt="Empty state" />
  <img src="screenshots/test-md.png" width="45%" alt="Rendering test.md" />
</p>

## Features

- **GitHub Flavored Markdown** — full GFM spec: tables, task lists, strikethrough, fenced code blocks
- **Table of contents** — auto-generated sidebar from headings, click to scroll
- **Live reload** — watches the file for changes and re-renders instantly, keeping your scroll position
- **Syntax highlighting** — ~20 languages with regex-based tokenization
- **LaTeX math** — native rendering via SwiftMath (no MathJax/KaTeX)
- **PlantUML diagrams** — rendered via CLI subprocess as SVG
- **Multiple open methods** — File > Open, drag-and-drop, CLI argument, or registered `.md` file handler

### Supported Markdown

- Headings, paragraphs, blockquotes, horizontal rules
- **Bold**, *italic*, ~~strikethrough~~
- Links and images (rendered at actual size)
- Ordered, unordered, and task lists
- Tables
- Fenced code blocks with syntax highlighting (~20 languages)
- LaTeX math via `math`/`latex` code blocks
- PlantUML diagrams via `plantuml` code blocks

See [`test.md`](test.md) for rendered examples of everything supported.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6 toolchain
- [PlantUML](https://plantuml.com) (optional, for diagram rendering)
  ```
  sudo port install plantuml
  ```

## Build

```bash
# Build the .app bundle (release)
make

# Debug build
make app-debug

# Launch
make open
```

> **Note:** Running the bare executable (not the `.app` bundle) may cause window focus issues on macOS. Use the `.app` bundle for normal use.

## Install

### MacPorts

Requires [MacPorts](https://www.macports.org) and Xcode Command Line Tools.

```bash
git clone https://github.com/ehkropf/Pellucid-Markdown-Viewer.git
cd Pellucid-Markdown-Viewer
sudo port -D ports/aqua/pellucid install pellucid

# Or with PlantUML diagram support:
sudo port -D ports/aqua/pellucid install pellucid +plantuml
```

The app installs to `/Applications/MacPorts/Pellucid.app`.

### Manual

Drag `build/Pellucid.app` to your Applications folder — just like any other Mac app.

Or from the command line:

```bash
cp -R build/Pellucid.app /Applications/
```

## Usage

```bash
# Open with a file
open build/Pellucid.app test.md

# Or run directly
build/Pellucid.app/Contents/MacOS/Pellucid ~/notes/readme.md
```

You can also:
- **Drag and drop** a `.md` file onto the window
- **File > Open** (⌘O) to browse for a file
- Double-click a `.md` file if Pellucid is set as the handler

## Architecture

```
Pellucid/
  App/           — entry point, AppDelegate, menu commands
  Models/        — MarkdownDocument, TOCEntry, FileWatcher
  Views/         — ContentView, TOCSidebarView, MathBlockView, DiagramBlockView
  Services/      — TOCExtractor, SyntaxHighlighter, PlantUMLRenderer
  Utilities/     — Slugify
```

Built entirely with Swift Package Manager — no Xcode project required.

### Dependencies

| Package | Purpose |
|---------|---------|
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | GFM AST parsing |
| [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) | SwiftUI markdown rendering |
| [SwiftMath](https://github.com/mgriebling/SwiftMath) | LaTeX math rendering |

## License

GPL-3.0-or-later. See [LICENSE](LICENSE) for details.
