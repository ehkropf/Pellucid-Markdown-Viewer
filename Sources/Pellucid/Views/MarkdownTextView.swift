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

import AppKit
import os
import SwiftUI

// MARK: - MarkdownNSTextView

/// Custom NSTextView subclass that draws decorations behind text for code blocks,
/// inline code, blockquotes, thematic breaks, and heading dividers.
///
/// The text view is configured as read-only with selection support. Custom drawing
/// is performed in `drawBackground(in:)` by enumerating attributed string ranges
/// that carry decoration marker keys (`.codeBlockRange`, `.inlineCodeBackground`,
/// `.blockquoteRange`, `.thematicBreak`, `.headingDivider`).
final class MarkdownNSTextView: NSTextView {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pellucid",
        category: "MarkdownNSTextView"
    )

    /// The theme controlling decoration colors and dimensions.
    var decorationTheme: AttributedStringTheme?

    /// Back-reference to the coordinator for SourceMap and rawMarkdown access.
    weak var coordinator: MarkdownTextView.Coordinator?

    // MARK: - Hover Copy Button State

    /// The floating copy button shown when hovering over a code block.
    private var copyButton: NSButton?

    /// The character range of the code block currently being hovered.
    private var hoveredCodeBlockRange: NSRange?

    /// Observer for scroll view bounds changes (hides copy button on scroll).
    nonisolated(unsafe) private var scrollObserver: NSObjectProtocol?

    // MARK: - Background Drawing

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)

        guard let layoutManager, let textContainer, let textStorage,
              let theme = decorationTheme
        else { return }

        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: rect,
            in: textContainer
        )
        let visibleCharRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange,
            actualGlyphRange: nil
        )

        guard visibleCharRange.length > 0 else { return }

        let origin = textContainerOrigin

        // Draw code block backgrounds.
        drawCodeBlockBackgrounds(
            in: visibleCharRange,
            textStorage: textStorage,
            layoutManager: layoutManager,
            textContainer: textContainer,
            origin: origin,
            theme: theme
        )

        // Draw inline code backgrounds.
        drawInlineCodeBackgrounds(
            in: visibleCharRange,
            textStorage: textStorage,
            layoutManager: layoutManager,
            textContainer: textContainer,
            origin: origin,
            theme: theme
        )

        // Draw blockquote accent bars.
        drawBlockquoteAccentBars(
            in: visibleCharRange,
            textStorage: textStorage,
            layoutManager: layoutManager,
            textContainer: textContainer,
            origin: origin,
            theme: theme
        )

        // Draw heading dividers.
        drawHeadingDividers(
            in: visibleCharRange,
            textStorage: textStorage,
            layoutManager: layoutManager,
            textContainer: textContainer,
            origin: origin,
            theme: theme
        )

        // Draw thematic breaks.
        drawThematicBreaks(
            in: visibleCharRange,
            textStorage: textStorage,
            layoutManager: layoutManager,
            textContainer: textContainer,
            origin: origin,
            theme: theme
        )
    }

    // MARK: - Code Block Backgrounds

    private func drawCodeBlockBackgrounds(
        in visibleRange: NSRange,
        textStorage: NSTextStorage,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        origin: NSPoint,
        theme: AttributedStringTheme
    ) {
        textStorage.enumerateAttribute(
            .codeBlockRange,
            in: visibleRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var blockRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            blockRect.origin.x += origin.x
            blockRect.origin.y += origin.y

            // Expand to include padding.
            let padding = theme.codeBlockPadding
            blockRect = blockRect.insetBy(dx: -padding, dy: -padding)

            let path = NSBezierPath(
                roundedRect: blockRect,
                xRadius: theme.codeBlockCornerRadius,
                yRadius: theme.codeBlockCornerRadius
            )
            theme.codeBlockBackground.setFill()
            path.fill()
        }
    }

    // MARK: - Inline Code Backgrounds

    private func drawInlineCodeBackgrounds(
        in visibleRange: NSRange,
        textStorage: NSTextStorage,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        origin: NSPoint,
        theme: AttributedStringTheme
    ) {
        textStorage.enumerateAttribute(
            .inlineCodeBackground,
            in: visibleRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)

            // Enumerate line fragments to handle inline code that wraps across lines.
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, lineGlyphRange, _ in
                let intersection = NSIntersectionRange(glyphRange, lineGlyphRange)
                guard intersection.length > 0 else { return }

                var codeRect = layoutManager.boundingRect(
                    forGlyphRange: intersection,
                    in: textContainer
                )
                codeRect.origin.x += origin.x
                codeRect.origin.y += origin.y

                // Small padding for inline code.
                let hPad: CGFloat = 3.0
                let vPad: CGFloat = 1.5
                codeRect = codeRect.insetBy(dx: -hPad, dy: -vPad)

                let path = NSBezierPath(
                    roundedRect: codeRect,
                    xRadius: 3.0,
                    yRadius: 3.0
                )
                theme.codeBlockBackground.withAlphaComponent(0.6).setFill()
                path.fill()
            }
        }
    }

    // MARK: - Blockquote Accent Bars

    private func drawBlockquoteAccentBars(
        in visibleRange: NSRange,
        textStorage: NSTextStorage,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        origin: NSPoint,
        theme: AttributedStringTheme
    ) {
        textStorage.enumerateAttribute(
            .blockquoteRange,
            in: visibleRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var blockRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            blockRect.origin.x += origin.x
            blockRect.origin.y += origin.y

            // Draw vertical accent bar at the left edge of the blockquote indent.
            let barRect = NSRect(
                x: origin.x + theme.blockquoteBarWidth,
                y: blockRect.origin.y,
                width: theme.blockquoteBarWidth,
                height: blockRect.height
            )
            let barPath = NSBezierPath(
                roundedRect: barRect,
                xRadius: theme.blockquoteBarWidth / 2,
                yRadius: theme.blockquoteBarWidth / 2
            )
            theme.blockquoteBarColor.setFill()
            barPath.fill()
        }
    }

    // MARK: - Heading Dividers

    private func drawHeadingDividers(
        in visibleRange: NSRange,
        textStorage: NSTextStorage,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        origin: NSPoint,
        theme: AttributedStringTheme
    ) {
        textStorage.enumerateAttribute(
            .headingDivider,
            in: visibleRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var blockRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            blockRect.origin.x += origin.x
            blockRect.origin.y += origin.y

            // Draw a subtle line below the heading.
            let lineY = blockRect.maxY + 4.0
            let lineRect = NSRect(
                x: origin.x,
                y: lineY,
                width: textContainer.containerSize.width,
                height: 1.0
            )
            theme.subtleColor.withAlphaComponent(0.3).setFill()
            NSBezierPath.fill(lineRect)
        }
    }

    // MARK: - Thematic Breaks

    private func drawThematicBreaks(
        in visibleRange: NSRange,
        textStorage: NSTextStorage,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        origin: NSPoint,
        theme: AttributedStringTheme
    ) {
        textStorage.enumerateAttribute(
            .thematicBreak,
            in: visibleRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var blockRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            blockRect.origin.x += origin.x
            blockRect.origin.y += origin.y

            // Draw a centered horizontal rule instead of the "---" characters.
            let ruleY = blockRect.midY - theme.thematicBreakHeight / 2
            let inset: CGFloat = 16.0
            let ruleRect = NSRect(
                x: origin.x + inset,
                y: ruleY,
                width: textContainer.containerSize.width - inset * 2,
                height: theme.thematicBreakHeight
            )
            let rulePath = NSBezierPath(
                roundedRect: ruleRect,
                xRadius: theme.thematicBreakHeight / 2,
                yRadius: theme.thematicBreakHeight / 2
            )
            theme.thematicBreakColor.setFill()
            rulePath.fill()
        }
    }

    // MARK: - Cursor Management

    /// NSTextView with isEditable=false already defaults to the arrow cursor on macOS.
    /// Override resetCursorRects to ensure we get arrow cursor everywhere except links,
    /// which get the pointing hand cursor via the default link attribute handling.
    override func resetCursorRects() {
        // Let the superclass set up link cursor rects.
        super.resetCursorRects()

        // The default behavior for non-editable text views is arrow cursor,
        // which is what we want. No additional cursor rects needed.
    }

    // MARK: - Cmd+Click → MacVim

    override func mouseDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.mouseDown(with: event)
            return
        }

        let pointInView = convert(event.locationInWindow, from: nil)
        let charIndex = charIndex(at: pointInView)

        guard charIndex < (textStorage?.length ?? 0),
              let entry = coordinator?.sourceMap.entry(at: charIndex),
              let fileURL = coordinator?.fileURL
        else {
            super.mouseDown(with: event)
            return
        }

        let line = entry.sourceLineRange.lowerBound + 1  // MacVim uses 1-based
        launchMacVim(at: line, fileURL: fileURL)
    }

    /// Launches MacVim at the specified line number, trying common MacPorts, Homebrew,
    /// and fallback paths.
    private func launchMacVim(at line: Int, fileURL: URL) {
        let candidatePaths = [
            "/opt/local/bin/mvim",       // MacPorts (preferred)
            "/usr/local/bin/mvim",       // Homebrew (Intel)
            "/opt/homebrew/bin/mvim",    // Homebrew (Apple Silicon)
        ]

        var launchPath: String?

        // Try known paths first.
        for path in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                launchPath = path
                break
            }
        }

        // Fallback: use `which mvim` to find it on PATH.
        if launchPath == nil {
            let whichProcess = Process()
            whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichProcess.arguments = ["mvim"]
            let pipe = Pipe()
            whichProcess.standardOutput = pipe
            whichProcess.standardError = FileHandle.nullDevice
            do {
                try whichProcess.run()
                whichProcess.waitUntilExit()
                if whichProcess.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let result = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if let result, !result.isEmpty,
                       FileManager.default.isExecutableFile(atPath: result)
                    {
                        launchPath = result
                    }
                }
            } catch {
                Self.logger.warning("Failed to run 'which mvim': \(error.localizedDescription)")
            }
        }

        guard let mvimPath = launchPath else {
            Self.logger.warning("MacVim (mvim) not found in any known location")
            return
        }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: mvimPath)
            process.arguments = ["+\(line)", fileURL.path]
            try process.run()
            Self.logger.debug(
                "Launched MacVim at line \(line) for \(fileURL.lastPathComponent)"
            )
        } catch {
            Self.logger.error(
                "Failed to launch MacVim: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let pointInView = convert(event.locationInWindow, from: nil)
        let charIndex = charIndex(at: pointInView)

        // Store the click character index for menu actions.
        contextMenuCharIndex = charIndex

        guard let textStorage, charIndex < textStorage.length else {
            return buildDefaultTextMenu(menu)
        }

        // Check if the click is on an attachment.
        let attributes = textStorage.attributes(at: charIndex, effectiveRange: nil)

        if let attachment = attributes[.attachment] as? (any MarkdownAttachment),
           attachment.attachmentImage != nil
        {
            // Image/diagram/math attachment.
            contextMenuAttachment = attachment
            let copyImageItem = NSMenuItem(
                title: "Copy Image",
                action: #selector(contextMenuCopyImage(_:)),
                keyEquivalent: ""
            )
            copyImageItem.target = self
            menu.addItem(copyImageItem)

            // If it's a table, also offer "Copy Table as Markdown".
            if attachment is TableAttachment {
                let copyTableItem = NSMenuItem(
                    title: "Copy Table as Markdown",
                    action: #selector(contextMenuCopyAttachmentMarkdown(_:)),
                    keyEquivalent: ""
                )
                copyTableItem.target = self
                menu.addItem(copyTableItem)
            }

            return menu
        }

        // Check if click is in a code block.
        var codeBlockEffectiveRange = NSRange(location: 0, length: 0)
        let codeBlockValue = textStorage.attribute(
            .codeBlockRange,
            at: charIndex,
            effectiveRange: &codeBlockEffectiveRange
        )

        if codeBlockValue != nil {
            contextMenuCodeBlockRange = codeBlockEffectiveRange

            let copyCodeItem = NSMenuItem(
                title: "Copy Code",
                action: #selector(contextMenuCopyCode(_:)),
                keyEquivalent: ""
            )
            copyCodeItem.target = self
            menu.addItem(copyCodeItem)

            let copyMarkdownItem = NSMenuItem(
                title: "Copy as Markdown",
                action: #selector(contextMenuCopyAsMarkdown(_:)),
                keyEquivalent: ""
            )
            copyMarkdownItem.target = self
            menu.addItem(copyMarkdownItem)

            menu.addItem(.separator())

            let openInVimItem = NSMenuItem(
                title: "Open in MacVim",
                action: #selector(contextMenuOpenInMacVim(_:)),
                keyEquivalent: ""
            )
            openInVimItem.target = self
            menu.addItem(openInVimItem)

            return menu
        }

        // Default: text context menu.
        return buildDefaultTextMenu(menu)
    }

    /// Builds the default text context menu with Copy, Copy as Markdown, and Open in MacVim.
    private func buildDefaultTextMenu(_ menu: NSMenu) -> NSMenu {
        let copyItem = NSMenuItem(
            title: "Copy",
            action: #selector(copy(_:)),
            keyEquivalent: ""
        )
        copyItem.target = self
        menu.addItem(copyItem)

        let copyMarkdownItem = NSMenuItem(
            title: "Copy as Markdown",
            action: #selector(contextMenuCopyAsMarkdown(_:)),
            keyEquivalent: ""
        )
        copyMarkdownItem.target = self
        menu.addItem(copyMarkdownItem)

        menu.addItem(.separator())

        let openInVimItem = NSMenuItem(
            title: "Open in MacVim",
            action: #selector(contextMenuOpenInMacVim(_:)),
            keyEquivalent: ""
        )
        openInVimItem.target = self
        menu.addItem(openInVimItem)

        return menu
    }

    // MARK: - Context Menu State

    /// Character index where the context menu was invoked.
    private var contextMenuCharIndex: Int = 0

    /// The attachment under the context menu click (if any).
    private var contextMenuAttachment: (any MarkdownAttachment)?

    /// The code block range under the context menu click (if any).
    private var contextMenuCodeBlockRange: NSRange?

    /// Converts a point in the text view to a character index, accounting for
    /// text container origin offset.
    private func charIndex(at pointInView: NSPoint) -> Int {
        guard let textContainer, let layoutManager else { return 0 }

        var textPoint = pointInView
        textPoint.x -= textContainerOrigin.x
        textPoint.y -= textContainerOrigin.y

        let glyphIndex = layoutManager.glyphIndex(
            for: textPoint,
            in: textContainer
        )
        return layoutManager.characterIndexForGlyph(at: glyphIndex)
    }

    // MARK: - Context Menu Actions

    @objc private func contextMenuCopyImage(_ sender: Any?) {
        guard let image = contextMenuAttachment?.attachmentImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        NotificationCenter.default.post(name: .didCopyToClipboard, object: nil)
        Self.logger.debug("Copied image to pasteboard via context menu")
    }

    @objc private func contextMenuCopyAttachmentMarkdown(_ sender: Any?) {
        guard let markdown = contextMenuAttachment?.sourceMarkdown,
              !markdown.isEmpty
        else { return }
        copyToClipboard(markdown)
        Self.logger.debug("Copied attachment markdown source via context menu")
    }

    @objc private func contextMenuCopyCode(_ sender: Any?) {
        guard let textStorage,
              let range = contextMenuCodeBlockRange,
              range.location + range.length <= textStorage.length
        else { return }

        let codeText = textStorage.attributedSubstring(from: range).string
        copyToClipboard(codeText)
        Self.logger.debug("Copied code block via context menu (\(range.length) chars)")
    }

    @objc private func contextMenuCopyAsMarkdown(_ sender: Any?) {
        // If there's a selection, copy its markdown source.
        let selectedRange = self.selectedRange()
        if selectedRange.length > 0 {
            copyAsMarkdownSource(in: selectedRange)
            return
        }

        // Otherwise, use the entry at the click point.
        guard let coordinator,
              let entry = coordinator.sourceMap.entry(at: contextMenuCharIndex)
        else { return }

        let lines = coordinator.rawMarkdown.components(separatedBy: "\n")
        let lo = max(entry.sourceLineRange.lowerBound, 0)
        let hi = min(entry.sourceLineRange.upperBound, lines.count)
        guard lo < hi else { return }

        let markdownText = lines[lo..<hi].joined(separator: "\n")
        copyToClipboard(markdownText)
        Self.logger.debug("Copied markdown source lines \(lo)-\(hi - 1) via context menu")
    }

    @objc private func contextMenuOpenInMacVim(_ sender: Any?) {
        guard let coordinator,
              let fileURL = coordinator.fileURL,
              let entry = coordinator.sourceMap.entry(at: contextMenuCharIndex)
        else { return }

        let line = entry.sourceLineRange.lowerBound + 1
        launchMacVim(at: line, fileURL: fileURL)
    }

    // MARK: - Smart Copy (Cmd+C)

    override func copy(_ sender: Any?) {
        let selectedRange = self.selectedRange()
        guard selectedRange.length > 0, let textStorage else {
            super.copy(sender)
            return
        }

        if isSelectionEntirelyInCodeBlock(selectedRange, textStorage: textStorage) {
            copyVerbatimText(in: selectedRange, textStorage: textStorage)
        } else {
            copyAsMarkdownSource(in: selectedRange)
        }
    }

    /// Checks whether the entire selection falls within a single contiguous
    /// code block (identified by the `.codeBlockRange` attribute).
    private func isSelectionEntirelyInCodeBlock(
        _ range: NSRange,
        textStorage: NSTextStorage
    ) -> Bool {
        var entirelyCovered = true
        textStorage.enumerateAttribute(
            .codeBlockRange,
            in: range,
            options: []
        ) { value, _, stop in
            if value == nil {
                entirelyCovered = false
                stop.pointee = true
            }
        }
        return entirelyCovered
    }

    /// Copies the plain text of the selection directly (no markdown fences).
    private func copyVerbatimText(
        in range: NSRange,
        textStorage: NSTextStorage
    ) {
        let text = textStorage.attributedSubstring(from: range).string
        copyToClipboard(text)
        Self.logger.debug("Copied verbatim code text (\(range.length) chars)")
    }

    /// Uses the coordinator's SourceMap to find which source lines the
    /// selection covers and copies the raw markdown for those lines.
    private func copyAsMarkdownSource(in range: NSRange) {
        guard let coordinator,
              let sourceLineRange = coordinator.sourceMap.sourceLines(for: range)
        else {
            // SourceMap lookup failed — fall through to default behavior.
            super.copy(nil)
            return
        }

        let lines = coordinator.rawMarkdown.components(separatedBy: "\n")
        let clampedLower = max(sourceLineRange.lowerBound, 0)
        let clampedUpper = min(sourceLineRange.upperBound, lines.count)
        guard clampedLower < clampedUpper else {
            super.copy(nil)
            return
        }

        let selectedLines = lines[clampedLower..<clampedUpper].joined(separator: "\n")
        copyToClipboard(selectedLines)
        Self.logger.debug(
            "Copied markdown source lines \(clampedLower)-\(clampedUpper - 1)"
        )
    }

    // MARK: - Hover Copy Button (Tracking)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove existing tracking areas we added.
        for area in trackingAreas where area.owner === self {
            removeTrackingArea(area)
        }

        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .mouseEnteredAndExited,
            .activeInActiveApp,
            .inVisibleRect,
        ]
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateCopyButtonForMouseLocation(event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hideCopyButton()
    }

    /// Hit-tests the character at the mouse point and shows/hides the copy
    /// button depending on whether the cursor is over a code block.
    private func updateCopyButtonForMouseLocation(_ event: NSEvent) {
        let pointInView = convert(event.locationInWindow, from: nil)

        guard let textContainer, let layoutManager, let textStorage else {
            hideCopyButton()
            return
        }

        // Convert point to text container coordinates.
        var textPoint = pointInView
        textPoint.x -= textContainerOrigin.x
        textPoint.y -= textContainerOrigin.y

        let glyphIndex = layoutManager.glyphIndex(
            for: textPoint,
            in: textContainer
        )
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        guard charIndex < textStorage.length else {
            hideCopyButton()
            return
        }

        // Check if this character is inside a code block.
        var effectiveRange = NSRange(location: 0, length: 0)
        let value = textStorage.attribute(
            .codeBlockRange,
            at: charIndex,
            effectiveRange: &effectiveRange
        )

        if value != nil {
            // Mouse is over a code block — show button if not already showing
            // for this range.
            if hoveredCodeBlockRange != effectiveRange {
                showCopyButton(for: effectiveRange)
            }
        } else {
            hideCopyButton()
        }
    }

    // MARK: - Copy Button Lifecycle

    /// Creates and positions the copy button in the top-right corner of the
    /// code block's visual bounding rect.
    private func showCopyButton(for codeBlockRange: NSRange) {
        hideCopyButton()
        hoveredCodeBlockRange = codeBlockRange

        guard let layoutManager, let textContainer else { return }

        // Calculate the visual rect of the code block.
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: codeBlockRange,
            actualCharacterRange: nil
        )
        var blockRect = layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: textContainer
        )
        blockRect.origin.x += textContainerOrigin.x
        blockRect.origin.y += textContainerOrigin.y

        // Expand for padding (matching drawCodeBlockBackgrounds).
        if let theme = decorationTheme {
            let padding = theme.codeBlockPadding
            blockRect = blockRect.insetBy(dx: -padding, dy: -padding)
        }

        // Position button in the top-right corner of the block.
        let buttonSize: CGFloat = 28
        let inset: CGFloat = 6
        let buttonOrigin = NSPoint(
            x: blockRect.maxX - buttonSize - inset,
            y: blockRect.origin.y + inset
        )

        let button = NSButton(frame: NSRect(
            origin: buttonOrigin,
            size: NSSize(width: buttonSize, height: buttonSize)
        ))
        button.bezelStyle = .accessoryBar
        button.isBordered = false
        button.image = NSImage(
            systemSymbolName: "doc.on.doc",
            accessibilityDescription: "Copy code block"
        )
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .secondaryLabelColor
        button.toolTip = "Copy code block"
        button.target = self
        button.action = #selector(copyCodeBlockClicked(_:))
        button.tag = codeBlockRange.location

        // Semi-transparent rounded background.
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        if let theme = decorationTheme {
            button.layer?.backgroundColor = theme.codeBlockBackground
                .withAlphaComponent(0.85).cgColor
        } else {
            button.layer?.backgroundColor = NSColor.controlBackgroundColor
                .withAlphaComponent(0.85).cgColor
        }

        // Start hidden for fade-in.
        button.alphaValue = 0

        addSubview(button)
        copyButton = button

        // Register for scroll events to hide the button on scroll.
        if scrollObserver == nil, let scrollView = enclosingScrollView {
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.hideCopyButton()
                }
            }
        }

        // Fade in.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            button.animator().alphaValue = 1
        }
    }

    /// Hides and removes the copy button with a fade-out animation.
    private func hideCopyButton() {
        guard let button = copyButton else { return }
        hoveredCodeBlockRange = nil
        copyButton = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            button.animator().alphaValue = 0
        }, completionHandler: { [weak button] in
            MainActor.assumeIsolated {
                button?.removeFromSuperview()
            }
        })

        removeScrollObserver()
    }

    /// Removes the scroll bounds-change observer if present.
    private func removeScrollObserver() {
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
            scrollObserver = nil
        }
    }

    /// Action for the hover copy button — copies the entire code block content.
    @objc private func copyCodeBlockClicked(_ sender: NSButton) {
        guard let textStorage else { return }
        let location = sender.tag

        // Find the full code block range from the stored location.
        guard location >= 0, location < textStorage.length else { return }

        var effectiveRange = NSRange(location: 0, length: 0)
        let value = textStorage.attribute(
            .codeBlockRange,
            at: location,
            effectiveRange: &effectiveRange
        )
        guard value != nil else { return }

        let codeText = textStorage.attributedSubstring(from: effectiveRange).string
        copyToClipboard(codeText)
        Self.logger.debug("Copied code block via hover button (\(effectiveRange.length) chars)")
    }

    // MARK: - Cleanup

    deinit {
        if let observer = scrollObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - MarkdownTextView (NSViewRepresentable)

/// SwiftUI wrapper around an NSScrollView containing a read-only `MarkdownNSTextView`
/// for displaying rendered markdown content. Replaces MarkdownUI's `Markdown` view
/// with a native NSTextView that supports text selection, custom decoration drawing,
/// and source-map-based features.
struct MarkdownTextView: NSViewRepresentable {

    /// The rendered markdown content (attributed string + source map).
    let renderResult: RenderResult

    /// The current theme for background colors and custom drawing.
    let theme: AttributedStringTheme

    /// When set, the view scrolls to the heading with this anchor ID.
    var selectedHeadingID: String?

    /// The file being displayed (for Cmd+click -> editor).
    var fileURL: URL?

    /// Source markdown text (for copy-as-markdown).
    var rawMarkdown: String = ""

    /// Window manager for opening markdown links in new windows.
    var windowManager: WindowManager?

    /// Maximum content width (matching current 860pt layout).
    private static let maxContentWidth: CGFloat = 860.0

    /// Horizontal padding (matching current 32pt).
    private static let horizontalPadding: CGFloat = 32.0

    /// Vertical padding.
    private static let verticalPadding: CGFloat = 16.0

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = MarkdownNSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticLinkDetectionEnabled = false

        // Text container inset provides horizontal padding.
        textView.textContainerInset = NSSize(
            width: Self.horizontalPadding,
            height: Self.verticalPadding
        )

        // Configure text container for max content width.
        // The text container width limits line length; the text view itself
        // fills the scroll view width, centering the content column.
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(
                width: Self.maxContentWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
            textContainer.lineFragmentPadding = 0
        }

        // Wire up to scroll view.
        scrollView.documentView = textView
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Store references in coordinator and text view.
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.windowManager = windowManager
        textView.coordinator = context.coordinator

        // Set the coordinator as delegate for link click interception.
        textView.delegate = context.coordinator

        // Set initial theme and content.
        applyTheme(to: textView, theme: theme)
        applyContent(to: textView, renderResult: renderResult, coordinator: context.coordinator)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        // Update theme if changed.
        if context.coordinator.currentThemeIsDark != theme.isDark
            || context.coordinator.currentWindowBackground != theme.windowBackground
        {
            applyTheme(to: textView, theme: theme)
            context.coordinator.currentThemeIsDark = theme.isDark
            context.coordinator.currentWindowBackground = theme.windowBackground
        }

        // Update content if the attributed string changed.
        let newGeneration = ObjectIdentifier(renderResult.attributedString)
        if context.coordinator.lastAttributedStringID != newGeneration {
            applyContent(to: textView, renderResult: renderResult, coordinator: context.coordinator)
        }

        // Update coordinator state for interaction features.
        context.coordinator.sourceMap = renderResult.sourceMap
        context.coordinator.rawMarkdown = rawMarkdown
        context.coordinator.fileURL = fileURL
        context.coordinator.windowManager = windowManager

        // Scroll to heading if requested.
        if let headingID = selectedHeadingID, !headingID.isEmpty {
            scrollToHeading(headingID, in: textView)
        }
    }

    // MARK: - Content Application

    /// Replaces the text storage contents with the new attributed string.
    private func applyContent(
        to textView: MarkdownNSTextView,
        renderResult: RenderResult,
        coordinator: Coordinator
    ) {
        guard let textStorage = textView.textStorage else { return }

        // Replace all text storage content.
        textStorage.setAttributedString(renderResult.attributedString)

        // Track the identity of this attributed string to avoid redundant updates.
        coordinator.lastAttributedStringID = ObjectIdentifier(renderResult.attributedString)
        coordinator.sourceMap = renderResult.sourceMap
    }

    /// Applies theme colors to the text view (background, link styling, insertion point color).
    private func applyTheme(to textView: MarkdownNSTextView, theme: AttributedStringTheme) {
        textView.decorationTheme = theme

        if let bg = theme.windowBackground {
            textView.drawsBackground = true
            textView.backgroundColor = bg
        } else {
            textView.drawsBackground = true
            textView.backgroundColor = .textBackgroundColor
        }

        // Override NSTextView's default link styling to use the theme's link color.
        // Without this, NSTextView forces its own blue on all .link attributes.
        textView.linkTextAttributes = [
            .foregroundColor: theme.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]

        // Force a redraw to pick up new decoration colors.
        textView.needsDisplay = true
    }

    // MARK: - Scroll to Heading

    /// Scrolls the text view to show the heading with the given anchor ID.
    /// Positions the heading near the top of the visible area with padding,
    /// uses smooth animation, and briefly flash-selects the heading for visibility.
    private func scrollToHeading(_ anchorID: String, in textView: MarkdownNSTextView) {
        guard let textStorage = textView.textStorage,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView
        else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        var targetRange: NSRange?

        textStorage.enumerateAttribute(
            .headingAnchorID,
            in: fullRange,
            options: []
        ) { value, range, stop in
            if let id = value as? String, id == anchorID {
                targetRange = range
                stop.pointee = true
            }
        }

        guard let range = targetRange else { return }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: range,
            actualCharacterRange: nil
        )
        var rect = layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: textContainer
        )
        rect.origin.x += textView.textContainerOrigin.x
        rect.origin.y += textView.textContainerOrigin.y

        // Calculate scroll target so the heading appears near the top of
        // the visible area with some padding (24pt from top).
        let topPadding: CGFloat = 24.0
        let clipView = scrollView.contentView
        let visibleHeight = clipView.bounds.height
        let contentHeight = textView.frame.height

        var targetY = rect.origin.y - topPadding
        // Clamp to valid scroll range.
        targetY = max(0, min(targetY, contentHeight - visibleHeight))

        let targetOrigin = NSPoint(x: clipView.bounds.origin.x, y: targetY)

        // Smooth animated scroll.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            clipView.animator().setBoundsOrigin(targetOrigin)
        } completionHandler: {
            MainActor.assumeIsolated {
                scrollView.reflectScrolledClipView(clipView)

                // Flash-select the heading text so the user sees where they landed.
                textView.setSelectedRange(range)
                textView.showFindIndicator(for: range)

                // Clear the selection after a brief delay.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    MainActor.assumeIsolated {
                        textView.setSelectedRange(NSRange(location: 0, length: 0))
                    }
                }
            }
        }
    }

    // MARK: - Coordinator

    /// Coordinator that stores mutable state for the NSTextView and acts as a
    /// delegate bridge. Holds the SourceMap, rawMarkdown, and fileURL for
    /// interaction features added in Steps 7-11. Conforms to NSTextViewDelegate
    /// for link click interception.
    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {

        private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.pellucid",
            category: "MarkdownTextView.Coordinator"
        )

        weak var textView: MarkdownNSTextView?
        weak var scrollView: NSScrollView?

        /// Identity tracker for the last applied attributed string,
        /// used to avoid redundant text storage replacements.
        var lastAttributedStringID: ObjectIdentifier?

        /// Source map for the current content.
        var sourceMap: SourceMap = SourceMap()

        /// Raw markdown source for copy-as-markdown.
        var rawMarkdown: String = ""

        /// File URL for Cmd+click -> editor.
        var fileURL: URL?

        /// Reference to WindowManager for opening markdown links in new windows.
        var windowManager: WindowManager?

        /// Tracks the current theme's dark mode state for change detection.
        var currentThemeIsDark: Bool?

        /// Tracks the current window background for change detection.
        var currentWindowBackground: NSColor?

        // MARK: - NSTextViewDelegate — Link Clicks

        /// Intercepts link clicks to handle relative markdown links.
        /// Returns true if the link was handled, false to let the system handle it.
        func textView(
            _ textView: NSTextView,
            clickedOnLink link: Any,
            at charIndex: Int
        ) -> Bool {
            guard let url = link as? URL else { return false }

            Self.logger.debug(
                "Link clicked: scheme=\(url.scheme ?? "nil") path=\(url.path) abs=\(url.absoluteString)"
            )

            // If the URL has no scheme, resolve it relative to the file's directory.
            if url.scheme == nil, let baseDir = fileURL?.deletingLastPathComponent() {
                let resolved = baseDir.appendingPathComponent(url.path)
                Self.logger.debug("Resolved relative link: \(resolved.absoluteString)")

                if markdownExtensions.contains(resolved.pathExtension.lowercased()) {
                    Self.logger.debug("Opening markdown link in new window")
                    windowManager?.openFile(url: resolved)
                    return true
                }
            }

            // For file:// URLs that point to markdown files, open in Pellucid.
            if url.scheme == "file",
               markdownExtensions.contains(url.pathExtension.lowercased())
            {
                Self.logger.debug("Opening file:// markdown link in new window")
                windowManager?.openFile(url: url)
                return true
            }

            // Let the system handle all other links (http, https, mailto, etc.).
            Self.logger.debug("Delegating link to system handler")
            return false
        }
    }
}
