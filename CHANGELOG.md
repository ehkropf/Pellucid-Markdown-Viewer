# Changelog

## 1.1.0 — 2026-03-28

- Rename app from md_viewr to Pellucid
- Theming system with Default and Solarized themes (system appearance drives light/dark)
- Copy All (⌘⇧C) menu item to copy raw markdown to clipboard
- MacPorts distribution: self-hosted custom port source in-repo (`sudo port install pellucid`)
- `+plantuml` variant for optional PlantUML diagram support
- Makefile replaces build-app.sh (`make`, `make test`, `make help`)
- Fix sidebar getting pushed off-screen during horizontal window resize
- Downscale oversized images to fit content area while preserving aspect ratio
- PlantUML diagrams get white background in dark mode for readability

## 1.0.2 — 2026-03-22

- Redesigned app icon
- Render images at actual size instead of stretching to fill
- Coalescing file watcher events (replaces debounce, catches missed writes)
- Copyright and license in About box
- Supported markdown list in README

## 1.0.1 — 2026-03-18

- Fix PlantUML subprocess stealing app focus (Java AWT headless mode)
- Concurrency and error handling improvements
- Drop CFBundleVersion from Info.plist

## 1.0.0 — 2026-03-16

- Initial release
- GitHub Flavored Markdown rendering (tables, task lists, strikethrough, fenced code blocks)
- Table of contents sidebar with click-to-scroll
- Live file watching with auto-reload
- Syntax highlighting for ~20 languages
- LaTeX math rendering via SwiftMath
- PlantUML diagram rendering via CLI subprocess
- Multi-window support with file deduplication
- File opening via File > Open, drag-and-drop, CLI arguments, and `.md` file handler
- Local image rendering
- Ad-hoc code signing for .app bundle
