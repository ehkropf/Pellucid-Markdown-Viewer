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

    /// The file being displayed (for Cmd+click -> editor, added in later steps).
    var fileURL: URL?

    /// Source markdown text (for copy-as-markdown, added in later steps).
    var rawMarkdown: String = ""

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

        // Store reference in coordinator.
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

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

        // Update coordinator state for later interaction features.
        context.coordinator.sourceMap = renderResult.sourceMap
        context.coordinator.rawMarkdown = rawMarkdown
        context.coordinator.fileURL = fileURL

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

    /// Applies theme colors to the text view (background, insertion point color).
    private func applyTheme(to textView: MarkdownNSTextView, theme: AttributedStringTheme) {
        textView.decorationTheme = theme

        if let bg = theme.windowBackground {
            textView.drawsBackground = true
            textView.backgroundColor = bg
        } else {
            textView.drawsBackground = true
            textView.backgroundColor = .textBackgroundColor
        }

        // Force a redraw to pick up new decoration colors.
        textView.needsDisplay = true
    }

    // MARK: - Scroll to Heading

    /// Scrolls the text view to show the heading with the given anchor ID.
    private func scrollToHeading(_ anchorID: String, in textView: MarkdownNSTextView) {
        guard let textStorage = textView.textStorage,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
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

        textView.scrollToVisible(rect)
    }

    // MARK: - Coordinator

    /// Coordinator that stores mutable state for the NSTextView and acts as a
    /// delegate bridge. Holds the SourceMap, rawMarkdown, and fileURL for
    /// interaction features added in Steps 7-11.
    @MainActor
    final class Coordinator: NSObject {
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

        /// Tracks the current theme's dark mode state for change detection.
        var currentThemeIsDark: Bool?

        /// Tracks the current window background for change detection.
        var currentWindowBackground: NSColor?
    }
}
