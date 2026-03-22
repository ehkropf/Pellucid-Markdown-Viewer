# Changelog

## Unreleased

- Redisigned app icon
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
